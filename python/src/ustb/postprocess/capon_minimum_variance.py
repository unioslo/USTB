"""Capon minimum variance (MV) adaptive beamforming.

Spatially smoothed (subarray-averaged) MV with temporal averaging over
2*K+1 depth samples, diagonal loading and optional forward-backward
averaging, applied across the receive channels (or waves) of beamformed data.

Reference: J. F. Synnevag, A. Austeng and S. Holm, "Benefits of
minimum-variance beamforming in medical ultrasound imaging", IEEE TUFFC
56(9):1868-1879, 2009.
"""

import warnings

import numpy as np
from numba import njit, prange

from ustb._scan_grid import from_image, to_image
from ustb.beamformed_data import BeamformedData
from ustb.enums import Dimension, Window
from ustb.postprocess._common import as_4d, resolve_dimension


@njit(parallel=True, cache=True)
def _capon_kernel(data_cube, apod_cube, K, L_elements, reg_coef, forward_backward, criterium):
    """Port of MATLAB capon_minimum_variance_implementation.

    data_cube, apod_cube: [depth, lateral, aperture]. Returns [depth, lateral].
    MATLAB forms R = X^H X with snapshots as rows and outputs w' * x', so the
    result is the complex conjugate of the textbook w^H x (same envelope);
    this port keeps MATLAB's convention.
    """
    N, E, M = data_cube.shape
    z = np.zeros((N, E), dtype=np.complex128)
    eps = np.finfo(np.float64).eps
    for e in prange(E):
        for k in range(N):
            row = data_cube[k, e, :]
            if not np.any(np.abs(row) > eps):
                continue
            idx = np.nonzero(np.abs(apod_cube[k, e, :]) > criterium)[0]
            M_new = idx.size
            if M_new < 2:
                z[k, e] = row.sum()
                continue
            L_new = int(np.floor(L_elements / M * M_new))
            if L_new < 1:
                L_new = 1
            elif L_new >= M_new:
                L_new = M_new - 1
            first, last = idx[0], idx[-1]
            if last - L_new + 1 < first:
                z[k, e] = row.sum()
                continue

            # Snapshot rows (MATLAB 1-based k-K..k+K, truncated at the edges)
            if k < K:
                r0, r1 = 0, min(k + K + 1, N)
            elif k + K + 1 > N:
                r0, r1 = k - K, N
            else:
                r0, r1 = k - K, k + K + 1

            R = np.zeros((L_new, L_new), dtype=np.complex128)
            for l in range(first, last - L_new + 2):
                X = data_cube[r0:r1, e, l:l + L_new]
                R += np.conj(X).T @ X
            R /= (2 * K + 1) * (M_new - L_new + 1)
            if forward_backward:
                R = 0.5 * (R + np.conj(R)[::-1, ::-1])

            a = np.ones(L_new, dtype=np.complex128)
            loaded = R + np.eye(L_new) * (reg_coef / L_new) * np.trace(R)
            Ria = np.linalg.solve(loaded, a)
            w = Ria / np.sum(Ria)

            acc = 0j
            for j in range(first, last - L_new + 2):
                acc += np.sum(np.conj(w) * np.conj(data_cube[k, e, j:j + L_new]))
            z[k, e] = acc / (M_new - L_new + 1) * M_new
    return z


