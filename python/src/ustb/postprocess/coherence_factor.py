"""Coherence factor adaptive beamforming.

Mallart-Fink coherence factor: weights beamformed data by the ratio of
coherent to incoherent energy to suppress off-axis echoes.

Reference: R. Mallart and M. Fink, "Adaptive focusing in scattering media
through sound-speed inhomogeneities: The van Cittert Zernike approach and
focusing criterion", J. Acoust. Soc. Am., vol. 96, no. 6, pp. 3721-3732, 1994.
"""

import warnings

import numpy as np

from ustb.enums import Dimension, Window
from ustb.beamformed_data import BeamformedData


class CoherenceFactor:
    """Coherence factor postprocess matching MATLAB postprocess.coherence_factor.

    Properties mirror the MATLAB class: dimension, active_element_criterium,
    receive_apodization, transmit_apodization. After go(), the raw
    coherence-factor weight map is available as ``self.CF`` (a
    BeamformedData with the same scan).
    """

    def __init__(self):
        self.input = None
        self.dimension = Dimension.both
        self.active_element_criterium = 0.16
        self.receive_apodization = None
        self.transmit_apodization = None
        self.CF = None
        self.output = None

    def go(self):
        data = np.asarray(self.input.data)
        while data.ndim < 4:
            data = data[..., np.newaxis]
        N_pixels, N_channels, N_waves, N_frames = data.shape

        dimension = self.dimension
        if dimension == Dimension.receive and N_channels < 2:
            raise ValueError("Not enough channels to compute factor")
        if dimension == Dimension.transmit and N_waves < 2:
            raise ValueError("Not enough waves to compute factor")
        if dimension == Dimension.both:
            if N_channels < 2 and N_waves > 1:
                warnings.warn(
                    "Not enough channels to compute factor. "
                    "Changing dimension to dimension.transmit"
                )
                dimension = Dimension.transmit
            elif N_waves < 2 and N_channels > 1:
                warnings.warn(
                    "Not enough waves to compute factor. "
                    "Changing dimension to dimension.receive"
                )
                dimension = Dimension.receive
            elif N_waves < 2 and N_channels < 2:
                raise ValueError("Not enough waves and channels to compute factor")
        self.dimension = dimension

        rx_apod = (
            self._receive_apodization(N_pixels, N_channels)
            if dimension != Dimension.transmit else None
        )
        tx_apod = (
            self._transmit_apodization(N_pixels, N_waves)
            if dimension != Dimension.receive else None
        )

        threshold = self.active_element_criterium
        if dimension == Dimension.both:
            combined = rx_apod[:, :, np.newaxis] * tx_apod[:, np.newaxis, :]
            M = np.sum(combined > threshold, axis=(1, 2)).astype(np.float64)
            coherent_sum = np.sum(data, axis=(1, 2), keepdims=True)
            incoherent_2_sum = np.sum(np.abs(data) ** 2, axis=(1, 2), keepdims=True)
        elif dimension == Dimension.transmit:
            M = np.sum(tx_apod > threshold, axis=1).astype(np.float64)
            coherent_sum = np.sum(data, axis=2, keepdims=True)
            incoherent_2_sum = np.sum(np.abs(data) ** 2, axis=2, keepdims=True)
        elif dimension == Dimension.receive:
            M = np.sum(rx_apod > threshold, axis=1).astype(np.float64)
            coherent_sum = np.sum(data, axis=1, keepdims=True)
            incoherent_2_sum = np.sum(np.abs(data) ** 2, axis=1, keepdims=True)
        else:
            raise ValueError(f"Unsupported dimension: {dimension}")

        M = M.reshape(N_pixels, 1, 1, 1)
        with np.errstate(divide="ignore", invalid="ignore"):
            cf = (np.abs(coherent_sum) ** 2 / incoherent_2_sum) / M
        cf = np.nan_to_num(cf, nan=0.0, posinf=0.0, neginf=0.0)

        output_data = cf * coherent_sum

        self.CF = BeamformedData(scan=self.input.scan, data=cf.astype(np.float32))
        self.output = BeamformedData(scan=self.input.scan, data=output_data.astype(np.complex64))
        return self.output

    def _receive_apodization(self, N_pixels, N_channels):
        apo = self.receive_apodization
        if apo is None or apo.window == Window.none:
            return np.ones((N_pixels, N_channels), dtype=np.float32)
        apo.focus = self.input.scan
        return np.asarray(apo.data, dtype=np.float32)

    def _transmit_apodization(self, N_pixels, N_waves):
        apo = self.transmit_apodization
        sequence = getattr(self.input, "sequence", None)
        if apo is None or apo.window == Window.none or (apo.sequence is None and sequence is None):
            return np.ones((N_pixels, N_waves), dtype=np.float32)
        apo.focus = self.input.scan
        if apo.sequence is None:
            apo.sequence = sequence
        return np.asarray(apo.data, dtype=np.float32)
