# Coherence Factor beamforming for Ultrasound Localization Microscopy

Code to reproduce the figures and numbers of

> S. A. Bjørn, A. Austeng and O. M. H. Rindal, "Enhanced Ultrasound
> Localization Microscopy through Coherence Factor Adaptive Beamforming"
> (manuscript in preparation),

which is based on Simon Andreas Bjørn's MSc thesis (University of Oslo, 2025).
The scripts compare delay-and-sum (DAS) and coherence factor (CF) beamforming
inside the USTB `+ulm` module (the PALA localizer, tracker and pairing code)
on the two OPULM/PALA datasets that are distributed as raw RF data.

No data is simulated here. Both datasets are downloaded and only processed.

## Data

| Dataset | Source | Put it in |
|---|---|---|
| In silico flow, 20 x 1000 frames | Zenodo [4343435](https://zenodo.org/records/4343435): `PALA_data_InSilicoFlow_RF.zip` and `PALA_data_InSilicoFlow.zip` | `data/PALA_data_InSilicoFlow/` (unzip both) |
| In vivo rat brain, 250 x 800 frames | Zenodo [7883227](https://zenodo.org/records/7883227): `param.mat` and the `RF_xxx_to_yyy.zip` archives | `data/param.mat` and `data/RF/RF_001.hdf5` ... |

`examples/ulm/OPULM_data_preparation_flow.m` and
`examples/ulm/OPLUM_data_preparation_RatBrain.m` download the files (the rat
brain script fetches the first 25 chunks). The scripts in this folder read the
downloaded files directly, one chunk at a time, so the UFF files written by
those examples are not needed.

Paths, beamforming settings, ULM parameters and regions of interest are all in
`ulm_paper_config.m`.

## How to run

```matlab
addpath(<path to USTB>)
cd publications/TUSON/Bjorn_et_al_Coherence_Factor_Beamforming_for_ULM

process_insilico              % about 2 minutes per chunk, 20 chunks
figures_insilico

process_invivo                % about 2.5 minutes per chunk, up to 250 chunks
figures_invivo
figure_invivo_svd_placement
```

The two `process_*` scripts write one result file per chunk to
`data/ULM_coherence_paper/` and skip chunks that are already there, so they can
be stopped and restarted. Set `chunks` first to process a subset, for example
`chunks = 1:5; process_invivo`. The `figures_*` scripts use whatever chunks have
been processed. Figures are written to `data/ULM_coherence_paper/figures/` with
the file names and sub-folders of the manuscript's `figures/` folder.

Requirements: MATLAB with the Image Processing Toolbox (used by `+ulm`), the
USTB MEX beamformer, and about 32 GB of RAM (lower `frames_per_batch` in the
config if memory is short).

## Which script makes which figure

| Manuscript item | File | Script |
|---|---|---|
| Fig. 3, clutter-filter placement | `invivo/svd/das_SVD.jpg`, `cf_SVD_after.jpg`, `cf_SVD.jpg` | `figure_invivo_svd_placement` |
| Fig. 4, ground truth and regions | `opulm_flow/fig1_Target.pdf` | `figures_insilico` |
| Fig. 5, reconstructed regions | `opulm_flow/2_per_lambda/fig2_horseshoe.pdf`, `fig2_flow.pdf`, `fig2_cross.pdf` | `figures_insilico` |
| Fig. 6, axial separation | `opulm_flow/fig6_gap.pdf` | `figures_insilico` |
| Fig. 7, lateral separation | `opulm_flow/fig7_horizontal_gap.pdf` | `figures_insilico` |
| Fig. 8, TP, FN and FP | `opulm_flow/2_per_lambda/fig3_TP_FP_FN.pdf` | `figures_insilico` |
| Fig. 9, precision, sensitivity, Jaccard | `opulm_flow/2_per_lambda/fig5_Jacc.pdf` | `figures_insilico` |
| Numbers in the simulation results text | `opulm_flow/insilico_statistics.txt` | `figures_insilico` |
| Fig. 10, rat brain DAS against CF | `invivo/parameters/compare_generic.png`, `compare_generic1.png` to `3.png` | `figures_invivo` |
| Fig. 11 and metrics table | `invivo/parameters/metrics_comparison.png`, `invivo_metrics.txt` | `figures_invivo` |

Figs. 1 and 2 of the manuscript are drawings, and the numbered arrows and boxes
in Fig. 10 were added by hand.

## Files

| File | Purpose |
|---|---|
| `ulm_paper_config.m` | all paths and parameters |
| `insilico_load_chunk.m`, `invivo_load_chunk.m` | read one chunk of RF data into `uff.channel_data` |
| `beamform_das_cf.m` | DAS and CF from the same delayed data, in batches of frames |
| `run_ulm.m` | localization and tracking with `ulm.ULM` |
| `ulm_density_image.m` | accumulate tracks into a ULM image |
| `match_histogram.m`, `ulm_image_metrics.m` | normalization, histogram matching and the three in vivo indices |
| `process_insilico.m`, `process_invivo.m` | the processing pipelines |
| `figures_insilico.m`, `figures_invivo.m`, `figure_invivo_svd_placement.m` | the figures |

## Processing in short

In silico: white Gaussian noise is added to the RF data (10 dB SNR, measured on
the mean signal power of the chunk), the data is beamformed on a lambda/2 grid
with a Hamming receive apodization at F# 0.8, and bubbles are localized with the
radial symmetry method and tracked with the Hungarian tracker using the
Jaccard-optimal parameters of each beamformer. Localizations along accepted
tracks are paired with the true positions (lambda/4 for a true positive).
Precision, sensitivity and the Jaccard index are computed per chunk, and the
mean and standard deviation over the chunks are reported.

In vivo: the SVD clutter filter is applied to the RF channel data of each chunk
before beamforming (F# 1.5, lambda/2 grid). ULM is run with the same
parameters for both beamformers. Tracks from all
chunks are accumulated on a lambda/12 grid.

## Where this differs from the thesis, and open points

The scripts that made the thesis figures were not available, so everything here
was rewritten on top of the `+ulm` module and the example scripts. The pipeline
follows the thesis, but these choices are not stated there and had to be made:

- **Noise.** The SNR definition (mean signal power of the whole chunk) and the
  noise realization (seeded per chunk).
- **In vivo `NLocalMax` and `numberOfParticles`.** The
  `ulm.ULM` defaults (3 and 70) are used.
- **SVD cutoff.** `cutoff = 5`, which removes the first four singular vectors,
  as PALA does. `examples/ulm/ULM_RatBrain_example.m` uses `cutoff = 2`, but
  that leaves most accepted tracks on stationary residual clutter: on one
  800-frame chunk about 20 tracks move more than two wavelengths with
  `cutoff = 2`, against about 120 with `cutoff = 5`. The value used for the
  thesis figures must be confirmed.
- **One in vivo parameter set.** The thesis also runs the simulation-tuned
  parameters on the in vivo data. That comparison is not part of the
  manuscript and is not reproduced here.
- **Image indices.** A 15 x 15 window for the local standard deviation,
  256 histogram bins, the DAS image as the histogram-matching
  reference, and that the indices and the difference image are computed on
  the power-compressed images (exponent 1/3) that are displayed.
- **Vessel separation (Figs. 6 and 7).** The measured gap is the widest run of
  pixels below 5 % of the ground-truth maximum between the two canals. The
  simulated distance is a straight line fitted to the gap measured on the
  ground-truth image.
- **Ground-truth image.** Rendered from the true trajectories
  (`PALA_InSilicoFlow_v3_pos_Tracks_dt.mat`) on the same lambda/12 grid as the
  reconstructions.

Facts read from the datasets that the manuscript text should be checked against:

- The in silico flow data has three plane waves (0 and +/- 4.76 degrees), not five.
- The in silico frame rate is 500 Hz and the in vivo frame rate is 1000 Hz.
- The rat-brain pixel grid shipped with the data is already lambda/2, so it is
  not upsampled.
