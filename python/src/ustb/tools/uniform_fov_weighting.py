"""Uniform field-of-view weighting matching MATLAB tools.uniform_fov_weighting."""

import numpy as np


def uniform_fov_weighting(mid):
    """Calculate weighting to give a uniform field of view.

    Compensates for the varying number of transmit/receive combinations
    that contribute to each pixel (e.g. due to f-number-limited receive
    apertures or scanline transmit apodization) plus r^2 geometrical
    spreading. Mirrors MATLAB tools.uniform_fov_weighting(mid).

    Args:
        mid: a midprocess-like object with channel_data, scan,
            transmit_apodization, and receive_apodization attributes
            (e.g. ustb.midprocess.DAS).

    Returns:
        (apod, array_gain_compensation, geo_spreading_compensation), each
        shaped (N_rows, N_cols) matching the scan grid.
    """
    mid.transmit_apodization.sequence = mid.channel_data.sequence
    mid.transmit_apodization.focus = mid.scan
    tx_apodization = np.asarray(mid.transmit_apodization.data, dtype=np.float32)

    mid.receive_apodization.probe = mid.channel_data.probe
    mid.receive_apodization.focus = mid.scan
    rx_apodization = np.asarray(mid.receive_apodization.data, dtype=np.float32)

    # Separable: sum_{wave, rx} tx[p, wave] * rx[p, rx] = sum_wave(tx) * sum_rx(rx)
    apod_matrix = tx_apodization.sum(axis=1) * rx_apodization.sum(axis=1)

    # Pixel order follows pyuff_ustb's own flatten order (meshgrid(..., indexing="ij")),
    # which for LinearScan is (x, z) and for SectorScan is (depth, azimuth) -- see
    # ustb.plotting for the same convention.
    scan = mid.scan
    if hasattr(scan, "x_axis") and scan.x_axis is not None:
        n_rows, n_cols = scan.N_x_axis, scan.N_z_axis
        depth_axis = np.asarray(scan.z_axis).ravel()
        array_gain_compensation = apod_matrix.reshape(n_rows, n_cols)
        geo_spreading_compensation = np.tile(depth_axis[np.newaxis, :] ** 2, (n_rows, 1))
    elif hasattr(scan, "depth_axis") and scan.depth_axis is not None:
        n_rows, n_cols = scan.N_depth_axis, scan.N_azimuth_axis
        depth_axis = np.asarray(scan.depth_axis).ravel()
        array_gain_compensation = apod_matrix.reshape(n_rows, n_cols)
        geo_spreading_compensation = np.tile(depth_axis[:, np.newaxis] ** 2, (1, n_cols))
    else:
        raise ValueError(f"Don't know how to reshape scan of type {type(scan)}")

    apod = geo_spreading_compensation / array_gain_compensation
    return apod, array_gain_compensation, geo_spreading_compensation
