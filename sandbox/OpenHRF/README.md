# OpenH-RF Contribution: USTB Datasets

This folder contains the proposal and conversion/packaging tools for
contributing USTB (UltraSound ToolBox) datasets to the
[OpenH-RF](https://github.com/open-h/OpenH-RF) initiative.

## Contents

| File | Description |
|------|-------------|
| `proposal.tex` | 2-page LaTeX proposal for the OpenH-RF RFP |
| `convert_ustb_to_openh_rf.py` | UFF -> zea HDF5 conversion (spec-compliant `zea.File.create`), grouped A-F |
| `make_submission.py` | Builds the submission: root `reconstruct.py`/`pipeline.yaml`/`LICENCE` + per-group data cards |
| `submission_template/` | Canonical `reconstruct.py`, `pipeline.yaml`, `LICENCE` (placed once at the submission root) |
| `validate_submission.py` | Validates every output `.hdf5` against the zea spec (`File.validate` / `File.validate_spec`) |
| `write_eval_reports.py` | Runs the `openh-rf-submission-eval` rubric and writes per-group + top-level reports |
| `export_openhrf_previews.m` | MATLAB: renders the canonical USTB DAS reference B-mode PNGs (catalog-matching) |
| `convert_ustb_to_openh_rf_matlab.m` | Legacy MATLAB prototype (superseded by the Python converter) |
| `generate_labels.m` | MATLAB script: DAS beamforming labels |

## PICMUS policy

PICMUS-sourced acquisitions are **excluded** from this submission, with one
exception: `PICMUS_numerical_calib_v2`. That numerical-calibration acquisition was
created by the USTB group in a follow-up to the PICMUS effort, so it is retained
(and documented as such in the group E data card). The excluded PICMUS files are
the in-vivo carotid (`PICMUS_carotid_cross`, `PICMUS_carotid_long`), the
experimental resolution/contrast (`PICMUS_experiment_*`), and the simulated
resolution/contrast (`PICMUS_simulation_*`) acquisitions.

## Submission layout

The submission is packaged as **6 application sub-datasets** (one data card each):

| Group | Folder | Tier | Acquisitions |
|---|---|---|---|
| A | `A_cardiac` | in-vivo human | 3 |
| B | `B_carotid` | in-vivo human | 3 |
| C | `C_verasonics_phantom` | phantom | 15 |
| D | `D_alpinion_phantom` | phantom | 4 |
| E | `E_simulation` | simulation | 12 (incl. 1 PICMUS calibration) |
| F | `F_motion` | phantom (SWE/ARFI) | 4 |

**Total: 41 eligible channel-capture acquisitions.** Four UFF files referenced in
the proposal (`reference_RTB_data`, `invitro_20`, `insilico_20`,
`insilico_side_100_M45`) contain only beamformed data (no raw channel data) and
are therefore not eligible for OpenH-RF (which requires `/data/raw_data`).

The submission **root** holds a single `reconstruct.py`, `pipeline.yaml` and
`LICENCE` (CC BY 4.0) that cover the whole collection — `reconstruct.py` is
geometry-driven and recurses into every group folder. Each **group folder** holds
its `*.hdf5` (zea), `README.md` (data card), and `*_bmode.png` / `*_zea_bmode.png`
reference reconstructions.

## Quick start

The conversion/reconstruction tooling requires `zea` (>= v0.1.0a3; we used v0.1.0)
and `pyuff-ustb`. We use the OpenH-RF environment (`uv sync` in the OpenH-RF repo)
which pins `zea`, plus `uv pip install pyuff-ustb`.

```bash
# 1. Convert all UFF datasets to zea HDF5, grouped into A-F
python convert_ustb_to_openh_rf.py --input C:/Data/USTB_data \
    --output C:/Data/USTB_data/openh_rf_submission

# 2. Build the root reconstruct.py / pipeline.yaml / LICENCE and per-group data cards
python make_submission.py --output C:/Data/USTB_data/openh_rf_submission

# 3. Render reference B-mode PNGs (one root script reconstructs every group folder)
python C:/Data/USTB_data/openh_rf_submission/reconstruct.py

# 4. (optional) Validate + self-evaluate the submission
python validate_submission.py
python write_eval_reports.py
```

## Dataset source

All datasets are hosted on Zenodo:
- **Record 20261898**: https://zenodo.org/records/20261898
- **License**: MIT (code), CC BY 4.0 (data contribution to OpenH-RF)

## Links

- OpenH-RF: https://github.com/open-h/OpenH-RF
- USTB: https://github.com/unioslo/USTB
- USTB website: https://www.ultrasoundtoolbox.com
