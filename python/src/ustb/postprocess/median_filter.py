"""Median filter for ultrasound image denoising.

Applies 2D median filtering to reduce speckle and noise.
"""

import numpy as np
from scipy.ndimage import median_filter
from ustb.beamformed_data import BeamformedData


class Median:
    """2D median filter postprocess matching MATLAB postprocess.median."""

    def __init__(self):
        self.input = None
        self.m = 20
        self.n = 20

    def go(self):
        data = np.array(self.input.data)
        scan = self.input.scan

        if hasattr(scan, "x_axis") and scan.x_axis is not None:
            x_axis = np.asarray(scan.x_axis).ravel()
            z_axis = np.asarray(scan.z_axis).ravel()
            N_rows = len(z_axis)
            N_cols = len(x_axis)
        elif hasattr(scan, "depth_axis") and scan.depth_axis is not None:
            N_rows = len(scan.depth_axis)
            N_cols = len(scan.azimuth_axis)
        else:
            raise ValueError("Scan type not supported for median filter")

        N_frames = data.shape[3] if data.ndim > 3 else 1
        img = data.reshape(N_rows, N_cols, 1, N_frames) if hasattr(scan, "x_axis") and scan.x_axis is not None else data.reshape(N_rows, N_cols, 1, N_frames)

        output_img = np.zeros_like(img)
        for f in range(N_frames):
            output_img[:, :, 0, f] = median_filter(
                np.abs(img[:, :, 0, f]), size=(self.m, self.n)
            )

        output_data = output_img.reshape(data.shape)
        return BeamformedData(scan=scan, data=output_data.astype(np.complex64))
