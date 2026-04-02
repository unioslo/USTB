# Publishing USTB Examples

The USTB website includes published MATLAB examples with executed code, output, and figures. These are pre-built locally and uploaded as a GitHub Release artifact, then downloaded by the deploy workflow.

## Quick Start

```bash
# From the USTB repository root:
./publish_examples.sh              # Generate examples
./publish_examples.sh --upload     # Generate and upload to GitHub Release
```

## Prerequisites

- **MATLAB R2024b** or later with Signal Processing Toolbox
- **Field II v3.30** (optional, for simulation examples) — install to `/opt/field_ii`
- **Python 3** (for `generate_examples_index.py`)
- **Recompiled MEX file** — the MEX beamformer must be compiled against your system's TBB:

```matlab
cd('+mex');
mex('-R2018a', '-D_UNIX_', '-I/usr/include/tbb', ...
    'LDFLAGS="$LDFLAGS -Wl,-rpath,/usr/lib/x86_64-linux-gnu"', ...
    '-L/usr/lib/x86_64-linux-gnu', '-ltbb', 'source/das_c.cpp');
```

## How It Works

1. `publish_all_examples.m` runs MATLAB `publish()` on each example
2. Examples with errors in the HTML output are automatically removed
3. `generate_examples_index.py` creates a browsable gallery page
4. Everything is packaged into `examples-html.tar.gz`
5. The tarball is uploaded to the `examples-v1` GitHub Release
6. The deploy workflow (`deploy-website.yml`) downloads and extracts it into `website/examples/`

## Manual Steps

```bash
# 1. Install Field II (optional)
mkdir -p /opt/field_ii
curl -L -A "Mozilla/5.0" -o /tmp/field_ii.tar.gz \
  "https://www.field-ii.dk/program_code/matlab_2021/Field_II_ver_3_30_linux.tar.gz"
tar -xzf /tmp/field_ii.tar.gz -C /opt/field_ii

# 2. Recompile MEX (if needed)
matlab -batch "cd('+mex'); mex('-R2018a','-D_UNIX_','-I/usr/include/tbb','LDFLAGS=\"\$LDFLAGS -Wl,-rpath,/usr/lib/x86_64-linux-gnu\"','-L/usr/lib/x86_64-linux-gnu','-ltbb','source/das_c.cpp')"

# 3. Publish examples
./publish_examples.sh

# 4. Upload to GitHub Release
./publish_examples.sh --upload
# Or for unioslo:
./publish_examples.sh --upload unioslo/USTB
```

## Skipped Examples

These examples are skipped by `publish_all_examples.m` (not attempted):

### External toolbox dependencies

| Example | Reason |
|---|---|
| `examples/FLUST/*` | Needs MUST toolbox |
| `examples/kWave/*` | Needs k-Wave toolbox |
| `examples/REFoCUS/*` | Causes segfault in headless MATLAB |

### Hardware/data dependencies

| Example | Reason |
|---|---|
| `examples/verasonics/*` | Needs Verasonics hardware/data |
| `examples/alpinion/*` | Needs Alpinion hardware/data |
| `examples/acoustical_radiation_force_imaging/*` | Needs hardware data |

### Interactive or slow

| Example | Reason |
|---|---|
| `MATLAB_intro.m` | Uses `ginput()`, hangs in headless |
| `STAI_L11_speckle.m` | Field II simulation, very slow |
| `STAI_L11_resolution_phantom.m` | Field II simulation, very slow |
| `CPWC_L11_probe_sim.m` | Field II simulation, very slow |
| `FI_elevation_profile.m` | Field II simulation, very slow |
| `FI_L11_parfor_compared_to_fresnel.m` | Needs Parallel Computing Toolbox |
| `STAI_L11_speckle_parfor.m` | Needs Parallel Computing Toolbox |
| `FI_P4_cardiac_coherence.m` | Needs Parallel Computing Toolbox |
| `STAI_2D_array_cardiac.m` | 3D simulation, very long runtime |
| `CPWC_2D_array_cardiac.m` | 3D simulation, very long runtime |

### Course exercises

| Example | Reason |
|---|---|
| `examples/UiO_course_IN4015_Ultrasound_Imaging/*` | Student exercises, some with unimplemented code |

### Runtime errors (published but removed)

These examples are attempted but produce errors during execution and are automatically removed from the final output:

| Example | Error |
|---|---|
| `FI_UFF_delay_multiply_and_sum_contrast.m` | `tools.measure_contrast_ratio` error |
| `FI_UFF_generalized_coherence_factor.m` | SLSC `makelagmat` error |
| `FI_UFF_multi_frame_processing.m` | HTTP 303 download error |
| `FI_UFF_short_lag_spatial_coherence.m` | SLSC `makelagmat` error |
| `FI_UFF_simplified_delay_multiply_and_sum_complexity.m` | `printSnap` error |
| `FI_UFF_synthetic_TX_SLSC.m` | `printSnap` error |
| `CPWC_linear_array_multiframe.m` | Fresnel phantom set error |
| `FI_linear_array_receive_processes.m` | `printSnap` error |
| `FI_phased_array_multiframe.m` | Fresnel phantom set error |
| `CPWC_UFF_Verasonics.m` | `printSnap` error |
| `CPWC_UFF_read.m` | HTTP 303 download error |
| `CPWC_UFF_write.m` | `questdlg` headless error |
| `FI_UFF_phased_array.m` | Runtime error |
| `FI_UFF_Verasonics_MLA.m` | Runtime error |
| `STAI_theoretical_PSF.m` | Field II cleanup error |
| `STAI_L11_probe_sim.m` | MEX/runtime error |
| `STAI_PSF.m` | Field II error |
| Various fresnel examples | Fresnel simulator errors in headless |

## Currently Published (24 examples)

| Category | Examples |
|---|---|
| Advanced Beamforming | `FI_UFF_delay_multiply_and_sum_resolution` |
| Field II | `STAI_L11_probe_sim`, `STAI_PSF` |
| Fresnel / Curvilinear | `DW_curvilinear_array`, `FI_curvilinear_array` |
| Fresnel / Linear | `CPWC_linear_array`, `CPWC_linear_array_tilt`, `DW_linear_array`, `FI_linear_array`, `RTB_linear_array_close_up` |
| Fresnel / Phased | `DW_phased_array`, `FI_phased_array`, `FI_phased_array_RTB`, `FI_phased_array_RTB_close_up` |
| PICMUS | All 6 (experiment/simulation × resolution/contrast/invivo) |
| UFF | `CPWC_UFF_Alpinion`, `FI_UFF_Alpinion`, `FI_UFF_Verasonics_RTB`, `STAI_UFF_beamform_with_demodulation` |
