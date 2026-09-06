"""Reconstruct B-mode images from the OpenH-RF (zea) channel data in this folder.

For every ``*.hdf5`` file in the same directory as this script the raw channel
data is beamformed with zea and the resulting B-mode image of the first frame is
saved as ``<name>_reconstruct_bmode.png``.

The reconstruction is chosen from the transmit geometry so that each acquisition
is beamformed the way it was acquired:

* **Focused / sector acquisitions** (finite positive focus distance, beams
  steered over a range of angles: focused imaging, sector scans) are
  reconstructed **scanline by scanline** — each focused transmit forms one image
  line along its beam, exactly like the conventional USTB Delay-And-Sum
  reconstruction. The per-line beamforming uses zea's ``tof_correction``
  primitive (the same delay-and-sum maths as ``pipeline.yaml``) and the lines are
  scan-converted to the correct sector geometry.
* **Synthetic transmit aperture (STA)** acquisitions are reconstructed by
  delay-and-sum on a cartesian grid **per transmit**, then coherently summed.
  zea's compounding ``Pipeline`` treats ``focus_distance == 0`` as plane-wave,
  which is incorrect for single-element STA, so STA never uses the pipeline.
* **Plane-wave compounding and diverging-wave acquisitions** use the compounding
  ``zea.Pipeline`` defined in ``pipeline.yaml`` on a cartesian grid.

Usage::

    python reconstruct.py                 # all .hdf5 files in this folder and sub-folders
    python reconstruct.py --input file.hdf5
"""

import os

os.environ["MPLBACKEND"] = "Agg"
os.environ.setdefault("KERAS_BACKEND", "jax")

import argparse
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import zea
from scipy.signal import hilbert
from zea import Config, File, Pipeline
from zea.beamform.beamformer import tof_correction

HERE = Path(__file__).resolve().parent
CONFIG = HERE / "pipeline.yaml"
N_DEPTH = 600  # axial samples per scan line (focused reconstruction)

DEPTH_SCALE_DEFAULT = 0.95  # trim ~5 % empty depth below the data extent
DEPTH_SCALE_ALPINION = 0.80  # Alpinion phantoms are recorded with excess depth

# Lateral / axial windows matching the USTB website catalog previews (metres).
_DISPLAY: dict[str, dict] = {
    "Alpinion_L3-8_CPWC_hypoechoic": {"zlims": (5e-3, 50e-3), "xlims_frac": 0.8},
    "Alpinion_L3-8_CPWC_hyperechoic_scatterers": {"zlims": (5e-3, 50e-3), "xlims_frac": 0.8},
    "FieldII_STAI_uniform_fov": {"zlims": (2.5e-3, 55e-3)},
    "FieldII_STAI_dynamic_range": {"zlims": (6e-3, 52.5e-3), "xlims": (-20e-3, 20e-3)},
    "FieldII_STAI_simulated_dynamic_range": {"zlims": (5e-3, 60e-3), "xlims_frac": 1.0},
}


def _has_tracks(f: File) -> bool:
    try:
        return "tracks" in f.keys()
    except Exception:  # noqa: BLE001
        return False


def _scan(f: File):
    return f.tracks[0].scan if _has_tracks(f) else f.scan


def _raw(f: File):
    """Raw channel data, handling both the flat (/data) and tracked (/tracks) layouts."""
    return f.tracks[0].data.raw_data[:] if _has_tracks(f) else f.data.raw_data[:]


def _probe_xlims(probe_geometry) -> tuple[float, float]:
    x = np.asarray(probe_geometry, dtype=np.float32)[:, 0]
    return float(x.min()), float(x.max())


def _depth_scale_factor(group: str = "") -> float:
    # The acquisition group is the name of the folder the .hdf5 lives in, so this
    # works whether reconstruct.py sits at the submission root or inside a group folder.
    if group == "D_alpinion_phantom":
        return DEPTH_SCALE_ALPINION
    return DEPTH_SCALE_DEFAULT


def _max_imaging_depth(n_ax: int, fs: float, c: float, group: str = "") -> float:
    return n_ax / fs * c / 2.0 * _depth_scale_factor(group)


def _display_limits(stem: str, probe_geometry, n_ax: int, fs: float, c: float, group: str = ""):
    """Return (xlims, zlims) in metres for B-mode display."""
    pg = np.asarray(probe_geometry, dtype=np.float32)
    x0, x1 = _probe_xlims(pg)
    half = (x1 - x0) / 2.0
    cx = (x0 + x1) / 2.0
    spec = _DISPLAY.get(stem, {})
    if "zlims" in spec:
        zlims = spec["zlims"]
    else:
        zlims = (1e-3, _max_imaging_depth(n_ax, fs, c, group))
    if "xlims" in spec:
        xlims = spec["xlims"]
    elif "xlims_frac" in spec:
        f = float(spec["xlims_frac"])
        xlims = (cx - half * f, cx + half * f)
    else:
        xlims = (x0, x1)
    return xlims, zlims


def _is_sta(tx_apodizations) -> bool:
    tx = np.asarray(tx_apodizations)
    if tx.ndim != 2 or tx.shape[0] < 2:
        return False
    active = (tx > 0.5).sum(axis=1)
    return bool(np.all(active == 1))


