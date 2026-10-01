"""Generalized coherence factor (GCF).

Ratio of the low-frequency energy to the total energy of the aperture
spectrum, used to weight the coherent sum.

Reference: Pai-Chi Li and Meng-Lin Li, "Adaptive Imaging Using the Generalized
Coherence Factor", IEEE TUFFC 50(2):128-141, 2003.
"""

import numpy as np

from ustb.beamformed_data import BeamformedData
from ustb.enums import Dimension
from ustb.postprocess._common import as_4d, resolve_dimension


class GeneralizedCoherenceFactor:
    """Port of MATLAB postprocess.generalized_coherence_factor.

    ``M0`` sets the low-frequency region: spatial frequencies 0..M0 and
    -M0..-1 of the aperture (and/or wave) FFT. After go(), the factor is in
    ``self.GCF``.
    """

    def __init__(self):
        self.input = None
        self.dimension = Dimension.both
        self.M0 = 4
        self.active_element_criterium = 0.16  # kept for API parity; unused, as in MATLAB
        self.receive_apodization = None
        self.transmit_apodization = None
        self.GCF = None
        self.output = None

    @staticmethod
    def _low_frequency_indices(N, M0):
        if M0 > 1 and N > 1:
            if M0 + 1 > N:
                raise ValueError(f"M0 = {M0} needs at least {M0 + 1} elements (or waves); got {N}")
            # MATLAB [1:M0+1, N-M0+1:N]; overlapping indices are counted twice there too
            return np.r_[0:M0 + 1, N - M0:N]
        return np.array([0])

    def go(self):
        data = as_4d(self.input.data)
        N_pixels, N_channels, N_waves, N_frames = data.shape
        self.dimension = resolve_dimension(self.dimension, N_channels, N_waves)
        # Only the axes that are summed are checked (MATLAB only indexes those)
        aperture = (self._low_frequency_indices(N_channels, self.M0)
                    if self.dimension != Dimension.transmit else None)
        waves = (self._low_frequency_indices(N_waves, self.M0)
                 if self.dimension != Dimension.receive else None)

        if self.dimension == Dimension.both:
            coherent_sum = data.sum(axis=(1, 2), keepdims=True)
            spectrum = np.abs(np.fft.fft2(data, axes=(1, 2))) ** 2
            low = spectrum[:, aperture][:, :, waves].sum(axis=(1, 2), keepdims=True)
            total = spectrum.sum(axis=(1, 2), keepdims=True)
        elif self.dimension == Dimension.transmit:
            coherent_sum = data.sum(axis=2, keepdims=True)
            spectrum = np.abs(np.fft.fft(data, axis=2)) ** 2
            low = spectrum[:, :, waves].sum(axis=2, keepdims=True)
            total = spectrum.sum(axis=2, keepdims=True)
        elif self.dimension == Dimension.receive:
            coherent_sum = data.sum(axis=1, keepdims=True)
            spectrum = np.abs(np.fft.fft(data, axis=1)) ** 2
            low = spectrum[:, aperture].sum(axis=1, keepdims=True)
            total = spectrum.sum(axis=1, keepdims=True)
        else:
            raise ValueError(f"Unsupported dimension: {self.dimension}")

        with np.errstate(divide="ignore", invalid="ignore"):
            gcf = low / total
        gcf[np.isnan(gcf)] = 0

        self.GCF = BeamformedData(scan=self.input.scan, data=gcf.astype(np.float32))
        self.output = BeamformedData(scan=self.input.scan,
                                     data=(gcf * coherent_sum).astype(np.complex64))
        return self.output
