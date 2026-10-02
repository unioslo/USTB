"""Phase coherence factor (PCF).

Weights the coherent sum by the spread of the signal phases across the
aperture (and/or waves): FCC from the circular variance, FCA from the
standard deviation of the phase.

Reference: J. Camacho and C. Fritsch, "Phase coherence imaging of grained
materials", IEEE TUFFC 58(5):1006-1015, 2011.
"""

import numpy as np

from ustb.beamformed_data import BeamformedData
from ustb.enums import Dimension
from ustb.postprocess._common import (as_4d, receive_weights, resolve_dimension,
                                      transmit_weights)


def _weighted_var(values, weights, axis):
    """MATLAB tools.weigthed_var: sum(W * (D - mean_W(D))^2) / sum(W)."""
    total = weights.sum(axis=axis, keepdims=True)
    mean = (weights * values).sum(axis=axis, keepdims=True) / total
    return (weights * (values - mean) ** 2).sum(axis=axis, keepdims=True) / total


class PhaseCoherenceFactor:
    """Port of MATLAB postprocess.phase_coherence_factor.

    After go(), ``self.FCC`` (complex factor, used for the output) and
    ``self.FCA`` (absolute factor) hold the two factors.
    """

    def __init__(self):
        self.input = None
        self.dimension = Dimension.both
        self.center_frequency = None
        self.sound_speed = 1540.0
        self.gamma = 1.0
        self.sigma_0 = np.pi / np.sqrt(3)
        self.receive_apodization = None
        self.transmit_apodization = None
        self.FCA = None
        self.FCC = None
        self.output = None

    def go(self):
        data = as_4d(self.input.data)
        N_pixels, N_channels, N_waves, N_frames = data.shape
        self.dimension = resolve_dimension(self.dimension, N_channels, N_waves)
        scan = self.input.scan

        rx = (receive_weights(self.receive_apodization, scan, N_pixels, N_channels)
              if self.dimension != Dimension.transmit else None)
        tx = (transmit_weights(self.transmit_apodization, scan,
                               getattr(self.input, "sequence", None), N_pixels, N_waves)
              if self.dimension != Dimension.receive else None)

        if self.center_frequency is None:
            aux_data = data
        else:
            # Remove the two-way receive propagation phase (MATLAB: incidence_aperture distance)
            self.receive_apodization.focus = scan
            distance = self.receive_apodization._incidence_aperture(return_distance=True)[2]
            aux_data = data * np.exp(-2j * np.pi * self.center_frequency * 2 * distance
                                     / self.sound_speed)[:, :, None, None]

        phase = np.angle(aux_data)
        auxiliary = np.where(phase <= 0, phase + np.pi, phase - np.pi)

        if self.dimension == Dimension.both:
            coherent_sum = data.sum(axis=(1, 2), keepdims=True)
            shape = (N_pixels, N_channels * N_waves, 1, N_frames)
            phase, auxiliary = phase.reshape(shape), auxiliary.reshape(shape)
            weights = (rx[:, :, None] * tx[:, None, :]).reshape(N_pixels, -1)[:, :, None, None]
            axis = 1
        elif self.dimension == Dimension.transmit:
            coherent_sum = data.sum(axis=2, keepdims=True)
            weights, axis = tx[:, None, :, None], 2
        elif self.dimension == Dimension.receive:
            coherent_sum = data.sum(axis=1, keepdims=True)
            weights, axis = rx[:, :, None, None], 1
        else:
            raise ValueError(f"Unsupported dimension: {self.dimension}")

        std_phase = np.sqrt(_weighted_var(phase, weights, axis))
        std_auxiliary = np.sqrt(_weighted_var(auxiliary, weights, axis))
        std_complex = np.sqrt(_weighted_var(np.cos(phase), weights, axis)
                              + _weighted_var(np.sin(phase), weights, axis))

        fca = 1 - (self.gamma / self.sigma_0) * np.minimum(std_phase, std_auxiliary)
        fca[fca < 0] = 0
        fca[np.isnan(fca)] = 0
        fcc = 1 - std_complex

        self.FCA = BeamformedData(scan=scan, data=fca.astype(np.float32))
        self.FCC = BeamformedData(scan=scan, data=fcc.astype(np.float32))
        self.output = BeamformedData(scan=scan, data=(fcc * coherent_sum).astype(np.complex64))
        return self.output
