# AGENTS.md

## Cursor Cloud specific instructions

### Overview

USTB (UltraSound ToolBox) is an open-source toolbox for beamforming, processing, and visualization of ultrasonic signals. The codebase has two implementations:

- **MATLAB** (primary, in repo root): `.m` files with C++/CUDA MEX extensions
- **Python** (in `python/`): pip-installable reimplementation using `pyuff-ustb` for I/O

### Repository structure

| Path | Contents |
|---|---|
| `+uff/`, `+midprocess/`, `+postprocess/`, `+preprocess/`, `+tools/` | MATLAB packages |
| `+mex/` | C++/CUDA MEX beamformer source |
| `@unit_test/`, `tests/` | MATLAB tests |
| `examples/` | MATLAB examples |
| `python/src/ustb/` | Python USTB package (installable via pip) |
| `python/examples/` | Python examples |
| `python/tests/` | Python unit + integration tests |
| `website/` | Static HTML website (deployed to GitHub Pages) |
| `docs/` | Sphinx API documentation source |
| `.github/workflows/` | CI: MATLAB tests, toolbox build, website deploy |

### Key services

| Service | How to run | Notes |
|---|---|---|
| MATLAB tests | `matlab -batch "results = runtests('tests'); assertSuccess(results);"` | Requires MATLAB + Signal_Processing_Toolbox |
| MATLAB legacy tests | `matlab -batch "ut = unit_test(); ut.all();"` | Downloads test data from ustb.no |
| Python tests | `cd python && pip install -e '.[dev]' && pytest tests/` | Unit tests run without MATLAB or datasets |
| Python integration tests | `cd python && pytest tests/test_integration_matlab.py tests/test_examples_vs_matlab.py` | Requires MATLAB reference HDF5 files and datasets |
| Sphinx docs build | `sphinx-build -b html docs docs/_build/html` | Python 3 + `pip install -r docs/requirements.txt` |
| Website preview | `cd website && python3 -m http.server 8090` | Static site, no build step |
| Toolbox build | `matlab -batch "build_toolbox"` | Produces `USTB_v<version>.mltbx` |

---

### MATLAB implementation

#### Class hierarchy

- **`uff` < `handle`** — base class for all UFF data objects (metadata, HDF5 I/O)
  - `uff.channel_data` — raw RF/IQ data `[time × channel × wave × frame]`
  - `uff.beamformed_data` — beamformed image data `[pixel × channel × wave × frame]`
  - `uff.scan` — pixel positions; subclasses: `uff.linear_scan`, `uff.sector_scan`
  - `uff.probe` — transducer element geometry
  - `uff.wave` — transmit event (wavefront, source, delay)
  - `uff.point` — point in space (spherical coordinates)
  - `uff.pulse` — excitation pulse
  - `uff.apodization` — pixel-dependent window weights
- **Enums** (all `< int32`): `dimension`, `code`, `uff.window`, `uff.wavefront`, `spherical_transmit_delay_model`
- **Processing**: `process` → `preprocess`, `midprocess`, `postprocess` → concrete classes like `midprocess.das`

#### DAS beamformer (`+midprocess/das.m`)

The core beamformer implements Eq. (2) of "The Generalized Beamformer":

1. Compute receive delay: `sqrt((probe.x - scan.x)^2 + ...) / c`
2. Compute transmit delay per wave (spherical/plane/photoacoustic models)
3. Compute Rx and Tx apodization from `uff.apodization`
4. For each wave and channel: interpolate channel data at `rx_delay + tx_delay`, apply apodization and IQ phase, accumulate per `dimension`
5. Apply reference distance phase correction for IQ data

Key properties: `dimension`, `code`, `spherical_transmit_delay_model`, `pw_margin`, `lens_delay`

#### Running MATLAB

- MATLAB R2024b is installed at `/opt/matlab/bin/matlab`
- License is activated via MathWorks online licensing (UiO headcount license)
- If activation fails, ensure `/opt/matlab/licenses/` is writable: `sudo chmod 777 /opt/matlab/licenses`
- Run with: `matlab -batch "addpath('.'); <commands>"`

#### MATLAB vs Octave

