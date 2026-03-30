"""Apodization computation matching MATLAB uff.apodization.

Computes pixel-dependent apodization weights for receive elements or
transmit waves, implementing Eqs. (22)-(23) of the Generalized Beamformer.
"""

import numpy as np
from ustb.enums import Window


class Apodization:
    """Apodization weights for receive or transmit channels.

    Mirrors MATLAB uff.apodization. For receive apodization, set probe and
    focus. For transmit apodization, set sequence and focus.
    """

    def __init__(self):
        self.probe = None
        self.focus = None
        self.sequence = None
        self.f_number = np.array([1.0, 1.0])
        self.window = Window.none
        self.MLA = np.array([1, 1])
        self.MLA_overlap = np.array([0, 0])
        self.tilt = np.array([0.0, 0.0])
        self.minimum_aperture = np.array([1e-3, 1e-3])
        self.maximum_aperture = np.array([10.0, 10.0])
        self.apodization_vector = None
        self.origin = None

    @property
    def N_elements(self):
        if self.probe is not None:
            return self.probe.N_elements
        elif self.sequence is not None:
            return len(self.sequence)
        return 0

    @property
    def data(self):
        """Compute apodization matrix [N_pixels x N_elements_or_waves]."""
        if self.focus is None:
            raise ValueError("Apodization requires focus (scan) to be set")

        N_pixels = getattr(self.focus, "N_pixels", None) or self.focus.x.size

        if self.window == Window.none:
            return np.ones((N_pixels, self.N_elements), dtype=np.float32)

        if self.probe is not None:
            return self._receive_apodization()
        elif self.sequence is not None:
            return self._transmit_apodization()
        else:
            return np.ones((N_pixels, 1), dtype=np.float32)

    def _receive_apodization(self):
        """Compute receive apodization based on probe geometry and f-number."""
        N_pixels = getattr(self.focus, "N_pixels", None) or self.focus.x.size
        N_elements = self.probe.N_elements

        if self.apodization_vector is not None:
            apo = np.tile(self.apodization_vector, (N_pixels, 1))
            return apo.astype(np.float32)

        if self.window == Window.boxcar or self.window == Window.rectangular:
            return np.ones((N_pixels, N_elements), dtype=np.float32)

        scan_x = self.focus.x.ravel()
        scan_z = self.focus.z.ravel()
        probe_x = self.probe.x.ravel()

        dx = np.abs(probe_x[np.newaxis, :] - scan_x[:, np.newaxis])
        aperture = scan_z[:, np.newaxis] / self.f_number[0]
        aperture = np.clip(aperture, self.minimum_aperture[0], self.maximum_aperture[0])
        ratio = dx / (aperture / 2.0 + 1e-20)

        apo = self._apply_window(ratio)
        apo[ratio > 1.0] = 0.0
        return apo.astype(np.float32)

    def _transmit_apodization(self):
        """Compute transmit apodization based on wave sequence."""
        N_pixels = getattr(self.focus, "N_pixels", None) or self.focus.x.size
        N_waves = len(self.sequence)

        if self.window == Window.scanline:
            return self._scanline_apodization()

        if self.window == Window.none:
            return np.ones((N_pixels, N_waves), dtype=np.float32)

        return np.ones((N_pixels, N_waves), dtype=np.float32)

    def _scanline_apodization(self):
        """Scanline apodization for focused imaging."""
        N_pixels = getattr(self.focus, "N_pixels", None) or self.focus.x.size
        N_waves = len(self.sequence)

        scan_x = self.focus.x.ravel()
        scan_y = self.focus.y.ravel() if self.focus.y is not None else np.zeros_like(scan_x)

        source_az = np.array([w.source.azimuth for w in self.sequence])

        apo = np.zeros((N_pixels, N_waves), dtype=np.float32)

        if N_waves > 1:
            d_az = np.abs(np.diff(source_az)).mean()
        else:
            d_az = 1.0

        for n_wave in range(N_waves):
            az = source_az[n_wave]
            scan_az = np.arctan2(scan_x, self.focus.z.ravel() + 1e-20)
            diff = np.abs(scan_az - az)
            mask = diff <= d_az * self.MLA[0] / 2.0
            apo[mask, n_wave] = 1.0

        return apo

    def _apply_window(self, ratio):
        """Apply window function to normalized aperture ratio."""
        if self.window == Window.hanning:
            return 0.5 * (1.0 + np.cos(np.pi * ratio))
        elif self.window == Window.hamming:
            return 0.54 + 0.46 * np.cos(np.pi * ratio)
        elif self.window == Window.tukey25:
            return self._tukey(ratio, 0.25)
        elif self.window == Window.tukey50:
            return self._tukey(ratio, 0.50)
        elif self.window == Window.tukey75:
            return self._tukey(ratio, 0.75)
        elif self.window == Window.triangle:
            return 1.0 - np.abs(ratio)
        else:
            return np.ones_like(ratio)

    @staticmethod
    def _tukey(ratio, alpha):
        result = np.ones_like(ratio)
        mask = ratio > (1.0 - alpha)
        result[mask] = 0.5 * (1.0 + np.cos(np.pi * (ratio[mask] - (1.0 - alpha)) / alpha))
        return result
