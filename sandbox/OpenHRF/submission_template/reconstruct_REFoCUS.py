"""Reconstruct B-mode images using zea.Pipeline with REFoCUS decoding.

REFoCUS (Retrospective Encoding For Conventional Ultrasound Sequences) inverts
the transmit encoding model in the frequency domain, recovering a full-matrix
capture (synthetic aperture) dataset from plane-wave or focused transmit data.
This can improve lateral resolution and contrast compared to standard DAS.

For STA datasets (already single-element transmissions), REFoCUS is not
applicable — they are reconstructed with pfield-enabled DAS instead.

References:
    Bottenus, N. (2018). Recovery of the complete data set from focused
    transmit beams. IEEE TUFFC, 65(1), 30-38.

Usage::

    python reconstruct_REFoCUS.py                   # all .hdf5 files recursively
    python reconstruct_REFoCUS.py --input file.hdf5
    python reconstruct_REFoCUS.py --method tikhonov --param 0.01
"""

import os

os.environ["MPLBACKEND"] = "Agg"
os.environ.setdefault("KERAS_BACKEND", "jax")

import argparse
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import zea
from zea import File, Pipeline
from zea.ops import (
    ApplyWindow,
    BandPassFilter,
    Beamform,
    Cast,
    Demodulate,
    Downsample,
    EnvelopeDetect,
    LogCompress,
    Normalize,
    Refocus,
)

HERE = Path(__file__).resolve().parent

# Minimum number of transmit events for REFoCUS to be well-posed. Below this the
# transmit-encoding inversion is too underdetermined to recover a focused image, so we
# fall back to pfield-DAS (e.g. single plane wave n_tx=1, or PICMUS with 5 angles).
MIN_TX_FOR_REFOCUS = 8

DEPTH_SCALE_DEFAULT = 0.95
DEPTH_SCALE_ALPINION = 0.80

_DISPLAY: dict[str, dict] = {
    "Alpinion_L3-8_CPWC_hypoechoic": {"zlims": (5e-3, 50e-3), "xlims_frac": 0.8},
    "Alpinion_L3-8_CPWC_hyperechoic_scatterers": {"zlims": (5e-3, 50e-3), "xlims_frac": 0.8},
    "FieldII_STAI_uniform_fov": {"zlims": (2.5e-3, 55e-3)},
    "FieldII_STAI_dynamic_range": {"zlims": (6e-3, 52.5e-3), "xlims": (-20e-3, 20e-3)},
    "FieldII_STAI_simulated_dynamic_range": {"zlims": (5e-3, 60e-3), "xlims_frac": 1.0},
    # Phased-array sectors: clip the radial depth to the USTB catalog reference depth.
    # The transmit angle span already matches USTB, so matching the depth matches the
    # displayed sector size (fan width scales as depth * sin(theta_max)).
    "P4_FI_121444_45mm_focus": {"zlims": (1e-3, 60e-3)},
    "FI_P4_cysts_center": {"zlims": (1e-3, 115e-3)},
    "FI_P4_point_scatterers": {"zlims": (1e-3, 115e-3)},
    "FieldII_P4_point_scatterers": {"zlims": (1e-3, 110e-3)},
    "Verasonics_P2-4_parasternal_long_small": {"zlims": (1e-3, 110e-3)},
    "Verasonics_P2-4_parasternal_long_subject_1": {"zlims": (1e-3, 110e-3)},
    "Verasonics_P2-4_apical_four_chamber_subject_1": {"zlims": (1e-3, 110e-3)},
    "speckle_sim_FI_P4_probe_apod_1_speckle_long_many_angles": {"zlims": (1e-3, 110e-3)},
    "speckle_sim_FI_P4_probe_apod_2_speckle_long_many_angles": {"zlims": (1e-3, 110e-3)},
    "speckle_sim_FI_P4_probe_apod_3_speckle_long_many_angles": {"zlims": (1e-3, 110e-3)},
}


def _has_tracks(f: File) -> bool:
    try:
        return "tracks" in f.keys()
    except Exception:  # noqa: BLE001
        return False


def _scan(f: File):
    return f.tracks[0].scan if _has_tracks(f) else f.scan


def _raw(f: File):
    return f.tracks[0].data.raw_data[:] if _has_tracks(f) else f.data.raw_data[:]


