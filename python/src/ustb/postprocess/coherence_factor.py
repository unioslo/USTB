"""Coherence factor adaptive beamforming.

Mallart-Fink coherence factor: weights beamformed data by the ratio of
coherent to incoherent energy to suppress off-axis echoes.
"""

import numpy as np
from ustb.enums import Dimension
from ustb.beamformed_data import BeamformedData


class CoherenceFactor:
    """Coherence factor postprocess matching MATLAB postprocess.coherence_factor."""

    def __init__(self):
        self.input = None
        self.dimension = Dimension.both
        self.active_element_criterium = 0.16

    def go(self):
        data = np.array(self.input.data)
        N_pixels = data.shape[0]
        N_channels = data.shape[1] if data.ndim > 1 else 1
        N_waves = data.shape[2] if data.ndim > 2 else 1
        N_frames = data.shape[3] if data.ndim > 3 else 1

        if self.dimension == Dimension.transmit:
            coherent_sum = np.sum(data, axis=2, keepdims=True)
            incoherent_sq = np.sum(np.abs(data) ** 2, axis=2, keepdims=True)
            M = float(N_waves)
        elif self.dimension == Dimension.receive:
            coherent_sum = np.sum(data, axis=1, keepdims=True)
            incoherent_sq = np.sum(np.abs(data) ** 2, axis=1, keepdims=True)
            M = float(N_channels)
        elif self.dimension == Dimension.both:
            coherent_sum = np.sum(np.sum(data, axis=2, keepdims=True), axis=1, keepdims=True)
            incoherent_sq = np.sum(np.sum(np.abs(data) ** 2, axis=2, keepdims=True), axis=1, keepdims=True)
            M = float(N_channels * N_waves)
        else:
            raise ValueError(f"Unsupported dimension: {self.dimension}")

        cf = np.abs(coherent_sum) ** 2 / (incoherent_sq * M + 1e-30)
        cf[np.isnan(cf)] = 0

        output_data = cf * coherent_sum
        output = BeamformedData(scan=self.input.scan, data=output_data.astype(np.complex64))
        return output