def _is_focused_sector(scan) -> bool:
    fd = np.array(scan.focus_distances).ravel()
    pa = np.array(scan.polar_angles).ravel()
    finite_pos = np.isfinite(fd) & (fd > 1e-6)
    polar_span = float(np.ptp(pa)) if pa.size > 1 else 0.0
    return bool(finite_pos.mean() > 0.5 and polar_span > np.deg2rad(3))


def _prepare_rf(data: np.ndarray) -> np.ndarray:
    """RF (n_tx, n_ax, n_el, 1) -> analytic signal (n_tx, n_ax, n_el, 2)."""
    if data.shape[-1] == 1:
        analytic = hilbert(data[..., 0].astype(np.float32), axis=1)
        return np.stack([analytic.real, analytic.imag], axis=-1).astype(np.float32)
    return data.astype(np.float32)


def _beamform_scanline(parameters, data, f_number, depth, sector):
    """Scanline DAS reconstruction of focused data (one focused beam per line).

    ``sector=True`` (phased array): each line follows its steered beam ray from
    the apex -> sector geometry. ``sector=False`` (linear array): each line is a
    vertical column at the beam's lateral focus position -> linear-scan geometry.

    Returns (envelope (N_DEPTH, n_tx), X (N_DEPTH, n_tx), Z (N_DEPTH, n_tx)) in
    metres for scan-converted display.
    """
    g = lambda a: np.array(getattr(parameters, a))  # noqa: E731
    t0, txapod, fd = g("t0_delays"), g("tx_apodizations"), g("focus_distances")
    pa, to, it, tpk = g("polar_angles"), g("transmit_origins"), g("initial_times"), g("t_peak")
    probe = g("probe_geometry")
    try:
        az = g("azimuth_angles")
    except Exception:  # noqa: BLE001
        az = np.zeros_like(pa)
    fs = float(np.array(parameters.sampling_frequency))
    c = float(np.array(parameters.sound_speed))

    n_tx = data.shape[0]
    data = _prepare_rf(data)

    s = np.linspace(1e-3, depth, N_DEPTH).astype(np.float32)
    lines = np.zeros((N_DEPTH, n_tx), dtype=np.complex64)
    X = np.zeros((N_DEPTH, n_tx), dtype=np.float32)
    Z = np.zeros((N_DEPTH, n_tx), dtype=np.float32)

    for n in range(n_tx):
        v = np.array(
            [np.sin(pa[n]) * np.cos(az[n]), np.sin(pa[n]) * np.sin(az[n]), np.cos(pa[n])],
            dtype=np.float32,
        )
        if sector:
            pts = (to[n][None, :] + s[:, None] * v[None, :]).astype(np.float32)
        else:
            x_n = float(to[n, 0] + fd[n] * v[0])
            pts = np.stack([np.full(N_DEPTH, x_n, np.float32), np.zeros(N_DEPTH, np.float32), s], axis=1)
        X[:, n], Z[:, n] = pts[:, 0], pts[:, 2]
        tof = tof_correction(
            data[n : n + 1], pts, t0[n : n + 1], txapod[n : n + 1], c, probe,
            it[n : n + 1], fs, 0.0, f_number, pa[n : n + 1], fd[n : n + 1],
            tpk[n : n + 1], to[n : n + 1],
        )
        line = np.array(tof).sum(axis=2)[0]
        lines[:, n] = line[:, 0] + 1j * line[:, 1]

    return np.abs(lines), X, Z


def _beamform_sta(data, probe_geometry, scan, f_number, xlims, zlims, grid_size):
    """STA: per-transmit DAS on a cartesian grid, then coherent sum."""
    pg = np.asarray(probe_geometry, dtype=np.float32)
    t0 = np.asarray(scan.t0_delays, dtype=np.float32)
    txapod = np.asarray(scan.tx_apodizations, dtype=np.float32)
    fd = np.asarray(scan.focus_distances, dtype=np.float32)
    pa = np.asarray(scan.polar_angles, dtype=np.float32)
    to = np.asarray(scan.transmit_origins, dtype=np.float32)
    it = np.asarray(scan.initial_times, dtype=np.float32)
    fs = float(np.asarray(scan.sampling_frequency))
    c = float(np.asarray(scan.sound_speed))

    data = _prepare_rf(data)
    n_tx = data.shape[0]
    nx = nz = int(grid_size)
    x = np.linspace(xlims[0], xlims[1], nx, dtype=np.float32)
    z = np.linspace(zlims[0], zlims[1], nz, dtype=np.float32)
    X, Z = np.meshgrid(x, z)
    grid = np.stack([X.ravel(), np.zeros(X.size, np.float32), Z.ravel()], axis=1)

    acc = np.zeros(X.size, dtype=np.complex64)
    tpk = np.zeros(n_tx, dtype=np.float32)
    for n in range(n_tx):
        tof = tof_correction(
            data[n : n + 1], grid, t0[n : n + 1], txapod[n : n + 1], c, pg,
            it[n : n + 1], fs, 0.0, f_number, pa[n : n + 1], fd[n : n + 1],
            tpk[n : n + 1], to[n : n + 1],
        )
        line = np.array(tof)[0].sum(axis=1)
        acc += line[:, 0] + 1j * line[:, 1]

    env = np.abs(acc).reshape(nz, nx)
    extent = np.array([xlims[0], xlims[1], zlims[1], zlims[0]], dtype=np.float32)
    return env, extent


