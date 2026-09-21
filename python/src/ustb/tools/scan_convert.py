"""Polar to Cartesian image resampling matching MATLAB tools.scan_convert."""

import numpy as np
from scipy.interpolate import RegularGridInterpolator


def scan_convert(input_image, thetas, ranges, size_x=512, size_z=512, method="linear"):
    """Convert an image from polar (range, beam angle) to Cartesian coordinates.

    Mirrors MATLAB tools.scan_convert(inputImage, thetas, ranges, sizeX, sizeZ,
    interpolationMethod). ``thetas`` and ``ranges`` must be strictly increasing.

    Args:
        input_image: 2-D array of shape (len(ranges), len(thetas)).
        thetas: beam angles [rad], increasing.
        ranges: sample ranges [m], increasing.
        size_x, size_z: pixel size of the output image.
        method: interpolation method passed to RegularGridInterpolator
            ("linear" or "nearest").

    Returns:
        (scan_converted_image, xs, zs) where scan_converted_image has shape
        (size_z, size_x) and xs, zs are the output Cartesian axes [m].
        Pixels outside the polar footprint are filled with -inf, matching
        MATLAB's fill value.
    """
    thetas = np.asarray(thetas, dtype=float).ravel()
    ranges = np.asarray(ranges, dtype=float).ravel()
    input_image = np.asarray(input_image, dtype=float)

    theta_grid, range_grid = np.meshgrid(thetas, ranges)
    z = range_grid * np.cos(theta_grid)
    x = range_grid * np.sin(theta_grid)

    xs = np.linspace(x.min(), x.max(), size_x)
    zs = np.linspace(z.min(), z.max(), size_z)
    xs_grid, zs_grid = np.meshgrid(xs, zs)

    theta_out = np.arctan2(xs_grid, zs_grid)
    range_out = np.sqrt(zs_grid**2 + xs_grid**2)

    interpolator = RegularGridInterpolator(
        (ranges, thetas), input_image, method=method,
        bounds_error=False, fill_value=-np.inf,
    )
    query = np.column_stack([range_out.ravel(), theta_out.ravel()])
    scan_converted_image = interpolator(query).reshape(zs_grid.shape)

    return scan_converted_image, xs, zs