def _probe_xlims(probe_geometry) -> tuple[float, float]:
    x = np.asarray(probe_geometry, dtype=np.float32)[:, 0]
    return float(x.min()), float(x.max())


def _depth_scale_factor(group: str = "") -> float:
    if group == "D_alpinion_phantom":
        return DEPTH_SCALE_ALPINION
    return DEPTH_SCALE_DEFAULT


def _max_imaging_depth(n_ax: int, fs: float, c: float, group: str = "") -> float:
    return n_ax / fs * c / 2.0 * _depth_scale_factor(group)


def _display_limits(stem: str, probe_geometry, n_ax: int, fs: float, c: float, group: str = ""):
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


def reconstruct_file(path: Path, method: str = "adjoint", param: float | None = None,
                     f_number: float = 1.75, dynamic_range: float = 60.0,
                     grid_size_x: int = 400, grid_size_z: int = 600,
                     num_patches: int = 200, out_dir: Path | None = None) -> Path:
    """Reconstruct a single file with REFoCUS + DAS pipeline."""
    suffix = "_reconstruct_refocus_bmode.png"
    if out_dir is not None:
        out_dir.mkdir(parents=True, exist_ok=True)
        out_path = out_dir / (path.stem + suffix)
    else:
        out_path = path.with_name(path.stem + suffix)

    zea.visualize.set_mpl_style()
    fig, ax = plt.subplots(figsize=(5, 6))

    with File(str(path)) as f:
        raw = _raw(f)
        n_ch = raw.shape[-1]
        n_tx = raw.shape[1]
        scan = _scan(f)
        probe_geometry = np.asarray(f.probe.probe_geometry)
        try:
            probe_type = str(f.probe.type)
        except Exception:  # noqa: BLE001
            probe_type = "linear"
        fs = float(np.array(scan.sampling_frequency))
        c = float(np.array(scan.sound_speed))
        group = path.parent.name
        xlims, zlims = _display_limits(path.stem, probe_geometry, raw.shape[2], fs, c, group)

        sta = _is_sta(scan.tx_apodizations)

        # Phased-array sectors are beamformed on a polar grid (following the steered
        # angles) with the full receive aperture (f-number 0), then displayed with
        # pcolormesh so the entire sector field of view is preserved. A finite
        # f-number would mask the wide-angle edges and narrow the sector.
        is_phased = (probe_type == "phased")
        fn = 0.0 if is_phased else f_number
        overrides: dict = {
            "f_number": fn,
            "grid_size_x": grid_size_x,
            "grid_size_z": grid_size_z,
            "dynamic_range": [-dynamic_range, 0],
            "selected_transmits": "all",
            "zlims": zlims,
            "grid_type": "polar" if is_phased else "cartesian",
            "grid_size_y": 1,
        }
        if probe_type == "linear":
            overrides["xlims"] = xlims

        parameters = f.load_parameters(**overrides)
        extent = np.array(parameters.extent_imshow)

    # Preprocessing follows the zea cardiac example gist
    # (tristan-deep/067e80f28086ec894513e46422a7bbd1). Baseband (IQ) data has n_ch == 2,
    # so the band-pass and RF->IQ demodulation steps are skipped (already at baseband).
    fc = float(np.array(parameters.center_frequency))
    is_baseband = (n_ch == 2)
    bandpass_ops = [] if is_baseband else [BandPassFilter(passband=(0.5 * fc, 1.5 * fc))]
    demod_ops = [] if is_baseband else [Demodulate()]
    # REFoCUS decodes the transmit-encoding matrix to recover the multistatic (per-element)
    # dataset. This requires enough transmit events to be well-posed: with a single transmit
    # (n_tx == 1) it is undefined, and with only a handful (e.g. PICMUS's 5 plane-wave angles)
    # the inversion is badly underdetermined and produces a defocused image regardless of the
    # inversion method. We therefore fall back to pfield-DAS below MIN_TX_FOR_REFOCUS. STA is
    # already multistatic, so REFoCUS is also N/A there.
    refocus_na = sta or n_tx < MIN_TX_FOR_REFOCUS
    if refocus_na:
        # REFoCUS not applicable — use pfield DAS directly.
        pipeline = Pipeline(
            operations=[
                Cast(dtype="float32"),
                *bandpass_ops,
                ApplyWindow(),
                *demod_ops,
                Downsample(factor=2),
                Beamform(
                    beamformer="delay_and_sum",
                    enable_pfield=True,
                    num_patches=num_patches,
                ),
                EnvelopeDetect(),
                Normalize(),
                LogCompress(),
            ],
            with_batch_dim=False,
        )
        mode = "sta-pfield (REFoCUS N/A)" if sta else f"pfield (REFoCUS N/A: only {n_tx} transmits)"
    else:
        # Apply REFoCUS to decode transmit encoding before beamforming. jit_compile=False
        # avoids a cuBLASLt autotuning failure on the complex matmul under XLA on some
        # GPUs (matches the REFoCUS notebook / gist).
        pipeline = Pipeline(
            operations=[
                Cast(dtype="float32"),
                ApplyWindow(size=64, start=64),
                Refocus(method=method, param=param, jit_compile=False),
                *bandpass_ops,
                *demod_ops,
                Downsample(factor=2),
                Beamform(
                    beamformer="delay_and_sum",
                    enable_pfield=True,
                    num_patches=num_patches,
                ),
                EnvelopeDetect(),
                Normalize(),
                LogCompress(),
            ],
            with_batch_dim=False,
        )
        mode = f"REFoCUS ({method})"

    inputs = pipeline.prepare_parameters(parameters)
    recon = np.array(pipeline(data=raw[0], **inputs)["data"])
    recon = recon[0] if recon.ndim == 3 else recon

    image = zea.display.to_8bit(recon, dynamic_range=parameters.dynamic_range)
    if is_phased:
        # Map each polar pixel to its true cartesian position to render the full sector.
        grid_cart = np.array(parameters.grid)  # (grid_size_z, grid_size_x, 3)
        ax.pcolormesh(grid_cart[..., 0], grid_cart[..., 2], image,
                      cmap="gray", shading="auto", vmin=0, vmax=255)
        ax.invert_yaxis()
    else:
        ax.imshow(image, extent=extent, cmap="gray")

    ax.set_aspect("equal")
    ax.set_xlabel("x (m)")
    ax.set_ylabel("z (m)")
    ax.set_title(f"zea ({mode}): " + path.stem, fontsize=7)
    fig.savefig(str(out_path), bbox_inches="tight", dpi=110)
    plt.close(fig)
    print(f"  {path.name} -> {out_path.name}  ({mode})")
    return out_path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=None, help="Single .hdf5 file")
    parser.add_argument("--input-dir", type=Path, default=None, help="Root dir to find .hdf5 files")
    parser.add_argument("--output-dir", type=Path, default=None, help="Output directory for PNGs")
    parser.add_argument("--method", type=str, default="adjoint",
                        choices=["adjoint", "tikhonov", "tsvd", "rsvd"],
                        help="REFoCUS inversion method")
    parser.add_argument("--param", type=float, default=None,
                        help="REFoCUS regularization parameter (None = default per method)")
    parser.add_argument("--f-number", type=float, default=1.75)
    parser.add_argument("--dynamic-range", type=float, default=60.0)
    parser.add_argument("--grid-size-x", type=int, default=400)
    parser.add_argument("--grid-size-z", type=int, default=600)
    parser.add_argument("--num-patches", type=int, default=200)
    args = parser.parse_args()

    search_root = args.input_dir if args.input_dir else HERE
    files = [args.input] if args.input else sorted(search_root.rglob("*.hdf5"))
    if not files:
        print("No .hdf5 files found.")
        return
    print(f"Reconstructing {len(files)} file(s) with REFoCUS ({args.method}) pipeline...")
    for path in files:
        try:
            reconstruct_file(
                path,
                method=args.method,
                param=args.param,
                f_number=args.f_number,
                dynamic_range=args.dynamic_range,
                grid_size_x=args.grid_size_x,
                grid_size_z=args.grid_size_z,
                num_patches=args.num_patches,
                out_dir=args.output_dir,
            )
        except Exception as exc:  # noqa: BLE001
            print(f"  ERROR ({path.name}): {type(exc).__name__}: {exc}")


if __name__ == "__main__":
    main()
