"""Assemble OpenH-RF submission folders for each USTB application sub-dataset.

For every group folder produced by ``convert_ustb_to_openh_rf.py`` this script:

* copies ``reconstruct.py``, ``pipeline.yaml`` and ``LICENCE`` into the folder,
* introspects the converted ``*.hdf5`` files (frames, transmits, samples,
  elements, sampling/center frequency, sound speed, probe, size on disk),
* writes a Hugging Face-style ``README.md`` data card with YAML frontmatter and
  every section required by the OpenH-RF submission guide.

Run after the conversion step::

    python make_submission.py --output C:/Data/USTB_data/openh_rf_submission
"""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path

import h5py
import numpy as np

TEMPLATE_DIR = Path(__file__).resolve().parent / "submission_template"

CONTRIBUTORS = (
    "University of Oslo (UiO), Department of Informatics. "
    "Primary contact: Ole Marius Hoel Rindal (omrindal@ifi.uio.no). "
    "Team: Ole Marius Hoel Rindal, Yucel Karabiyik, Sven Peter Nasholm, Andreas Austeng."
)
CREATION_DATE = "06/23/2026"  # packaging date; original acquisitions span 2016-2023
CREDIT_LINE = (
    "The UltraSound ToolBox (USTB) Channel Capture Collection, University of Oslo. "
    "Contributed to OpenH-RF. Zenodo record 20261898."
)

