# OpenH-RF Submission Form — Draft Answers

Prepared for copy-paste into the Google Form at:
https://docs.google.com/forms/d/e/1FAIpQLScbC1FEknFM0tNjKXh_lWi5u-Ly02WxhjK8uEDry1MatyCm7A/viewform

---

## Lead Contact

**Name:** Ole Marius Hoel Rindal

**Email:** olemarius@olemarius.net

**Institution:** University of Oslo (UiO), Department of Informatics

**Country:** Norway

---

## Proposal Title

The UltraSound ToolBox (USTB) Channel Capture Dataset

---

## Executive Summary (≤500 words)

We propose to contribute 53 pre-beamformed (channel capture) ultrasound datasets from the UltraSound ToolBox (USTB) initiative to OpenH-RF. The USTB is an open-source toolbox for ultrasound beamforming, processing, and visualization, maintained since 2017 at the University of Oslo and used widely in the ultrasound research community.

The datasets span in-vivo human cardiac and carotid imaging, tissue-mimicking phantoms (CIRS), and physics-based Field II simulations. They cover linear, phased-array, and convex probes with plane-wave, diverging-wave, focused, and synthetic-transmit-aperture sequences — representing the diversity of modern ultrasound acquisition strategies.

All data is openly hosted on Zenodo (record 20261898) under the MIT license and stored in the community-standard Ultrasound File Format (UFF/HDF5). We provide a conversion pipeline (pyuff-ustb → zea, and a MATLAB equivalent using h5create/h5write) that maps UFF channel data to the OpenH-RF format, along with DAS reference reconstructions and processing scripts. For simulated and phantom data, true ground truth (scatterer position maps, known phantom geometry) is available.

Our contribution includes 8 in-vivo human datasets (cardiac parasternal/apical views and carotid cross-sections), 4 shear wave elastography and ARFI datasets, and over 40 phantom and simulation datasets covering resolution, contrast, dynamic range, speckle, and point-spread-function evaluation. We confirm intent to release the converted data under CC BY 4.0 as required by OpenH-RF.

---

## Target Task Groups

- [x] 6.1 Generalized Reconstruction
- [ ] 6.2 Blood Flow Measurements
- [ ] 6.3 Quantitative Imaging/Measurements
- [x] 6.4 Motion Estimation (Shear Wave Elastography, ARFI)
- [ ] 6.5 Ultrasound Interpretation
- [ ] 6.6 Other Applications

---

## Data Tiers & Estimated Measurements

| Tier | Count | Details |
|------|-------|---------|
| In-Vivo Human (research platform) | 8 | 3 cardiac (P2-4), 5 carotid (L7-4) |
| Phantom / Table-Top | ~25 | CIRS, elastography, dynamic range, point targets |
| Simulation (Digital) | ~20 | Field II (linear + phased array, various configurations) |

**Total measurements:** 53 channel capture datasets

**Weighted contribution:** ~365 equivalent (8 × 40 + 45 × 1)

---

## Sensor Hardware

- Verasonics Vantage (research ultrasound platform)
  - P2-4 phased array (64 elements, cardiac)
  - L7-4 linear array (128 elements, general/vascular)
- Alpinion E-Cube 12R
  - L3-8 linear array (128 elements)
- Field II simulation framework (various virtual probes: P4-1, L7-4)

---

## Estimated Number of Frames

Varies per dataset:
- Cardiac in-vivo: 10–100+ frames per acquisition
- Carotid in-vivo: 1–10 frames
- Phantom: 1 frame (single acquisition)
- Simulation: 1 frame
- SWE: multiple push-track frames

**Conservative estimate across all datasets: 500–1000 total frames**

---

## Data Rights & IP Confirmation

We confirm intent to release the contributed dataset under the Creative Commons BY 4.0 licence. All datasets are currently hosted on Zenodo under open-access terms (MIT license on code). No third-party IP encumbrances apply. The PICMUS benchmark datasets were originally distributed by the IEEE IUS community under open terms.

---

## Author List (contributors to be recognized)

1. Ole Marius Hoel Rindal — University of Oslo (lead, USTB developer)
2. Anders E. Vrålstad — University of Oslo (PhD candidate, blocked array correction)
3. Alfonso Rodriguez-Molares — NTNU (co-creator of USTB and UFF format)
4. Andreas Austeng — University of Oslo (Professor, signal processing)

---

## Links

- USTB GitHub: https://github.com/unioslo/USTB
- USTB website: https://www.ultrasoundtoolbox.com
- Zenodo dataset record: https://zenodo.org/records/20261898
- Conversion code: https://github.com/olemarius90/USTB/tree/cursor/openh-rf-proposal-c47b/sandbox/OpenHRF

---

## PDF Upload

Upload: `proposal.pdf` (built from `sandbox/OpenHRF/proposal.tex`)

Build with:
```bash
cd sandbox/OpenHRF && pdflatex proposal.tex
```
