# USTB for Python

Python reimplementation of the [UltraSound ToolBox (USTB)](https://www.ustb.no) — an open-source toolbox for beamforming, processing, and visualization of ultrasonic signals.

## Installation

```bash
pip install ustb
```

For development:

```bash
pip install -e ".[dev]"
```

## Quick Start

```python
from pyuff_ustb.objects.uff import Uff
from ustb.midprocess import DAS
from ustb.enums import Dimension, Window

# Read channel data from UFF file
channel_data = Uff("data.uff").read("channel_data")

# Set up beamformer (same API as MATLAB)
mid = DAS()
mid.channel_data = channel_data
mid.scan = scan
mid.dimension = Dimension.both
mid.transmit_apodization.window = Window.scanline
mid.receive_apodization.window = Window.none

# Beamform
b_data = mid.go()

# Plot scan-converted B-mode image
b_data.plot(title="My Image")
```

## Features

- **`midprocess.DAS`** — Generalized Delay-And-Sum beamformer, compiled with numba and run in parallel over pixels
- **`preprocess`** — `FastDemodulation` and `Demodulation` (RF to IQ), `SVDFilter` (spatiotemporal clutter filter)
- **`postprocess`**:
  - compounding: `CoherentCompounding`, `IncoherentCompounding`
  - adaptive beamforming: `CoherenceFactor`, `GeneralizedCoherenceFactor`, `PhaseCoherenceFactor`, `CaponMinimumVariance`, `DelayMultiplyAndSum`, `ShortLagSpatialCoherence`
  - flow: `SVDFilter`, `AutocorrelationDisplacementEstimation`, `ModifiedAutocorrelationDisplacementEstimation`
  - image processing: `Median`
- **`Apodization`** — every window; receive, transmit (plane and diverging waves) and scanline (MLA) apodization
- **`Pipeline`** — chain preprocess/midprocess/postprocess steps in one call
- **`tools`** — `download`, `zenodo_dataset_files_base`, `scan_convert`, `power_spectrum`, `estimate_frequency`, `uniform_fov_weighting`
- **`BeamformedData.get_image()` / `.save_as_gif()`** — image extraction and animated B-mode export
- **Scan-converted display** — sector and linear scan visualization, plus raw channel-data preview via `plotting.plot_channel_data`
- **UFF I/O** — reads/writes USTB UFF files via [pyuff-ustb](https://github.com/magnusdk/pyuff_ustb)

Documentation: [USTB for Python](https://unioslo.github.io/USTB/api/python/index.html), including a [MATLAB to Python](https://unioslo.github.io/USTB/api/python/matlab_to_python.html) guide (class mapping and known differences).

## Examples

See the `examples/` directory:

- `minimal_example.py` — cardiac phased array imaging
- `maximal_example.py` — full pipeline (demod → DAS → CF → median)
- `cpwc_linear.py` — plane wave compound imaging
- `picmus_*.py` — PICMUS challenge datasets

## Relationship to MATLAB USTB

This package mirrors the MATLAB USTB API as closely as possible. The main classes (`DAS`, `Dimension`, `Window`, `Apodization`) use the same names, properties, and method signatures. The integration tests compare against MATLAB pixel by pixel: the beamformed output of every example (CPWC linear, phased array, and the four PICMUS datasets) matches MATLAB to about 1e-4 relative error, and the receive, transmit and scanline apodization match `uff.apodization` to float precision.