# Per-group descriptive content -------------------------------------------------
GROUPS: dict[str, dict] = {
    "A_cardiac": {
        "pretty": "USTB - In-vivo Cardiac (Verasonics P4-2)",
        "collection": "clinical",
        "tier": "in-vivo human (research platform)",
        "task_categories": ["image-to-image"],
        "tags": ["ultrasound", "rf", "openh-rf", "cardiac", "in-vivo"],
        "rfp_task": "6.1 Generalized Reconstruction",
        "description": (
            "In-vivo human cardiac channel-capture data acquired with a Verasonics Vantage 256 "
            "research scanner and a P4-2 phased-array probe. The collection contains parasternal "
            "long-axis and apical four-chamber views recorded with focused transmit beams (sector "
            "scan). The data is pre-beamformed RF channel data intended for research into "
            "generalized beamforming, adaptive imaging and cardiac reconstruction."
        ),
        "intended": (
            "Generalized reconstruction and adaptive beamforming of cardiac ultrasound "
            "(RFP task 6.1). Suitable for B-mode reconstruction, aperture-domain processing, "
            "and deep-learning beamforming research on in-vivo cardiac data."
        ),
        "labeling": "N/A (raw channel data; no annotations).",
        "subject_meta": (
            "Healthy adult volunteer(s). Anatomy: heart (parasternal long-axis, apical four-chamber). "
            "Scanner: Verasonics Vantage 256. Probe: P4-2 phased array (64 elements). "
            "Aggregate only; no per-subject identifiers are stored."
        ),
        "ethics": (
            "In-vivo data recorded from healthy adult volunteers at the University of Oslo with "
            "written informed consent for research use and data sharing, and approval from the "
            "Regional Committee for Medical and Health Research Ethics (REK), Norway. The files "
            "contain only backscattered RF channel data and acquisition parameters - no patient "
            "name, identifier, date of birth, acquisition date, facial image, or any other HHS "
            "Safe Harbor identifier is present (de-identified by construction)."
        ),
        "known_issues": (
            "Focused sector acquisition: lateral resolution and field of view follow the transmit "
            "geometry. Phased-array data is best reconstructed on a polar (sector) grid. "
            "Frame counts vary per acquisition."
        ),
    },
    "B_carotid": {
        "pretty": "USTB - In-vivo Carotid (Verasonics L7-4)",
        "collection": "clinical",
        "tier": "in-vivo human (research platform)",
        "task_categories": ["image-to-image"],
        "tags": ["ultrasound", "rf", "openh-rf", "vascular", "carotid", "in-vivo"],
        "rfp_task": "6.1 Generalized Reconstruction",
        "description": (
            "In-vivo human carotid-artery channel-capture data acquired with a Verasonics Vantage "
            "256 and an L7-4 linear-array probe, cross-sectional views, focused transmit imaging. "
            "Pre-beamformed RF channel data for vascular imaging and beamforming research."
        ),
        "intended": (
            "Generalized reconstruction and adaptive beamforming of vascular ultrasound "
            "(RFP task 6.1)."
        ),
        "labeling": "N/A (raw channel data; no annotations).",
        "subject_meta": (
            "Healthy adult volunteer(s). Anatomy: carotid artery (cross-section). "
            "Scanner: Verasonics Vantage 256. Probe: L7-4 linear array (128 elements). "
            "Aggregate only; no per-subject identifiers."
        ),
        "ethics": (
            "In-vivo data recorded from healthy adult volunteers at the University of Oslo with "
            "written informed consent for research use and data sharing, and approval from the "
            "Regional Committee for Medical and Health Research Ethics (REK), Norway. Files contain "
            "only RF channel data and acquisition parameters; no HHS Safe Harbor identifiers are "
            "present."
        ),
        "known_issues": "Single/few-frame acquisitions; focused linear imaging.",
    },
    "C_verasonics_phantom": {
        "pretty": "USTB - Phantom (Verasonics L7-4 / P4)",
        "collection": "phantom",
        "tier": "phantom / table-top",
        "task_categories": ["image-to-image"],
        "tags": ["ultrasound", "rf", "openh-rf", "phantom", "cirs"],
        "rfp_task": "6.1 Generalized Reconstruction",
        "description": (
            "Tissue-mimicking and table-top phantom channel-capture data acquired on a Verasonics "
            "Vantage 256 with L7-4 linear and P4 phased-array probes. The collection spans coherent "
            "plane-wave compounding (CPWC), focused imaging (FI), synthetic transmit aperture (STA) "
            "and diverging-wave (DW) sequences for resolution, contrast, dynamic-range and "
            "point-spread-function evaluation, including CIRS tissue-mimicking phantom targets."
        ),
        "intended": (
            "Generalized reconstruction, image-quality assessment (resolution, contrast, dynamic "
            "range), and beamforming research (RFP task 6.1). Several acquisitions provide multiple "
            "transmit schemes on the same target for cross-method comparison."
        ),
        "labeling": "Derived (known phantom geometry, e.g. CIRS Model 040GSE where applicable).",
        "subject_meta": (
            "No human or animal subjects. Targets: CIRS tissue-mimicking phantoms and lab phantoms "
            "(wire/point targets, hypo/hyperechoic inclusions, dynamic-range targets). "
            "Probes: L7-4 (128 el.), P4 phased array."
        ),
        "ethics": (
            "Phantom / table-top acquisitions; no human or animal subjects are involved. No ethical "
            "considerations beyond standard laboratory practice."
        ),
        "known_issues": (
            "Mixed transmit schemes across files (CPWC / FI / STA / DW). Single-frame acquisitions "
            "for most phantoms. The reference reconstruction uses a single B-mode pipeline; "
            "per-scheme tuning may improve image quality."
        ),
    },
    "D_alpinion_phantom": {
        "pretty": "USTB - Phantom (Alpinion L3-8)",
        "collection": "phantom",
        "tier": "phantom / table-top",
        "task_categories": ["image-to-image"],
        "tags": ["ultrasound", "rf", "openh-rf", "phantom", "alpinion"],
        "rfp_task": "6.1 Generalized Reconstruction",
        "description": (
            "Phantom channel-capture data acquired on an Alpinion E-Cube 12R research scanner with "
            "an L3-8 linear-array probe. Hypoechoic and hyperechoic targets imaged with focused (FI) "
            "and coherent plane-wave compounding (CPWC) sequences."
        ),
        "intended": (
            "Generalized reconstruction and image-quality assessment on a second hardware platform "
            "(RFP task 6.1); cross-vendor robustness studies."
        ),
        "labeling": "Derived (known phantom target types).",
        "subject_meta": (
            "No human or animal subjects. Targets: hypoechoic/hyperechoic phantom inclusions. "
            "Scanner: Alpinion E-Cube 12R. Probe: L3-8 linear array (128 elements)."
        ),
        "ethics": (
            "Phantom acquisitions; no human or animal subjects. No ethical considerations beyond "
            "standard laboratory practice."
        ),
        "known_issues": "Single-frame acquisitions; two transmit schemes (FI, CPWC).",
    },
    "E_simulation": {
        "pretty": "USTB - Simulation (Field II)",
        "collection": "synthetic",
        "tier": "simulation (digital)",
        "task_categories": ["image-to-image"],
        "tags": ["ultrasound", "rf", "openh-rf", "simulation", "field-ii", "synthetic"],
        "rfp_task": "6.1 Generalized Reconstruction",
        "description": (
            "Physics-based synthetic channel-capture data generated with the Field II ultrasound "
            "simulation framework. The collection covers point scatterers, cysts, speckle, "
            "dynamic-range targets and blocked-array (aperture-apodized) configurations, using "
            "linear (L7-4-like) and phased (P4-like) virtual probes with CPWC, FI and STA sequences. "
            "Because the scattering medium is fully defined, exact ground-truth scatterer positions "
            "and medium parameters are known. One numerical calibration acquisition "
            "(PICMUS_numerical_calib_v2) was created in collaboration with our group as part of the "
            "PICMUS effort; it is included here while the other PICMUS datasets are excluded (see Known Issues)."
        ),
        "intended": (
            "Generalized reconstruction, beamformer development and validation with known "
            "ground truth (RFP task 6.1); resolution/contrast/dynamic-range characterization; "
            "training/validation of learned reconstruction methods."
        ),
        "labeling": "Synthetic ground truth (known scatterer positions and medium parameters).",
        "subject_meta": (
            "No human or animal subjects. Synthetic media simulated with Field II. "
            "Virtual probes: L7-4-like linear and P4-like phased arrays."
        ),
        "ethics": (
            "Fully synthetic data generated with the Field II simulation framework; no human or "
            "animal subjects. No personal data is present. The included numerical calibration file "
            "was produced in collaboration with our group as part of the PICMUS effort (IEEE IUS 2016) "
            "and is released here under CC BY 4.0."
        ),
        "known_issues": (
            "PICMUS calibration: 'PICMUS_numerical_calib_v2' was created in collaboration with our "
            "group as part of the PICMUS (Plane-wave Imaging Challenge in Medical UltraSound, IEEE IUS "
            "2016) effort, and is therefore included here. The other PICMUS acquisitions (in-vivo "
            "carotid, experimental and simulated resolution/contrast) are deliberately excluded from "
            "this submission. Simulation framework: Field II (Jensen et al.)."
        ),
    },
    "F_motion": {
        "pretty": "USTB - Motion Estimation (SWE / ARFI, Verasonics L7-4)",
        "collection": "phantom",
        "tier": "phantom / table-top",
        "task_categories": ["image-to-image"],
        "tags": ["ultrasound", "rf", "openh-rf", "elastography", "shear-wave", "arfi"],
        "rfp_task": "6.4 Motion Estimation",
        "description": (
            "Shear-wave elastography (SWE) and acoustic-radiation-force-impulse (ARFI) "
            "push-tracking phantom acquisitions on a Verasonics Vantage 256 with an L7-4 linear "
            "array. Each acquisition contains many high-frame-rate tracking frames following an "
            "acoustic push, suitable for tissue-motion and shear-wave-velocity estimation."
        ),
        "intended": (
            "Motion estimation (RFP task 6.4): shear-wave velocity estimation, ARFI displacement "
            "tracking, and high-frame-rate motion reconstruction."
        ),
        "labeling": "Derived (elastography phantom of known/typical stiffness classes).",
        "subject_meta": (
            "No human or animal subjects. Elastography phantoms. "
            "Scanner: Verasonics Vantage 256. Probe: L7-4 linear array (128 elements)."
        ),
        "ethics": (
            "Phantom acquisitions; no human or animal subjects. No ethical considerations beyond "
            "standard laboratory practice."
        ),
        "known_issues": (
            "Push-track sequences contain many frames at a high frame rate; the B-mode reference "
            "reconstruction shows a single tracking frame. Displacement/velocity estimation requires "
            "frame-to-frame processing not included in the reference pipeline. The displacement "
            "estimation as implemented in the UltraSound ToolBox (USTB) can be provided/added for "
            "these motion datasets on request if needed."
        ),
    },
}