def reconstruct_file(path: Path, rf_pipeline: Pipeline, base_overrides: dict, num_patches: int) -> Path:
    f_number = float(base_overrides.get("f_number", 1.75))
    dr = float(abs(np.array(base_overrides.get("dynamic_range", [-60, 0])).min()))
    grid_size_x = int(base_overrides.get("grid_size_x", 400))
    grid_size_z = int(base_overrides.get("grid_size_z", 600))
    out_path = path.with_name(path.stem + "_reconstruct_bmode.png")
    zea.visualize.set_mpl_style()
    fig, ax = plt.subplots(figsize=(5, 6))

    with File(str(path)) as f:
        raw = _raw(f)
        n_ch = raw.shape[-1]
        scan = _scan(f)
        probe_geometry = np.asarray(f.probe.probe_geometry)
        try:
            probe_type = str(f.probe.type)
        except Exception:  # noqa: BLE001
            probe_type = "linear"
        fs = float(np.array(scan.sampling_frequency))
        c = float(np.array(scan.sound_speed))
        group = path.parent.name  # acquisition group = folder the .hdf5 lives in
        xlims, zlims = _display_limits(path.stem, probe_geometry, raw.shape[2], fs, c, group)
        depth = zlims[1]
        focused = _is_focused_sector(scan)
        sta = _is_sta(scan.tx_apodizations)
        sector = probe_type == "phased"

        overrides = dict(base_overrides)
        overrides["zlims"] = zlims
        overrides["grid_type"] = "cartesian"
        overrides.setdefault("grid_size_y", 1)
        if not focused and probe_type == "linear":
            overrides["xlims"] = xlims
        parameters = f.load_parameters(**overrides)
        extent = np.array(parameters.extent_imshow)

    if focused:
        fn_scanline = 0.0 if sector else f_number
        env, X, Z = _beamform_scanline(parameters, raw[0], fn_scanline, depth, sector)
        env = env / (env.max() + 1e-12)
        logc = np.clip(20 * np.log10(env + 1e-6), -dr, 0)
        ax.pcolormesh(X, Z, logc, cmap="gray", shading="auto", vmin=-dr, vmax=0)
        ax.invert_yaxis()
        mode = "scanline-" + ("sector" if sector else "linear")
    elif sta:
        env, extent = _beamform_sta(
            raw[0], probe_geometry, scan, f_number, xlims, zlims,
            grid_size=min(grid_size_x, grid_size_z),
        )
        env = env / (env.max() + 1e-12)
        logc = np.clip(20 * np.log10(env + 1e-6), -dr, 0)
        ax.imshow(logc, extent=extent, cmap="gray", aspect="equal", vmin=-dr, vmax=0)
        mode = "sta"
    else:
        pipeline = rf_pipeline if n_ch == 1 else Pipeline.from_default(baseband=True, num_patches=num_patches)
        inputs = pipeline.prepare_parameters(parameters)
        recon = np.array(pipeline(data=raw[:1], **inputs)["data"])
        recon = recon[0] if recon.ndim == 3 else recon
        image = zea.display.to_8bit(recon, dynamic_range=parameters.dynamic_range)
        ax.imshow(image, extent=extent, cmap="gray")
        mode = "compound"

    ax.set_aspect("equal")
    ax.set_xlabel("x (m)")
    ax.set_ylabel("z (m)")
    ax.set_title("zea: " + path.stem, fontsize=8)
    fig.savefig(str(out_path), bbox_inches="tight", dpi=110)
    plt.close(fig)
    print(f"  {path.name} -> {out_path.name}  ({mode})")
    return out_path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=None, help="Single .hdf5 file (default: all in folder)")
    args = parser.parse_args()

    config = Config.from_path(str(CONFIG))
    rf_pipeline = Pipeline.from_config(config)
    base_overrides = dict(config.get("parameters", {}))
    num_patches = 200
    try:
        for op in config["pipeline"]["operations"]:
            if op.get("name") == "beamform":
                num_patches = int(op.get("params", {}).get("num_patches", num_patches))
    except Exception:  # noqa: BLE001
        pass

    # Recurse so a single root-level reconstruct.py reconstructs every sub-dataset
    # folder; when placed inside one folder it just finds that folder's files.
    files = [args.input] if args.input else sorted(HERE.rglob("*.hdf5"))
    if not files:
        print("No .hdf5 files found.")
        return
    print(f"Reconstructing {len(files)} file(s)...")
    for path in files:
        try:
            reconstruct_file(path, rf_pipeline, base_overrides, num_patches)
        except Exception as exc:  # noqa: BLE001
            print(f"  ERROR ({path.name}): {type(exc).__name__}: {exc}")


if __name__ == "__main__":
    main()