class CaponMinimumVariance:
    """Port of MATLAB postprocess.capon_minimum_variance.

    Set ``scan`` and ``channel_data`` before ``K_in_lambda`` (it is converted
    to a number of depth samples, as in MATLAB). ``L_elements`` is the
    subarray length for the full aperture; it is scaled to the number of
    active elements per pixel.
    """

    def __init__(self):
        self.input = None
        self.dimension = Dimension.both
        self.active_element_criterium = 0.16
        self.L_elements = None
        self.regCoef = None
        self.doForwardBackward = False
        self.channel_data = None
        self.scan = None
        self.receive_apodization = None
        self.transmit_apodization = None
        self.output = None
        self._K_in_lambda = None
        self._K_samples = None

    @property
    def K_in_lambda(self):
        return self._K_in_lambda

    @K_in_lambda.setter
    def K_in_lambda(self, value):
        self._K_in_lambda = value
        self._K_samples = _samples_from_lambda(self.scan, self.channel_data, value)

    def go(self):
        data = as_4d(self.input.data)
        N_pixels, N_channels, N_waves, N_frames = data.shape
        self.dimension = resolve_dimension(self.dimension, N_channels, N_waves)
        if self._K_samples is None:
            raise ValueError("Set scan, channel_data and then K_in_lambda before go()")
        scan = self.input.scan
        rx, tx = self._apodization(N_pixels, N_channels, N_waves)

        def run(cube, apod):
            image = _capon_kernel(to_image(cube, scan).astype(np.complex128),
                                  to_image(apod, scan).astype(np.float64),
                                  int(self._K_samples), float(self.L_elements),
                                  float(self.regCoef), bool(self.doForwardBackward),
                                  float(self.active_element_criterium))
            return from_image(image, scan)

        if self.dimension == Dimension.both:
            warnings.warn("Capon minimum variance on both dimensions simultaneously has not "
                          "been done in the literature before, and might not make sense.")
            out = np.zeros((N_pixels, 1, 1, N_frames), dtype=np.complex64)
            # Channel varies fastest in the combined aperture, as in MATLAB
            apod = (rx[:, :, None] * tx[:, None, :]).reshape(N_pixels, -1, order="F")
            for f in range(N_frames):
                out[:, 0, 0, f] = run(data[:, :, :, f].reshape(N_pixels, -1, order="F"), apod)
        elif self.dimension == Dimension.transmit:
            out = np.zeros((N_pixels, N_channels, 1, N_frames), dtype=np.complex64)
            for f in range(N_frames):
                for c in range(N_channels):
                    # MATLAB indexes rx_apodization(n_channel) linearly here, which
                    # picks pixel n_channel; the receive weight of channel c is meant
                    out[:, c, 0, f] = run(data[:, c, :, f], tx * rx[:, c:c + 1])
        else:  # receive
            out = np.zeros((N_pixels, 1, N_waves, N_frames), dtype=np.complex64)
            partial = _partial_aperture(self.channel_data)
            for f in range(N_frames):
                for w in range(N_waves):
                    cube = data[:, :, w, f]
                    apod = tx[:, w:w + 1] * rx
                    if partial:
                        apod = np.where(np.abs(cube) < np.finfo(np.float64).eps, 0.0, apod)
                    out[:, 0, w, f] = run(cube, apod)

        self.output = BeamformedData(scan=scan, data=out)
        return self.output

    def _apodization(self, N_pixels, N_channels, N_waves):
        rx = np.ones((N_pixels, N_channels))
        tx = np.ones((N_pixels, N_waves))
        probe = getattr(self.channel_data, "probe", None)
        if (self.receive_apodization is not None and self.transmit_apodization is not None
                and probe is not None):
            if N_channels > 1 and self.receive_apodization.window != Window.none:
                self.receive_apodization.probe = probe
                self.receive_apodization.focus = self.input.scan
                rx = np.asarray(self.receive_apodization.data, dtype=np.float64)
            if N_waves > 1 and self.transmit_apodization.window != Window.none:
                self.transmit_apodization.probe = None
                self.transmit_apodization.sequence = self.channel_data.sequence
                self.transmit_apodization.focus = self.input.scan
                tx = np.asarray(self.transmit_apodization.data, dtype=np.float64)
        return rx, tx


def _samples_from_lambda(scan, channel_data, K_in_lambda):
    """MATLAB set.K_in_lambda: number of depth samples (odd) closest to K wavelengths."""
    if scan is None or channel_data is None:
        raise ValueError("Set scan and channel_data before K_in_lambda")
    wavelength = channel_data.sound_speed / channel_data.pulse.center_frequency
    axis = getattr(scan, "z_axis", None)
    if axis is None:
        axis = scan.depth_axis
    z_in_lambda = np.asarray(axis, dtype=np.float64).ravel() / wavelength
    z_in_lambda = z_in_lambda - z_in_lambda[0]
    samples = int(np.argmin(np.abs(z_in_lambda - K_in_lambda))) + 1  # MATLAB 1-based index
    return samples if samples % 2 else samples + 1


def _partial_aperture(channel_data):
    """True when only part of the probe is active (MATLAB N_active_elements check)."""
    active = getattr(channel_data, "N_active_elements", None)
    if active is None:
        return False
    N_elements = channel_data.probe.N_elements
    return bool(np.any(np.asarray(active) != N_elements))
