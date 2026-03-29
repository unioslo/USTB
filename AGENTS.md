# AGENTS.md

## Cursor Cloud specific instructions

### Overview
USTB (UltraSound ToolBox) is an open-source **MATLAB** toolbox for beamforming, processing, and visualization of ultrasonic signals. The primary codebase is MATLAB (`.m` files), with C++/CUDA MEX extensions and Python-based Sphinx documentation.

### Key services

| Service | How to run | Notes |
|---|---|---|
| MATLAB tests (CI) | `matlab -batch "run('run_tests_matlab.m')"` | Requires MATLAB with Signal_Processing_Toolbox. See `.github/workflows/matlab-tests.yml`. |
| Sphinx docs build | `sphinx-build -b html docs docs/_build/html` | Python 3 + `pip install -r docs/requirements.txt` |
| Docs preview | `python3 -m http.server 8080` from `docs/_build/html/` | Local preview server |

### MATLAB vs Octave compatibility
- The toolbox is designed for MATLAB. GNU Octave (installed in this environment) can run basic functions like `ustb_path()` and verify package structure, but **cannot** instantiate most USTB classes due to MATLAB-specific features (e.g. class inheritance from `int32` for enums, namespace/class shadowing between `uff.m` and `+uff/` package).
- Full test execution (`unit_test().all()` or the `tests/` test suite) requires a licensed MATLAB installation with the Signal Processing Toolbox.
- Octave is useful for: verifying toolbox structure, running simple scripts, and generating basic plots.

### Documentation build
- Python deps: `pip install -r docs/requirements.txt` (sphinx, sphinxcontrib-matlabdomain, sphinx-rtd-theme).
- Build: `sphinx-build -b html docs docs/_build/html` (runs from workspace root).
- The build produces warnings from some MATLAB docstrings but completes successfully.

### MEX compilation
- The C++ MEX beamformer (`+mex/source/das_c.cpp`) requires `libtbb-dev` (TBB threading library).
- Build from MATLAB: `mex.build_mex()`.
- On Mac: install TBB via `brew install tbb`.

### Lint
- No dedicated MATLAB linter is configured in the repo. MATLAB's built-in `checkcode` can be used.
- Python linting: not configured (only 4 Python files for docs/hardware scripts).

### Testing
- **Smoke tests** (in `tests/`): MATLAB unittest framework tests (`smoke_test.m`, `uff_*_test.m`, `integration_*_test.m`). Run via `matlab -batch "results = runtests('tests'); assertSuccess(results);"`.
- **Legacy unit tests** (in `@unit_test/`): Custom test harness. Run via `matlab -batch "ut = unit_test(); ut.all();"`. Requires downloading test data from `ustb.no/datasets`.
