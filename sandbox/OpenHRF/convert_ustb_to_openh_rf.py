"""Convert USTB UFF datasets to the OpenH-RF (zea) HDF5 format.

Reads ``.uff`` files (via ``pyuff-ustb``) and writes spec-compliant ``zea``
HDF5 files using ``zea.File.create``. The output satisfies the OpenH-RF
submission requirements: a ``/data/raw_data`` array of shape
``(n_frames, n_tx, n_ax, n_el, n_ch)``, a fully populated ``/scan`` group
(``t0_delays``, ``focus_distances``, ``polar_angles``, ``transmit_origins`` …),
a ``/probe`` group with ``probe_geometry``, and the ``zea_version`` root
attribute that the OpenH-RF evaluator requires.

The USTB transmit model is geometry-based (each ``uff.wave`` stores a virtual
source plus a wavefront type). zea instead stores explicit per-element
``t0_delays`` together with ``focus_distances`` / ``polar_angles`` /
``transmit_origins`` that select the first/last-arrival wavefront logic. This
script maps between the two using ``zea``'s own
``compute_t0_delays_planewave`` / ``compute_t0_delays_focused`` helpers, so the
delays are guaranteed consistent with zea's beamformer.

Supported transmit types: coherent plane-wave compounding (CPWC), focused
imaging (FI), diverging waves (DW) and synthetic transmit aperture (STA).

Datasets are grouped into application sub-datasets (A-F) for OpenH-RF, and the
PICMUS in-vivo / experiment / simulation acquisitions are excluded
(``PICMUS_numerical_calib_v2`` is kept, with its PICMUS origin documented in the
group E data card).

Usage::

    python convert_ustb_to_openh_rf.py --input C:/Data/USTB_data \
        --output C:/Data/USTB_data/openh_rf_submission

Requirements::

    pip install pyuff-ustb zea numpy
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path

import numpy as np

os.environ.setdefault("KERAS_BACKEND", "jax")

# ---------------------------------------------------------------------------
# Dataset registry: group -> list of (filename, probe, probe_type, view, notes)
# Groups map to OpenH-RF application sub-datasets A-F.
# The six excluded PICMUS files are simply absent from this list.
# ---------------------------------------------------------------------------
GROUPS: dict[str, dict] = {
    "A_cardiac": {
        "pretty": "In-vivo cardiac (Verasonics P4-2)",
        "tier": "in-vivo-human",
        "datasets": [
            {"filename": "Verasonics_P2-4_parasternal_long_subject_1.uff", "probe": "P4-2", "probe_type": "phased", "view": "parasternal long-axis"},
            {"filename": "Verasonics_P2-4_parasternal_long_small.uff", "probe": "P4-2", "probe_type": "phased", "view": "parasternal long-axis"},
            {"filename": "Verasonics_P2-4_apical_four_chamber_subject_1.uff", "probe": "P4-2", "probe_type": "phased", "view": "apical four-chamber"},
        ],
    },
    "B_carotid": {
        "pretty": "In-vivo carotid (Verasonics L7-4)",
        "tier": "in-vivo-human",
        "datasets": [
            {"filename": "L7_FI_carotid_cross_1.uff", "probe": "L7-4", "probe_type": "linear", "view": "carotid cross-section"},
            {"filename": "L7_FI_carotid_cross_2.uff", "probe": "L7-4", "probe_type": "linear", "view": "carotid cross-section"},
            {"filename": "L7_FI_carotid_cross_sub_2.uff", "probe": "L7-4", "probe_type": "linear", "view": "carotid cross-section"},
        ],
    },
    "C_verasonics_phantom": {
        "pretty": "Phantom (Verasonics L7-4 / P4)",
        "tier": "phantom",
        "datasets": [
            {"filename": "experimental_STAI_dynamic_range.uff", "probe": "L7-4", "probe_type": "linear", "view": "STA dynamic range phantom"},
            {"filename": "experimental_dynamic_range_phantom.uff", "probe": "L7-4", "probe_type": "linear", "view": "dynamic range phantom"},
            {"filename": "STAI_UFF_CIRS_phantom.uff", "probe": "L7-4", "probe_type": "linear", "view": "CIRS phantom (STA)"},
            {"filename": "L7_CPWC_193328.uff", "probe": "L7-4", "probe_type": "linear", "view": "CPWC phantom"},
            {"filename": "L7_FI_IUS2018.uff", "probe": "L7-4", "probe_type": "linear", "view": "focused phantom"},
            {"filename": "L7_FI_Verasonics.uff", "probe": "L7-4", "probe_type": "linear", "view": "focused phantom"},
            {"filename": "L7_FI_Verasonics_CIRS.uff", "probe": "L7-4", "probe_type": "linear", "view": "CIRS phantom (focused)"},
            {"filename": "L7_FI_Verasonics_CIRS_points.uff", "probe": "L7-4", "probe_type": "linear", "view": "CIRS point targets"},
            {"filename": "P4_FI_121444_45mm_focus.uff", "probe": "P4-1", "probe_type": "phased", "view": "focused phased-array phantom"},
            {"filename": "FI_P4_point_scatterers.uff", "probe": "P4-2", "probe_type": "phased", "view": "Verasonics P4-2 focused point scatterers"},
            {"filename": "FI_P4_cysts_center.uff", "probe": "P4-2", "probe_type": "phased", "view": "Verasonics P4-2 focused cyst phantom"},
            {"filename": "L7_CPWC_TheGB.uff", "probe": "L7-4", "probe_type": "linear", "view": "CPWC (Generalized Beamformer)"},
            {"filename": "L7_FI_TheGB.uff", "probe": "L7-4", "probe_type": "linear", "view": "focused (Generalized Beamformer)"},
            {"filename": "L7_DW_TheGB.uff", "probe": "L7-4", "probe_type": "linear", "view": "diverging wave (Generalized Beamformer)"},
            {"filename": "L7_STA_TheGB.uff", "probe": "L7-4", "probe_type": "linear", "view": "synthetic transmit aperture (Generalized Beamformer)"},
            # Note: reference_RTB_data.uff and invitro_20.uff are beamformed-only (no raw
            # channel data) and are therefore not eligible for OpenH-RF.
        ],
    },
    "D_alpinion_phantom": {
        "pretty": "Phantom (Alpinion L3-8)",
        "tier": "phantom",
        "datasets": [
            {"filename": "Alpinion_L3-8_FI_hypoechoic.uff", "probe": "L3-8", "probe_type": "linear", "view": "focused hypoechoic cyst"},
            {"filename": "Alpinion_L3-8_FI_hyperechoic_scatterers.uff", "probe": "L3-8", "probe_type": "linear", "view": "focused hyperechoic scatterers"},
            {"filename": "Alpinion_L3-8_CPWC_hypoechoic.uff", "probe": "L3-8", "probe_type": "linear", "view": "CPWC hypoechoic cyst"},
            {"filename": "Alpinion_L3-8_CPWC_hyperechoic_scatterers.uff", "probe": "L3-8", "probe_type": "linear", "view": "CPWC hyperechoic scatterers"},
        ],
    },
    "E_simulation": {
        "pretty": "Simulation (Field II)",
        "tier": "simulation",
        "datasets": [
            {"filename": "FieldII_CPWC_simulation_v2.uff", "probe": "L7-4", "probe_type": "linear", "view": "CPWC simulation"},
            {"filename": "FieldII_CPWC_point_scatterers_res_v2.uff", "probe": "L7-4", "probe_type": "linear", "view": "CPWC point scatterers"},
            {"filename": "FieldII_STAI_dynamic_range.uff", "probe": "L7-4", "probe_type": "linear", "view": "STA dynamic range"},
            {"filename": "FieldII_STAI_simulated_dynamic_range.uff", "probe": "L7-4", "probe_type": "linear", "view": "STA dynamic range"},
            # Website preview uses /channel_data_speckle; /channel_data is the string-grid target.
            {"filename": "FieldII_STAI_uniform_fov.uff", "probe": "L7-4", "probe_type": "linear", "view": "STA uniform FOV (speckle)", "uff_path": "channel_data_speckle"},
            {"filename": "FieldII_P4_point_scatterers.uff", "probe": "P4-1", "probe_type": "phased", "view": "phased-array point scatterers"},
            {"filename": "FieldII_speckle_DMASsimulation300000pts.uff", "probe": "L7-4", "probe_type": "linear", "view": "dense speckle"},
            {"filename": "speckle_sim_FI_P4_probe_apod_1_speckle_long_many_angles.uff", "probe": "P4-1", "probe_type": "phased", "view": "blocked array (full aperture)"},
            {"filename": "speckle_sim_FI_P4_probe_apod_2_speckle_long_many_angles.uff", "probe": "P4-1", "probe_type": "phased", "view": "blocked array (1/3 aperture)"},
            {"filename": "speckle_sim_FI_P4_probe_apod_3_speckle_long_many_angles.uff", "probe": "P4-1", "probe_type": "phased", "view": "blocked array (1/2 aperture)"},
            # Note: insilico_20.uff and insilico_side_100_M45.uff are beamformed-only (no raw
            # channel data) and are therefore not eligible for OpenH-RF.
            # Kept PICMUS file: numerical calibration only. PICMUS origin documented in data card.
            {"filename": "PICMUS_numerical_calib_v2.uff", "probe": "L7-4", "probe_type": "linear", "view": "numerical calibration (PICMUS-derived)", "picmus_origin": True},
        ],
    },
    "F_motion": {
        "pretty": "Motion estimation (SWE / ARFI, Verasonics L7-4)",
        "tier": "phantom",
        "datasets": [
            {"filename": "ARFI_dataset.uff", "probe": "L7-4", "probe_type": "linear", "view": "ARFI push-track"},
            {"filename": "SWE_L7_type_I.uff", "probe": "L7-4", "probe_type": "linear", "view": "shear wave elastography (type I)"},
            {"filename": "SWE_L7_type_III.uff", "probe": "L7-4", "probe_type": "linear", "view": "shear wave elastography (type III)"},
            {"filename": "SWE_L7_type_IV.uff", "probe": "L7-4", "probe_type": "linear", "view": "shear wave elastography (type IV)"},
        ],
    },
}

# STA detection: a focused/diverging virtual source whose |z| is below this
# threshold is treated as a single-element synthetic-aperture transmit.
STA_Z_THRESHOLD_M = 1.0e-3


def _read_channel_data(filepath: Path, uff_path: str = "channel_data"):
    from pyuff_ustb.objects.uff import Uff

    uff = Uff(str(filepath))
    try:
        return uff.read(uff_path)
    except Exception as exc:  # noqa: BLE001
        print(f"    no {uff_path} ({exc})")
        return None


def _probe_geometry(probe) -> np.ndarray:
    n_el = int(probe.N_elements)
    geom = np.zeros((n_el, 3), dtype=np.float32)
    geom[:, 0] = np.asarray(probe.x, dtype=np.float32).ravel()
    if probe.y is not None:
        geom[:, 1] = np.asarray(probe.y, dtype=np.float32).ravel()
    if probe.z is not None:
        geom[:, 2] = np.asarray(probe.z, dtype=np.float32).ravel()
    return geom


def _build_transmit_fields(channel_data, probe_geometry: np.ndarray, sound_speed: float):
    """Map the USTB wave sequence onto zea transmit fields.

    Returns a dict with ``t0_delays`` ``(n_tx, n_el)``, ``tx_apodizations``
    ``(n_tx, n_el)``, ``focus_distances`` ``(n_tx,)``, ``polar_angles``
    ``(n_tx,)``, ``azimuth_angles`` ``(n_tx,)``, ``transmit_origins``
    ``(n_tx, 3)`` and ``wave_delays`` ``(n_tx,)``.
    """
    from zea.beamform.beamformer import transmit_delays
    from zea.beamform.delays import (
        compute_t0_delays_focused,
        compute_t0_delays_planewave,
    )

    sequence = channel_data.sequence
    if not isinstance(sequence, (list, tuple)):
        sequence = [sequence]
    n_tx = len(sequence)
    n_el = probe_geometry.shape[0]

    t0_delays = np.zeros((n_tx, n_el), dtype=np.float32)
    tx_apod = np.ones((n_tx, n_el), dtype=np.float32)
    focus_distances = np.zeros(n_tx, dtype=np.float32)
    polar_angles = np.zeros(n_tx, dtype=np.float32)
    azimuth_angles = np.zeros(n_tx, dtype=np.float32)
    transmit_origins = np.zeros((n_tx, 3), dtype=np.float32)
    wave_delays = np.zeros(n_tx, dtype=np.float32)
    # Per-wave correction added to initial_times (seconds). For synthetic
    # transmit aperture (single-element transmits), every transmit is recorded
    # with the same A/D start, so initial_times must be a constant across
    # transmits; any per-transmit variation breaks the coherent synthetic-aperture
    # focusing and smears the image laterally. The STA branch therefore cancels
    # the per-wave wave.delay term so that initial_times = channel_data.initial_time
    # (verified against the USTB preview: constant -> sharp, variable -> blurred).
    init_correction = np.zeros(n_tx, dtype=np.float32)
    is_sta = np.zeros(n_tx, dtype=bool)
    source_distances = np.zeros(n_tx, dtype=np.float32)  # |element| for STA transmits

    for i, wave in enumerate(sequence):
        wave_delays[i] = float(wave.delay) if wave.delay is not None else 0.0
        src = wave.source
        sx, sy, sz = float(src.x), float(src.y), float(src.z)
        az = float(src.azimuth)
        el = float(src.elevation)
        dist = float(src.distance)

        plane_wave = (not np.isfinite(sz)) or (not np.isfinite(dist)) or (not np.isfinite(sx))

        if plane_wave:
            # Plane wave: USTB azimuth/elevation are the steering angles, which
            # map directly to zea polar/azimuth (v = sin(p)cos(a), sin(p)sin(a), cos(p)).
            polar_angles[i] = az
            azimuth_angles[i] = el
            focus_distances[i] = 0.0  # plane wave
            transmit_origins[i] = (0.0, 0.0, 0.0)
            t0_delays[i] = compute_t0_delays_planewave(
                probe_geometry, np.array([az]), np.array([el]), sound_speed
            )[0]
            continue

        if abs(sz) < STA_Z_THRESHOLD_M:
            # Synthetic transmit aperture: virtual source sits on the array
            # surface -> single-element transmit. The active element fires at
            # t=0 and all other elements are masked via tx_apodization=0.
            active = int(np.argmin(np.linalg.norm(probe_geometry - np.array([sx, sy, sz]), axis=1)))
            t0_delays[i] = 0.0
            tx_apod[i] = 0.0
            tx_apod[i, active] = 1.0
            focus_distances[i] = 0.0
            polar_angles[i] = 0.0
            transmit_origins[i] = probe_geometry[active]
            is_sta[i] = True
            source_distances[i] = float(np.linalg.norm(probe_geometry[active]))
            # fd=0 is interpreted as plane-wave in zea; use a short virtual source below
            # the element so spherical STA propagation is used.
            focus_distances[i] = -1e-3
            polar_angles[i] = np.pi / 2
            continue

        # Focused (sz > 0) or diverging (sz < 0) wave with a finite virtual source.
        source = np.array([sx, sy, sz], dtype=np.float64)
        norm = float(np.linalg.norm(source))
        fd_signed = np.sign(sz) * norm
        v = source / fd_signed  # so that origin(0) + fd_signed * v == source
        # Signed in-plane (x-z) steering angle so that left/right beams of a
        # sector scan map to negative/positive polar angles (zea v = (sin p cos a,
        # sin p sin a, cos p); imaging is in the x-z plane so azimuth ~ 0).
        polar = float(np.arctan2(v[0], v[2]))
        azimuth = float(np.arctan2(v[1], np.hypot(v[0], v[2])))

        focus_distances[i] = fd_signed
        polar_angles[i] = polar
        azimuth_angles[i] = azimuth
        transmit_origins[i] = (0.0, 0.0, 0.0)
        t0_delays[i] = compute_t0_delays_focused(
            np.zeros((1, 3)),
            np.array([fd_signed]),
            probe_geometry,
            np.array([polar]),
            np.array([azimuth]),
            sound_speed,
        )[0]

    # Per-wave time reference (C_wave): zea's t0-based helpers shift each transmit
    # so its first element fires at t=0, putting every transmit on a *different*
    # time reference. USTB references every transmit to the array origin (its
    # transmit delay is 0 at the origin for plane, diverging and focused waves),
    # so to compound/scan-convert coherently we add zea's transmit arrival at the
    # origin to initial_times. (STA is handled separately above.)
    origin = np.zeros((1, 3), dtype=np.float32)
    rxdel0 = (np.linalg.norm(origin[:, None, :] - probe_geometry[None, :, :], axis=-1)
              / sound_speed).astype(np.float32)  # (1, n_el)
    for i in range(n_tx):
        if is_sta[i]:
            continue
        arrival = transmit_delays(
            origin, t0_delays[i], tx_apod[i], rxdel0, float(focus_distances[i]),
            float(polar_angles[i]), 0.0, float(azimuth_angles[i]), transmit_origins[i],
        )
        init_correction[i] = float(np.array(arrival)[0])

    # STA initial_times. For Field II STA simulations each transmit's signal starts at
    # its own Field II time t(n), encoded in wave.delay = source.distance/c - lag*dt + t(n).
    # zea reads sample (|elem - pixel|/c + |rx - pixel|/c - initial_times) * fs, so to place
    # every single-element transmit at the correct depth the per-transmit offset must be
    #     initial_times = channel.initial_time + wave.delay - source.distance/c.
    # (Empirically verified against the stored USTB /b_data_das: the - source.distance/c
    # term is what aligns the transmits in depth; +source.distance/c or 0 leave it defocused.)
    #
    # The Verasonics / experimental STA import stores a pre-compensated wave.delay (signed
    # across the aperture) referenced to a common A/D start and is already correct with a
    # constant initial_times; those datasets are verified good and are left untouched
    # (cancel wave.delay -> initial_times = channel.initial_time).
    sta_idx = np.flatnonzero(is_sta)
    if sta_idx.size:
        wd_sta = wave_delays[sta_idx]
        if np.all(wd_sta >= 0):  # Field II geometric wave.delay
            init_correction[sta_idx] = -source_distances[sta_idx] / sound_speed
        else:  # Verasonics / experimental: pre-compensated, keep constant initial_times
            init_correction[sta_idx] = -wave_delays[sta_idx]

    return {
        "t0_delays": t0_delays,
        "tx_apodizations": tx_apod,
        "focus_distances": focus_distances,
        "polar_angles": polar_angles,
        "azimuth_angles": azimuth_angles,
        "transmit_origins": transmit_origins,
        "wave_delays": wave_delays,
        "init_correction": init_correction,
    }


def _reshape_raw(data: np.ndarray):
    """USTB (n_ax, n_el[, n_tx[, n_frames]]) -> zea (n_frames, n_tx, n_ax, n_el, n_ch)."""
    data = np.asarray(data)
    while data.ndim < 4:
        data = data[..., np.newaxis]  # pad trailing wave/frame dims
    # now (n_ax, n_el, n_tx, n_frames)
    data = np.transpose(data, (3, 2, 0, 1))  # (n_frames, n_tx, n_ax, n_el)
    if np.iscomplexobj(data):
        raw = np.stack([data.real, data.imag], axis=-1).astype(np.float32)  # n_ch=2 (IQ)
        is_iq = True
    else:
        raw = data[..., np.newaxis].astype(np.float32)  # n_ch=1 (RF)
        is_iq = False
    return raw, is_iq


def uff_to_zea(channel_data, meta: dict):
    """Build (data, scan, probe, metadata) dicts for ``zea.File.create``."""
    sound_speed = float(channel_data.sound_speed)
    probe_geometry = _probe_geometry(channel_data.probe)

    raw, is_iq = _reshape_raw(channel_data.data)

    center_frequency = 0.0
    if getattr(channel_data, "pulse", None) is not None and channel_data.pulse.center_frequency is not None:
        center_frequency = float(channel_data.pulse.center_frequency)
    modulation_frequency = float(channel_data.modulation_frequency or 0.0)
    if center_frequency <= 0:
        center_frequency = modulation_frequency

    tx = _build_transmit_fields(channel_data, probe_geometry, sound_speed)
    n_tx = tx["t0_delays"].shape[0]

    initial_time = float(channel_data.initial_time or 0.0)
    # USTB computes the data sample for a pixel as
    #   (rx_tof + tx_tof/c - wave_delay - initial_time) * fs
    # while zea uses (rx_tof + tx_arrival - initial_times) * fs with the same
    # geometry. Matching the two gives initial_times = initial_time + wave_delay
    # (+ a per-wave correction for the STA single-element model, see init_correction).
    initial_times = (initial_time + tx["wave_delays"] + tx["init_correction"]).astype(np.float32)

    if is_iq:
        demodulation_frequency = modulation_frequency if modulation_frequency > 0 else center_frequency
    else:
        demodulation_frequency = center_frequency  # demodulate RF in the pipeline

    scan = {
        "sampling_frequency": np.float32(channel_data.sampling_frequency),
        "center_frequency": np.float32(center_frequency),
        "demodulation_frequency": np.float32(demodulation_frequency),
        "sound_speed": np.float32(sound_speed),
        "initial_times": initial_times,
        "t0_delays": tx["t0_delays"],
        "tx_apodizations": tx["tx_apodizations"],
        "focus_distances": tx["focus_distances"],
        "transmit_origins": tx["transmit_origins"],
        "polar_angles": tx["polar_angles"],
        "azimuth_angles": tx["azimuth_angles"],
    }

    probe = {
        "name": meta["probe"],
        "type": meta["probe_type"],
        "probe_geometry": probe_geometry,
        "probe_center_frequency": np.float32(center_frequency),
    }
    pr = channel_data.probe
    if getattr(pr, "element_width", None) is not None:
        probe["element_width"] = np.float32(pr.element_width)
    if getattr(pr, "element_height", None) is not None:
        probe["element_height"] = np.float32(pr.element_height)

    metadata = {
        "credit": "UltraSound ToolBox (USTB), University of Oslo. Zenodo record 20261898.",
        "subject": {"type": "human" if meta["tier"] == "in-vivo-human" else meta["tier"]},
        "annotations": {"view": meta["view"]},
    }

    data = {"raw_data": raw}
    return data, scan, probe, metadata, {"n_tx": n_tx, "is_iq": is_iq, "shape": raw.shape}


def convert_one(filepath: Path, out_path: Path, meta: dict) -> bool:
    from zea import File

    uff_path = meta.get("uff_path", "channel_data")
    channel_data = _read_channel_data(filepath, uff_path)
    if channel_data is None:
        print(f"  SKIP (no {uff_path}): {filepath.name}")
        return False

    data, scan, probe, metadata, info = uff_to_zea(channel_data, meta)
    description = f"USTB dataset {filepath.stem}: {meta['view']} ({meta['tier']})."
    if uff_path != "channel_data":
        description += f" Converted from UFF /{uff_path} (original file also contains /channel_data)."

    File.create(
        path=str(out_path),
        data=data,
        scan=scan,
        probe=probe,
        metadata=metadata,
        us_machine="Verasonics Vantage 256 / Alpinion E-Cube 12R / Field II simulation",
        description=description,
        overwrite=True,
    )
    print(f"  OK: {out_path.name}  raw={info['shape']}  {'IQ' if info['is_iq'] else 'RF'}  n_tx={info['n_tx']}")
    return True


def main():
    parser = argparse.ArgumentParser(description="Convert USTB UFF to OpenH-RF zea HDF5")
    parser.add_argument("--input", type=str, default=r"C:\Data\USTB_data", help="Directory with .uff files")
    parser.add_argument("--output", type=str, default=r"C:\Data\USTB_data\openh_rf_submission", help="Output staging directory")
    parser.add_argument("--groups", type=str, default="", help="Comma-separated subset of groups to convert (default: all)")
    parser.add_argument("--only", type=str, default="", help="Convert only the given filename (debug)")
    args = parser.parse_args()

    in_dir = Path(args.input)
    out_root = Path(args.output)
    out_root.mkdir(parents=True, exist_ok=True)

    selected = set(args.groups.split(",")) if args.groups else set(GROUPS)
    ok = miss = fail = 0

    for group, ginfo in GROUPS.items():
        if group not in selected:
            continue
        gdir = out_root / group
        gdir.mkdir(parents=True, exist_ok=True)
        print(f"\n=== {group}: {ginfo['pretty']} ===")
        for meta in ginfo["datasets"]:
            fn = meta["filename"]
            if args.only and fn != args.only:
                continue
            src = in_dir / fn
            if not src.exists():
                print(f"  MISSING: {fn}")
                miss += 1
                continue
            out_path = gdir / (Path(fn).stem + ".hdf5")
            meta_full = {**meta, "tier": ginfo["tier"]}
            try:
                if convert_one(src, out_path, meta_full):
                    ok += 1
                else:
                    fail += 1
            except Exception as exc:  # noqa: BLE001
                print(f"  ERROR ({fn}): {type(exc).__name__}: {exc}")
                fail += 1

    print(f"\n=== Done: {ok} converted, {miss} missing, {fail} failed ===")


if __name__ == "__main__":
    main()
