"""Short-lag spatial coherence (SLSC) imaging.

For each pixel, the normalized correlation between pairs of channel signals
over a short depth kernel is averaged over all pairs at each lag m, and the
image is the sum over lags 1..maxM, normalized to its maximum.

References: M. A. Lediju, G. E. Trahey, B. C. Byram and J. J. Dahl,
"Short-lag spatial coherence of backscattered echoes: Imaging
characteristics", IEEE TUFFC 58(7):1377-1388, 2011; M. A. Lediju Bell et
al., "Short-Lag Spatial Coherence (SLSC) Imaging of Cardiac Ultrasound
Data: Initial Clinical Results", UMB 39(10):1861-1874, 2013.
"""

import numpy as np

from ustb._scan_grid import from_image, to_image
from ustb.beamformed_data import BeamformedData
from ustb.enums import Dimension, Window
from ustb.postprocess._common import as_4d
from ustb.postprocess.capon_minimum_variance import _samples_from_lambda


def _kernel_sum(values, K):
    """Sum over a centered depth window of K samples, truncated at the edges (axis 0)."""
    half = (K - 1) // 2
    N = values.shape[0]
    padded = np.concatenate([np.zeros((1,) + values.shape[1:]), np.cumsum(values, axis=0)])
    upper = np.minimum(np.arange(N) + half + 1, N)
    lower = np.maximum(np.arange(N) - half, 0)
    return padded[upper] - padded[lower]


def slsc_lags(signals, K, maxM):
    """Mean normalized correlation per lag for one image line.

    signals: [depth, elements] real signals of the active elements.
    Returns [depth, maxM]; lag m (1-based) pairs elements i and i + m.
    """
    N, E = signals.shape
    energy = _kernel_sum(signals ** 2, K)
    values = np.zeros((N, maxM))
    for m in range(1, min(maxM, E - 1) + 1):
        cross = _kernel_sum(signals[:, :-m] * signals[:, m:], K)
        with np.errstate(divide="ignore", invalid="ignore"):
            correlation = cross / np.sqrt(energy[:, :-m] * energy[:, m:])
        correlation[~np.isfinite(correlation)] = 0
        values[:, m - 1] = correlation.mean(axis=1)
    return values


class ShortLagSpatialCoherence:
    """Python counterpart of MATLAB postprocess.short_lag_spatial_coherence.

    MATLAB computes the per-lag correlations in a compiled MEX (mex.slsc_mex)
    whose source is not in the repository; this implements the published
    definition. ``K_in_lambda`` gives the depth kernel, converted to an odd
    number of samples K as in MATLAB and used as a centered window of K
    samples (truncated at the image edges). Elements whose data are zero over
    the whole image line are left out, and lags count active elements, as in
    MATLAB. After go(), the per-lag values are in ``self.slsc_values``
    ([depth, lateral, lag] per wave or channel processed last).

    No apodization may be used (receive and transmit window none).
    """

    def __init__(self):
        self.input = None
        self.dimension = None
        self.maxM = None
        self.active_element_criterium = 0.16
        self.channel_data = None
        self.receive_apodization = None
        self.transmit_apodization = None
        self.slsc_values = None
        self.output = None
        self._K_in_lambda = None
        self._K_samples = None

    @property
    def K_in_lambda(self):
        return self._K_in_lambda

    @K_in_lambda.setter
    def K_in_lambda(self, value):
        if self.input is None:
            raise ValueError("You need to set the beamformed_data input first.")
        self._K_in_lambda = value
        self._K_samples = _samples_from_lambda(self.input.scan, self.channel_data, value)

    def go(self):
        data = as_4d(self.input.data)
        N_pixels, N_channels, N_waves, N_frames = data.shape
        if self._K_samples is None:
            raise ValueError("Set input, channel_data and then K_in_lambda before go()")
        for apodization in (self.receive_apodization, self.transmit_apodization):
            if apodization is not None and apodization.window != Window.none:
                raise ValueError("Please use window none (no apodization) with the SLSC beamformer.")

        if self.dimension is None:
            self.dimension = Dimension.receive if N_channels > 1 else Dimension.transmit
        dimension = Dimension(int(getattr(self.dimension, "value", self.dimension)))
        if self.maxM is None:
            aperture = N_channels if dimension == Dimension.receive else N_waves
            self.maxM = int(np.floor(0.3 * aperture + 0.5))  # MATLAB round

        scan = self.input.scan
        if dimension == Dimension.receive:
            out = np.zeros((N_pixels, 1, N_waves, N_frames), dtype=np.float32)
            for f in range(N_frames):
                for w in range(N_waves):
                    out[:, 0, w, f] = from_image(self._image(to_image(data[:, :, w, f], scan)), scan)
        elif dimension == Dimension.transmit:
            out = np.zeros((N_pixels, N_channels, 1, N_frames), dtype=np.float32)
            for f in range(N_frames):
                for c in range(N_channels):
                    out[:, c, 0, f] = from_image(self._image(to_image(data[:, c, :, f], scan)), scan)
        elif dimension == Dimension.both:
            raise ValueError("Both dimensions are not defined for SLSC. "
                             "Consider using transmit or receive dimensions.")
        else:
            raise ValueError(f"Unsupported dimension: {self.dimension}")

        self.output = BeamformedData(scan=scan, data=out)
        return self.output

    def _image(self, cube):
        """SLSC image of a [depth, lateral, aperture] cube, normalized to its maximum."""
        signals = np.real(cube).astype(np.float64)
        N_depth, N_lateral, _ = signals.shape
        values = np.zeros((N_depth, N_lateral, self.maxM))
        for x in range(N_lateral):
            active = np.abs(signals[:, x, :].sum(axis=0)) > 0
            values[:, x, :] = slsc_lags(signals[:, x, active], self._K_samples, self.maxM)
        self.slsc_values = values
        image = values.sum(axis=2)
        peak = image.max()
        return image / peak if peak != 0 else image
