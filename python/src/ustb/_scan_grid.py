"""Image-grid indices of scan pixels (depth x lateral), for linear and sector scans.

MATLAB orders scan pixels with depth varying fastest; pyuff_ustb orders them
with the lateral axis (x or azimuth) varying fastest. Processes that work on
the 2-D image (scanline apodization, Capon, DMAS, SLSC) use these indices so
they handle both orders.
"""

import numpy as np


def scan_grid(scan):
    """Return ``(depth_index, lateral_index, N_depth, N_lateral)`` for each pixel.

    Supports scans with ``x_axis``/``z_axis`` (linear) or
    ``azimuth_axis``/``depth_axis`` (sector). The pixel order is detected by
    comparing ``scan.x``/``scan.z`` with the grid built from the axes.
    """
    px = np.asarray(scan.x, dtype=np.float64).ravel()
    pz = np.asarray(scan.z, dtype=np.float64).ravel()
    azimuth_axis = getattr(scan, "azimuth_axis", None)
    x_axis = getattr(scan, "x_axis", None)

    if azimuth_axis is not None:
        azimuth = np.asarray(azimuth_axis, dtype=np.float64).ravel()
        depth = np.asarray(scan.depth_axis, dtype=np.float64).ravel()
        depth_index, lateral_index = np.meshgrid(np.arange(depth.size), np.arange(azimuth.size),
                                                 indexing="ij")
        origin = getattr(scan, "origin", None)
        multiple_origins = isinstance(origin, (list, tuple))
        ox, oz = (origin.x, origin.z) if origin is not None and not multiple_origins else (0.0, 0.0)
        x_grid = depth[depth_index] * np.sin(azimuth[lateral_index]) + ox
        z_grid = depth[depth_index] * np.cos(azimuth[lateral_index]) + oz
        if multiple_origins:
            # One origin per scanline: pyuff_ustb cannot compute x for these
            # scans itself, so assume its default (lateral fastest) ordering
            return (depth_index.ravel(order="C"), lateral_index.ravel(order="C"),
                    depth.size, azimuth.size)
        N_depth, N_lateral = depth.size, azimuth.size
    elif x_axis is not None:
        x_values = np.asarray(x_axis, dtype=np.float64).ravel()
        z_values = np.asarray(scan.z_axis, dtype=np.float64).ravel()
        depth_index, lateral_index = np.meshgrid(np.arange(z_values.size), np.arange(x_values.size),
                                                 indexing="ij")
        x_grid, z_grid = x_values[lateral_index], z_values[depth_index]
        N_depth, N_lateral = z_values.size, x_values.size
    else:
        raise ValueError("The scan needs x_axis/z_axis or azimuth_axis/depth_axis")

    for order in ("C", "F"):
        if (px.size == x_grid.size
                and np.allclose(x_grid.ravel(order=order), px, rtol=0, atol=1e-9)
                and np.allclose(z_grid.ravel(order=order), pz, rtol=0, atol=1e-9)):
            return (depth_index.ravel(order=order), lateral_index.ravel(order=order),
                    N_depth, N_lateral)
    raise ValueError("Could not match the scan pixels to its axes")


def to_image(data, scan):
    """Reshape ``[pixel, ...]`` data to ``[depth, lateral, ...]``."""
    depth_index, lateral_index, N_depth, N_lateral = scan_grid(scan)
    data = np.asarray(data)
    image = np.zeros((N_depth, N_lateral) + data.shape[1:], dtype=data.dtype)
    image[depth_index, lateral_index] = data
    return image


def from_image(image, scan):
    """Inverse of :func:`to_image`: ``[depth, lateral, ...]`` back to ``[pixel, ...]``."""
    depth_index, lateral_index, _, _ = scan_grid(scan)
    return np.asarray(image)[depth_index, lateral_index]
