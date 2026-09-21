"""Coherent compounding postprocess matching MATLAB postprocess.coherent_compounding.

Sums complex beamformed data across the transmit/receive dimension(s),
preserving phase (as opposed to incoherent compounding, which sums
magnitudes).
"""

import numpy as np
from numpy.lib.stride_tricks import sliding_window_view

from ustb.enums import Dimension
from ustb.beamformed_data import BeamformedData


def _moving_sum(x, window_size, axis):
    """Sliding-window sum along ``axis``, discarding incomplete windows.

    Matches MATLAB movsum(x, window_size, axis, 'Endpoints', 'discard'):
    output length along axis is N - window_size + 1.
    """
    x = np.moveaxis(x, axis, -1)
    windows = sliding_window_view(x, window_shape=window_size, axis=-1)
    summed = windows.sum(axis=-1)
    return np.moveaxis(summed, -1, axis)


class CoherentCompounding:
    """Coherent compounding postprocess matching MATLAB postprocess.coherent_compounding."""

    def __init__(self):
        self.input = None
        self.dimension = Dimension.both
        self.window_size = None

    def go(self):
        data = np.asarray(self.input.data)
        while data.ndim < 4:
            data = data[..., np.newaxis]

        if self.window_size is None:
            if self.dimension == Dimension.both:
                out = np.sum(data, axis=(1, 2), keepdims=True)
            elif self.dimension == Dimension.transmit:
                out = np.sum(data, axis=2, keepdims=True)
            elif self.dimension == Dimension.receive:
                out = np.sum(data, axis=1, keepdims=True)
            else:
                raise ValueError(f"Unsupported dimension: {self.dimension}")
        else:
            N_pixels, N_channels, N_waves, N_frames = data.shape
            if self.window_size > N_waves:
                raise ValueError(
                    "Cannot have a window size greater than the available "
                    "number of transmit events."
                )
            reshaped = data.reshape(N_pixels, N_channels, 1, N_waves * N_frames)

            if self.dimension == Dimension.both:
                summed = np.sum(reshaped, axis=1, keepdims=True)
                out = _moving_sum(summed, self.window_size, axis=3)
            elif self.dimension == Dimension.transmit:
                out = _moving_sum(reshaped, self.window_size, axis=3)
            elif self.dimension == Dimension.receive:
                # Matches MATLAB: window_size is ignored for dimension.receive.
                out = np.sum(data, axis=1, keepdims=True)
            else:
                raise ValueError(f"Unsupported dimension: {self.dimension}")

        return BeamformedData(scan=self.input.scan, data=out.astype(data.dtype))