def _h5_raw_and_scan(h5: h5py.File):
    """Return (raw_dataset, scan_group, probe_group) handling track / flat layout."""
    if "tracks" in h5:
        track = h5["tracks"]["track_0"]
        raw = track["data"]["raw_data"]
        scan = track["scan"]
    else:
        raw = h5["data"]["raw_data"]
        scan = h5["scan"]
    probe = h5["probe"] if "probe" in h5 else None
    return raw, scan, probe


def _scalar(group, key, default=None):
    if group is not None and key in group:
        return np.array(group[key]).item()
    return default


def introspect(path: Path) -> dict:
    with h5py.File(str(path), "r") as h5:
        raw, scan, probe = _h5_raw_and_scan(h5)
        shape = tuple(int(x) for x in raw.shape)
        info = {
            "name": path.stem,
            "shape": shape,
            "dtype": str(raw.dtype),
            "n_ch": shape[-1] if len(shape) == 5 else 1,
            "fs": _scalar(scan, "sampling_frequency"),
            "cf": _scalar(scan, "center_frequency"),
            "c": _scalar(scan, "sound_speed"),
            "zea_version": h5.attrs.get("zea_version", "unknown"),
            "probe_name": None,
            "probe_type": None,
            "n_el": None,
            "size_mb": path.stat().st_size / 1e6,
        }
        if probe is not None:
            if "name" in probe:
                info["probe_name"] = np.array(probe["name"]).item()
                if isinstance(info["probe_name"], bytes):
                    info["probe_name"] = info["probe_name"].decode()
            if "type" in probe:
                info["probe_type"] = np.array(probe["type"]).item()
                if isinstance(info["probe_type"], bytes):
                    info["probe_type"] = info["probe_type"].decode()
            if "probe_geometry" in probe:
                info["n_el"] = int(probe["probe_geometry"].shape[0])
    return info


