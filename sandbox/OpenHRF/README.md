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
| `openhrf_download_subset.py` | Streams a frame range of an OpenH-RF zea file from the Hugging Face Hub into a small, MATLAB-readable (gzip) local file |
| `openhrf_to_uff.m` | MATLAB: OpenH-RF (zea) plane-wave HDF5 -> `uff.channel_data` (the reverse direction) |
| `ULMShare_openhrf_to_uff_example.m` | MATLAB example: ULMShare mouse-brain IQ data -> UFF -> DAS B-mode and power Doppler |

## Reading OpenH-RF data into USTB

`openhrf_to_uff.m` converts OpenH-RF plane-wave acquisitions (currently tested on
[ULMShare](https://huggingface.co/datasets/nvidia/OpenH-RF/tree/main/ulmshare))
to `uff.channel_data`. The ULMShare files are 60-370 GB each and their raw data
is Blosc-compressed, so first stream a frame subset to a local file:

```bash
pip install h5py hdf5plugin huggingface_hub numpy
python openhrf_download_subset.py \
    --source hf://nvidia/OpenH-RF/ulmshare/data/mouse_10_acquisition_1_zea.hdf5 \
    --output C:/Data/OpenH-RF/ulmshare/mouse_10_acquisition_1_frames_20000_20399.hdf5 \
    --first-frame 20000 --n-frames 400
```

then in MATLAB:

```matlab
channel_data = openhrf_to_uff('C:/Data/OpenH-RF/ulmshare/mouse_10_acquisition_1_frames_20000_20399.hdf5');
```

The zea transmit timing (`t0_delays` with min 0, `initial_times`) is mapped to
the USTB origin-referenced plane-wave model as
`wave.delay = initial_times - t_origin`, where `t_origin` is the time the zea
wavefront crosses the origin. See `ULMShare_openhrf_to_uff_example.m` for a
full B-mode / power-Doppler example.

## ULM of ULMShare data

`ULMShare_ULM_example.m` builds a ULM density map of mouse 16, acquisition 1
(Grade A, Fig. 5 of the ULMShare paper) with USTB. Compared with the ULMShare
reference processing ([code/example_script.m](https://github.com/provostultrasoundlab/ulmshare)
with the [TAL toolbox](https://github.com/provostultrasoundlab/TrackingAndLocalizationULM),
Leconte et al., IEEE TMI 2024):

| Step | ULMShare (TAL) | USTB example |
|---|---|---|
| Beamforming | MUST DAS, 25 um grid, F#1.4 | USTB DAS (GPU), same grid and F# |
| Clutter filter | SVD, 5% of the components rejected | same |
| Enhancement | lag-1 autocorrelation; optional local TGC (sigma = 9 px) before a second SVD | lag-1, then the same local normalization (no second SVD) |
| Detection | tracking *before* localization: Jerman vesselness of the (z, x, t) volume, threshold, 3-D thinning into centerlines | the `numberOfParticles` brightest maxima per frame, kept if above `intensity_threshold` |
| Localization | radial symmetry along the centerlines, averaged over 3 frames | radial symmetry per frame (PALA) |
| Linking | given by the centerlines, segments >= 20 frames | Hungarian frame-to-frame linking, 1.5 lambda gate, >= 15 frames |
| Rendering | every spline-interpolated point counted, lambda/10 | each track counted once per pixel, lambda/10 |

Without normalization, the fixed number of maxima per frame fills up with noise
wherever the noise floor is high (deep tissue, where TGC is largest) and with
residual skull clutter near the top. Normalizing by the local RMS and keeping
only localizations with SNR >= 1.5 removes the false band below 7 mm and most
of the haze between vessels (`ulm.ULM.intensity_threshold` was added for this).
A plain-MATLAB version of the TAL tracker (vesselness + `bwskel`) was tried but
needs its own detection threshold before it beats this: on normalized data it
detects noise "tubes" everywhere.

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
