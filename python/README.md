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

- **`midprocess.DAS`** — Generalized Delay-And-Sum beamformer
- **`preprocess.FastDemodulation`** — RF to IQ conversion
- **`postprocess.CoherenceFactor`** — Mallart-Fink coherence factor
- **`postprocess.Median`** — 2D median filter for speckle reduction
- **Scan-converted display** — sector and linear scan visualization
- **UFF I/O** — reads/writes USTB UFF files via [pyuff-ustb](https://github.com/magnusdk/pyuff_ustb)

## Examples

See the `examples/` directory:

- `minimal_example.py` — cardiac phased array imaging
- `maximal_example.py` — full pipeline (demod → DAS → CF → median)
- `cpwc_linear.py` — plane wave compound imaging
- `picmus_*.py` — PICMUS challenge datasets

## Relationship to MATLAB USTB

This package mirrors the MATLAB USTB API as closely as possible. The main classes (`DAS`, `Dimension`, `Window`, `Apodization`) use the same names, properties, and method signatures. Beamformed output matches MATLAB with >0.999 correlation across all tested examples.
