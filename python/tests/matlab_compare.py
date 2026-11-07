"""Helpers for comparing Python USTB output against MATLAB reference data.

MATLAB and pyuff_ustb order the pixels of a scan differently (Fortran vs C
order), so outputs cannot be compared index by index. Instead, pixels are
paired by their coordinates and the comparison is done pixel by pixel.
"""

import numpy as np
from scipy.spatial import cKDTree


def match_pixels(ml_coords, py_coords, atol=1e-6):
    """Return ``perm`` such that MATLAB pixel ``perm[k]`` is Python pixel ``k``.

    ``ml_coords`` and ``py_coords`` are tuples of coordinate arrays, e.g.
    ``(x, z)``. Raises ``AssertionError`` if the two scans do not contain the
    same pixel positions (within ``atol`` metres).

    Pixels at the same position (e.g. the depth-0 row of a sector scan, which
    all sit at the origin) cannot be told apart by their coordinates; such
    groups are paired in index order.
    """
    ml_coords = [np.asarray(c, dtype=np.float64).ravel() for c in ml_coords]
    py_coords = [np.asarray(c, dtype=np.float64).ravel() for c in py_coords]
    assert ml_coords[0].size == py_coords[0].size, (
        f"Pixel count mismatch: MATLAB {ml_coords[0].size}, Python {py_coords[0].size}"
    )

    ml_points = np.column_stack(ml_coords)
    tree = cKDTree(ml_points)
    # Nearest MATLAB pixel for every Python pixel
    _, perm = tree.query(np.column_stack(py_coords))

    # Pair up groups of pixels that share the same position
    shared = np.bincount(perm, minlength=len(ml_points))[perm] > 1
    for ml_pixel in np.unique(perm[shared]):
        py_group = np.flatnonzero(perm == ml_pixel)
        ml_group = np.sort(tree.query_ball_point(ml_points[ml_pixel], r=atol))
        assert len(ml_group) == len(py_group), (
            f"{len(py_group)} Python pixels but {len(ml_group)} MATLAB pixels "
            f"at position {ml_points[ml_pixel]}"
        )
        perm[py_group] = ml_group
    assert len(np.unique(perm)) == len(perm), "Pixel matching is not one-to-one"

    for axis, (ml_c, py_c) in enumerate(zip(ml_coords, py_coords, strict=True)):
        np.testing.assert_allclose(
            ml_c[perm],
            py_c,
            rtol=0,
            atol=atol,
            err_msg=f"Scan coordinate {axis} differs after pixel matching",
        )
    return perm


def pixelwise_metrics(ml_data, py_data, mask=None):
    """Envelope correlation and relative complex error, per frame.

    ``ml_data`` and ``py_data`` are ``[pixel, ..., frame]`` arrays with the
    pixels already aligned. ``mask`` optionally selects the pixels to compare.
    Returns two lists (one value per frame): envelope correlation, and
    ``||ml - py|| / ||ml||``.
    """
    ml = np.asarray(ml_data).reshape(ml_data.shape[0], -1)
    py = np.asarray(py_data).reshape(py_data.shape[0], -1)
    assert ml.shape == py.shape, f"Shape mismatch: MATLAB {ml.shape}, Python {py.shape}"
    if mask is not None:
        ml, py = ml[mask], py[mask]

    corrs, rel_errs = [], []
    for f in range(ml.shape[1]):
        a, b = ml[:, f], py[:, f]
        corrs.append(np.corrcoef(np.abs(a), np.abs(b))[0, 1])
        rel_errs.append(np.linalg.norm(a - b) / (np.linalg.norm(a) + 1e-30))
    return corrs, rel_errs


def assert_pixelwise_match(ml_data, py_data, name, min_corr, max_rel_err, mask=None):
    """Assert pixel-by-pixel agreement of beamformed data with MATLAB."""
    corrs, rel_errs = pixelwise_metrics(ml_data, py_data, mask)
    worst_corr, worst_err = min(corrs), max(rel_errs)
    print(
        f"{name}: pixelwise envelope correlation {worst_corr:.6f}, "
        f"relative complex error {worst_err:.2e}"
    )
    assert worst_corr > min_corr, (
        f"{name}: pixelwise envelope correlation {worst_corr:.6f} <= {min_corr}"
    )
    assert worst_err < max_rel_err, (
        f"{name}: relative complex error {worst_err:.2e} >= {max_rel_err:.0e}"
    )