def feature_table(infos: list[dict]) -> str:
    rows = [
        ("data/raw_data", "(n_frames, n_tx, n_ax, n_el, n_ch)", "float32", "a.u.", "Raw pre-beamformed RF channel data"),
        ("scan/sampling_frequency", "scalar", "float32", "Hz", "A/D sampling frequency"),
        ("scan/center_frequency", "scalar", "float32", "Hz", "Transmit pulse center frequency"),
        ("scan/demodulation_frequency", "scalar", "float32", "Hz", "Demodulation (carrier) frequency"),
        ("scan/sound_speed", "scalar", "float32", "m/s", "Assumed medium speed of sound"),
        ("scan/initial_times", "(n_tx,)", "float32", "s", "A/D start time per transmit"),
        ("scan/t0_delays", "(n_tx, n_el)", "float32", "s", "Per-element transmit fire times"),
        ("scan/tx_apodizations", "(n_tx, n_el)", "float32", "-", "Per-element transmit apodization"),
        ("scan/focus_distances", "(n_tx,)", "float32", "m", "Focus distance per transmit (0 = plane wave)"),
        ("scan/polar_angles", "(n_tx,)", "float32", "rad", "Transmit steering (polar) angle"),
        ("scan/transmit_origins", "(n_tx, 3)", "float32", "m", "Transmit beam origin (x, y, z)"),
        ("probe/probe_geometry", "(n_el, 3)", "float32", "m", "Element positions (x, y, z)"),
    ]
    lines = ["| Field | Shape | Dtype | Units | Description |", "|---|---|---|---|---|"]
    for r in rows:
        lines.append("| `{}` | `{}` | {} | {} | {} |".format(*r))
    return "\n".join(lines)


