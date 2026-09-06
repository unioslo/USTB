"""Plotting utilities for USTB beamformed data."""

import numpy as np
import matplotlib.pyplot as plt


def plot_beamformed_data(b_data, title="", dynamic_range=60):
    """Plot beamformed data as a B-mode image.

    For sector scans, displays scan-converted (fan-shaped) images using the
    physical (x, z) pixel coordinates, matching MATLAB's pcolor-based display.
    For linear scans, displays a rectangular image.
    """
    scan = b_data.scan
    data = np.array(b_data.data)

    if data.ndim == 4:
        data = data[:, 0, 0, 0]
    elif data.ndim == 3:
        data = data[:, 0, 0]
    elif data.ndim == 2:
        data = data[:, 0]

    envelope = np.abs(data)
    envelope[envelope < np.finfo(float).eps] = np.finfo(float).eps
    img_db = 20.0 * np.log10(envelope / envelope.max())
    img_db = np.clip(img_db, -dynamic_range, 0)

    is_sector = hasattr(scan, "azimuth_axis") and scan.azimuth_axis is not None
    is_linear = hasattr(scan, "x_axis") and scan.x_axis is not None

    if is_sector and not is_linear:
        return _plot_sector_scan(scan, img_db, title, dynamic_range)
    elif is_linear:
        return _plot_linear_scan(scan, img_db, title, dynamic_range)
    else:
        fig, ax = plt.subplots(1, 1, figsize=(8, 6))
        ax.plot(img_db)
        ax.set_ylabel("Amplitude [dB]")
        ax.set_title(title if title else "B-mode Image")
        return fig, ax


def _plot_sector_scan(scan, img_db, title, dynamic_range):
    """Scan-converted sector scan display using physical (x, z) coordinates.

    Matches MATLAB's pcolor(x_matrix, z_matrix, image) display where the
    image is shown in its physical fan-shaped geometry.
    """
    N_depth = len(scan.depth_axis)
    N_az = len(scan.azimuth_axis)

    # Reshape pixel coordinates and image to 2D grid
    # pyuff_ustb meshgrid(depth, az, indexing='ij') with C-order: (N_depth, N_az)
    x_matrix = scan.x.reshape(N_depth, N_az)
    z_matrix = scan.z.reshape(N_depth, N_az)
    img_2d = img_db.reshape(N_depth, N_az)

    fig, ax = plt.subplots(1, 1, figsize=(8, 8))

    # pcolormesh is Python's equivalent of MATLAB's pcolor
    pcm = ax.pcolormesh(
        x_matrix * 1e3,
        z_matrix * 1e3,
        img_2d,
        cmap="gray",
        vmin=-dynamic_range,
        vmax=0,
        shading="gouraud",
    )

    ax.set_aspect("equal")
    ax.invert_yaxis()
    ax.set_xlabel("x [mm]")
    ax.set_ylabel("z [mm]")
    ax.set_title(title if title else "B-mode Image")
    ax.set_facecolor("black")
    plt.colorbar(pcm, ax=ax, label="dB")
    plt.tight_layout()
    return fig, ax


def _plot_linear_scan(scan, img_db, title, dynamic_range):
    """Rectangular linear scan display using pcolormesh for scan conversion."""
    x_axis = np.asarray(scan.x_axis).ravel()
    z_axis = np.asarray(scan.z_axis).ravel()
    N_x = len(x_axis)
    N_z = len(z_axis)

    # pyuff_ustb LinearScan uses meshgrid(x_axis, z_axis, indexing='ij')
    # with C-order flatten, giving shape (N_x, N_z)
    x_matrix = scan.x.reshape(N_x, N_z)
    z_matrix = scan.z.reshape(N_x, N_z)
    img_2d = img_db.reshape(N_x, N_z)

    fig, ax = plt.subplots(1, 1, figsize=(8, 8))
    pcm = ax.pcolormesh(
        x_matrix * 1e3,
        z_matrix * 1e3,
        img_2d,
        cmap="gray",
        vmin=-dynamic_range,
        vmax=0,
        shading="gouraud",
    )
    ax.set_aspect("equal")
    ax.invert_yaxis()
    ax.set_xlabel("x [mm]")
    ax.set_ylabel("z [mm]")
    ax.set_title(title if title else "B-mode Image")
    plt.colorbar(pcm, ax=ax, label="dB")
    plt.tight_layout()
    return fig, ax