- GNU Octave cannot instantiate most USTB classes (enum inheritance from `int32`, `uff.m` class shadowing `+uff/` package)
- Octave is only useful for verifying toolbox structure and running simple scripts

---

### Python implementation (`python/`)

#### Installation

```bash
cd python
pip install -e ".[dev]"   # editable install with test dependencies
```

Dependencies: `numpy`, `scipy`, `matplotlib`, `pyuff-ustb>=3.0.0`

#### Package structure (`python/src/ustb/`)

| Module | MATLAB equivalent | Description |
|---|---|---|
| `ustb.midprocess.DAS` | `midprocess.das` | Generalized DAS beamformer |
| `ustb.preprocess.FastDemodulation` | `preprocess.fast_demodulation` | RF → IQ conversion |
| `ustb.postprocess.CoherenceFactor` | `postprocess.coherence_factor` | Mallart-Fink CF |
| `ustb.postprocess.Median` | `postprocess.median` | 2D median filter |
| `ustb.enums.Dimension` | `dimension` | none/receive/transmit/both |
| `ustb.enums.Wavefront` | `uff.wavefront` | plane/spherical/photoacoustic |
| `ustb.enums.Window` | `uff.window` | none/boxcar/hanning/hamming/tukey/scanline |
| `ustb.Apodization` | `uff.apodization` | f-number windowed weights |
| `ustb.BeamformedData` | `uff.beamformed_data` | Output container with `plot()` |
| `ustb.plotting` | `beamformed_data.plot()` | Scan-converted B-mode display |

UFF file I/O (ChannelData, Probe, Wave, Scan, etc.) comes from `pyuff-ustb` (PyPI), not reimplemented.

#### API design

The Python API mirrors MATLAB as closely as possible:

```python
# MATLAB:                          # Python:
# mid = midprocess.das();           mid = DAS()
# mid.channel_data = ch;            mid.channel_data = ch
# mid.dimension = dimension.both;   mid.dimension = Dimension.both
# mid.scan = scan;                  mid.scan = scan
# b_data = mid.go();                b_data = mid.go()
# b_data.plot([], 'Title');         b_data.plot(title="Title")
```

#### Known differences from MATLAB

- **Pixel ordering**: MATLAB `sector_scan` uses Fortran-order (depth varies fastest), `pyuff_ustb` uses C-order (azimuth varies fastest). The beamformer handles both correctly; the difference only affects 2D reshape for display.
- **Wavefront enum**: `pyuff_ustb.Wavefront` and `ustb.enums.Wavefront` are different types. The DAS code compares by `.value` to handle both.
- **Apodization**: The Python scanline apodization is a simplified implementation. For production use, verify against MATLAB output.

#### Running Python tests

```bash
cd python

# Unit tests only (fast, no MATLAB or data needed)
pytest tests/test_enums.py tests/test_apodization.py tests/test_beamformed_data.py tests/test_das.py

# Integration tests (need MATLAB reference files in tests/*.h5 and datasets in data/)
pytest tests/test_integration_matlab.py tests/test_examples_vs_matlab.py
```

To regenerate MATLAB reference data:
```bash
matlab -batch "addpath('.'); run('python/tests/generate_all_references.m');"
```

#### Running Python examples

```bash
cd python
python -m examples.cpwc_linear
python -m examples.picmus_experiment_resolution
python minimal_example.py
```

All examples download datasets automatically from `ustb.no/datasets/`.

---

### Toolbox build (`build_toolbox.m`)

- Reads `TOOLBOX_VERSION` from environment (defaults to `0.0.0-dev`)
- Strips pre-release suffixes (e.g. `-rc1`) for MATLAB's `ToolboxVersion` format
- Produces `USTB_v<version>.mltbx`
- CI workflow (`.github/workflows/build-toolbox.yml`) triggers on `v*` tags

### Website (`website/`)

- Static HTML/CSS, deployed to GitHub Pages via `.github/workflows/deploy-website.yml`
- Sphinx API docs are built into `website/api/` at deploy time (not committed)
- To preview locally: `sphinx-build -b html docs website/api && cd website && python3 -m http.server 8090`

### MEX compilation

- C++ MEX source: `+mex/source/das_c.cpp`, requires `libtbb-dev`
- Build from MATLAB: `mex.build_mex()`
- On Mac: `brew install tbb`