def acquisition_table(infos: list[dict]) -> str:
    lines = [
        "| Acquisition | frames | transmits | samples | elements | n_ch | fs (MHz) | fc (MHz) | size (MB) |",
        "|---|---|---|---|---|---|---|---|---|",
    ]
    for i in infos:
        s = i["shape"]
        nfr, ntx, nax, nel = (s + (1, 1, 1, 1))[:4]
        lines.append(
            "| `{}` | {} | {} | {} | {} | {} | {:.1f} | {:.2f} | {:.0f} |".format(
                i["name"], nfr, ntx, nax, nel, i["n_ch"],
                (i["fs"] or 0) / 1e6, (i["cf"] or 0) / 1e6, i["size_mb"],
            )
        )
    return "\n".join(lines)


def size_category(total_mb: float) -> str:
    # crude HF size_categories by number of acquisitions handled by caller; this maps by samples
    return "n<1K"


def write_readme(group: str, gdir: Path, infos: list[dict]):
    g = GROUPS[group]
    n_acq = len(infos)
    total_frames = sum((i["shape"] + (1,))[0] for i in infos)
    total_mb = sum(i["size_mb"] for i in infos)
    n_ch_set = sorted({i["n_ch"] for i in infos})
    data_type = "RF (n_ch=1)" if n_ch_set == [1] else "RF/IQ (n_ch in {})".format(n_ch_set)
    probes = sorted({i["probe_name"] for i in infos if i["probe_name"]})
    zea_versions = sorted({str(i["zea_version"]) for i in infos})

    frontmatter = (
        "---\n"
        f'pretty_name: "{g["pretty"]}"\n'
        "license: cc-by-4.0\n"
        "task_categories:\n"
        + "".join(f"  - {t}\n" for t in g["task_categories"])
        + "language:\n  - en\n"
        "tags:\n"
        + "".join(f"  - {t}\n" for t in g["tags"])
        + "size_categories:\n  - n<1K\n"
        "---\n"
    )

    body = f"""
# {g['pretty']}

Part of the **UltraSound ToolBox (USTB) Channel Capture Collection** contributed to the
[OpenH-RF](https://github.com/open-h/OpenH-RF) initiative. All acquisitions are stored in the
*zea* HDF5 file format (zea_version {", ".join(zea_versions)}) and contain raw pre-beamformed
channel data (`/data/raw_data`).

## Dataset Description

{g['description']}

## Dataset Contributors

{CONTRIBUTORS}

## Dataset Creation Date

{CREATION_DATE} (packaging date; original acquisitions/simulations were produced between 2016 and 2023).

## License / Terms of Use

Released under **Creative Commons Attribution 4.0 International (CC BY 4.0)** — see the `LICENCE`
file at the submission root (this license is also declared in the YAML frontmatter above). The
contributed data is cleared for this license. {CREDIT_LINE}

## Intended Usage

{g['intended']} (OpenH-RF RFP task {g['rfp_task']}).

## Dataset Characterization

- **Data Collection Method:** {g['collection']}
- **Labeling Method:** {g['labeling']}
- **Acquisition system:** probe(s) {", ".join(probes) if probes else "see table"};
  element positions stored in `/probe/probe_geometry` (meters); center frequency, sampling
  frequency and sound speed stored per acquisition in `/scan` (see per-sample feature table).

## Dataset Format

All acquisitions are stored in the **zea** HDF5 file format. Each `.hdf5` file is a single
acquisition with raw channel data `/data/raw_data` of shape
`(n_frames, n_tx, n_ax, n_el, n_ch)` and a fully populated `/scan` group describing the transmit
sequence (delays, focus distances, steering angles, apodization, timing). Data type: {data_type}.
No demodulation or decimation was applied during packaging beyond conversion from the USTB
Ultrasound File Format (UFF) to zea; RF data is demodulated inside the reconstruction pipeline.

## Dataset Quantification

- **Number of acquisitions:** {n_acq}
- **Total channel-capture frames:** {total_frames}
- **Train / validation / test split:** not predefined (research dataset).
- **Total size on disk:** {total_mb:.0f} MB

Per-acquisition summary:

{acquisition_table(infos)}

Per-sample feature table:

{feature_table(infos)}

## Subject Metadata

{g['subject_meta']}

## Data Validation

A Delay-And-Sum `zea.Pipeline` is provided in the **`pipeline.yaml` at the submission root** and
run by the single **`reconstruct.py` at the submission root**:
`cast -> demodulate -> delay-and-sum beamform -> envelope detect -> normalize -> log compress`
(RF is demodulated in-pipeline; IQ uses a baseband pipeline). The script is geometry-driven and
recurses into every sub-dataset folder; running `python reconstruct.py` from the root reconstructs
every `.hdf5` in the collection (or pass `--input <file>.hdf5` for a single acquisition) and writes
`<name>_zea_bmode.png` next to each file as a portable check that the recorded geometry and timing
are correct.

The reference B-mode images committed alongside the data (`<name>_bmode.png`) are produced with the
UltraSound ToolBox (USTB) MATLAB Delay-And-Sum beamformer — the exact per-dataset reconstruction
used in the public USTB dataset catalog (https://unioslo.github.io/USTB/datasets.html), with
scanline transmit apodization for focused/sector acquisitions and correct sector-scan geometry.
These are the recommended reference reconstructions for visual verification.

## Known Issues

{g['known_issues']}

## Ethical Considerations

{g['ethics']}
"""
    (gdir / "README.md").write_text(frontmatter + body, encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=str, default=r"C:\Data\USTB_data\openh_rf_submission")
    args = parser.parse_args()
    out_root = Path(args.output)

    # Three reconstruction scripts (each with a matching pipeline.yaml) + LICENCE for the
    # whole collection, at the root. All are geometry-driven and recurse into every
    # sub-dataset folder; the single CC BY 4.0 LICENCE covers the whole submission (each
    # data card also declares `license: cc-by-4.0` in its YAML frontmatter).
    #   - reconstruct.py / pipeline.yaml           : geometry-driven Delay-And-Sum
    #   - reconstruct_v2.py / pipeline_v2.yaml      : pressure-field-weighted DAS pipeline
    #   - reconstruct_REFoCUS.py / pipeline_refocus.yaml : REFoCUS + pfield DAS
    root_templates = (
        "reconstruct.py", "pipeline.yaml",
        "reconstruct_v2.py", "pipeline_v2.yaml",
        "reconstruct_REFoCUS.py", "pipeline_refocus.yaml",
        "LICENCE",
    )
    for tmpl in root_templates:
        shutil.copy2(TEMPLATE_DIR / tmpl, out_root / tmpl)
    print("wrote root reconstruction scripts + pipeline YAMLs + LICENCE")

    for group in GROUPS:
        gdir = out_root / group
        if not gdir.exists():
            print(f"SKIP {group}: folder not found")
            continue
        hdf5s = sorted(gdir.glob("*.hdf5"))
        if not hdf5s:
            print(f"SKIP {group}: no .hdf5 files")
            continue
        print(f"\n=== {group}: {len(hdf5s)} acquisitions ===")
        infos = [introspect(p) for p in hdf5s]
        write_readme(group, gdir, infos)
        for i in infos:
            print(f"  {i['name']}: shape={i['shape']} probe={i['probe_name']} zea={i['zea_version']}")
        print(f"  wrote README.md")


if __name__ == "__main__":
    main()
