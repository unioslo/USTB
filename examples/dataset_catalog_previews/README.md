# Dataset catalog previews (website thumbnails)

`dataset_preview_beamform.m` contains one **`switch` branch per `.uff` file** listed in `examples/dataset_smoke_tests/uff_dataset_registry.m`. Each branch mirrors the beamforming used in a specific **example or publication script** (see comments in that file).

- **`export_png_like_b_data_plot.m`** — renders with **`uff.beamformed_data.plot`** (same `pcolor` + `axis equal` geometry as the toolbox, including sector scans), then saves the axes to PNG (`exportgraphics` or `getframe`). This avoids stretching sector images into a misleading rectangle.

Regenerate website images from the repo root in MATLAB:

```matlab
addpath('examples/dataset_smoke_tests');
export_dataset_previews_to_website();
```

Then:

```bash
python3 website/scripts/build_datasets_page.py
```

When adding a new dataset to the registry, add a **`case 'filename.uff'`** in `dataset_preview_beamform.m` and point to the canonical example in the comment.
