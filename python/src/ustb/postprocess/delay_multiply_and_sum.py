"""Delay multiply and sum (DMAS) beamforming.

Sums the signed square roots of all pairwise products of the delayed (real,
RF) channel signals, then band-pass filters around twice the center
frequency and takes the analytic signal.

Reference: G. Matrone, A. S. Savoia, G. Caliano and G. Magenes, "The Delay
Multiply and Sum Beamforming Algorithm in Ultrasound B-Mode Medical Imaging",
IEEE TMI 34(4):940-949, 2015.
"""

import warnings

import numpy as np
from scipy.signal import firwin, hilbert, lfilter

from ustb._scan_grid import from_image, to_image
from ustb.beamformed_data import BeamformedData
from ustb.enums import Dimension, Window
from ustb.postprocess._common import as_4d
from ustb.postprocess.capon_minimum_variance import _partial_aperture
from ustb.tools.estimate_frequency import estimate_frequency


class DelayMultiplyAndSum:
    """Port of MATLAB postprocess.delay_multiply_and_sum.

    Needs RF beamformed data (the real part is used), a linear scan with a
    fine enough depth sampling for the band around 2 * f0, and
    ``channel_data`` (for the sound speed). ``filter_freqs`` optionally gives
    the four band edges [Hz] of the band-pass filter; by default they are set
    from the estimated center frequency f0 as
    [1.5 f0, 1.75 f0, 2.5 f0, 2.75 f0].
    """

    def __init__(self):
        self.input = None
        self.dimension = None
        self.channel_data = None
        self.filter_freqs = None
        self.receive_apodization = None
        self.transmit_apodization = None
        self.output = None

    def go(self):
        if self.input is None:
            raise ValueError("We need some data. Please add some beamformed_data.")
        if self.channel_data is None:
            raise ValueError("We need the channel_data object for some parameters. Please add it.")
        data = as_4d(self.input.data)
        N_pixels, N_channels, N_waves, N_frames = data.shape
        scan = self.input.scan
        rx, tx = self._apodization(N_pixels, N_channels, N_waves)
        dimension = Dimension(int(getattr(self.dimension, "value", self.dimension)))

        def run(cube, apod):
            image = self._dmas(to_image(np.real(cube), scan), to_image(apod, scan))
            return from_image(image, scan)

        if dimension == Dimension.both:
            warnings.warn("Delay multiply and sum on both dimensions simultaneously has not "
                          "been done in the literature before, and might not make sense.")
            out = np.zeros((N_pixels, 1, 1, N_frames), dtype=np.complex64)
            apod = (rx[:, :, None] * tx[:, None, :]).reshape(N_pixels, -1, order="F")
            for f in range(N_frames):
                out[:, 0, 0, f] = run(data[:, :, :, f].reshape(N_pixels, -1, order="F"), apod)
        elif dimension == Dimension.transmit:
            out = np.zeros((N_pixels, N_channels, 1, N_frames), dtype=np.complex64)
            for f in range(N_frames):
                for c in range(N_channels):
                    out[:, c, 0, f] = run(data[:, c, :, f], tx * rx[:, c:c + 1])
        elif dimension == Dimension.receive:
            out = np.zeros((N_pixels, 1, N_waves, N_frames), dtype=np.complex64)
            partial = _partial_aperture(self.channel_data)
            for f in range(N_frames):
                for w in range(N_waves):
                    cube = data[:, :, w, f]
                    apod = tx[:, w:w + 1] * rx
                    if partial:
                        apod = np.where(np.abs(cube) < np.finfo(np.float64).eps, 0.0, apod)
                    out[:, 0, w, f] = run(cube, apod)
        else:
            raise ValueError(f"Unsupported dimension: {self.dimension}")

        self.output = BeamformedData(scan=scan, data=out)
        return self.output

    def _dmas(self, data_cube, apod_cube):
        """MATLAB delay_multiply_and_sum_implementation on a [depth, lateral, aperture] cube."""
        z_axis = np.asarray(self.input.scan.z_axis, dtype=np.float64).ravel()
        c = float(self.channel_data.sound_speed)
        fs = c / np.mean(np.diff(z_axis)) / 2  # effective sampling frequency of the image

        if self.filter_freqs is None:
            f0, _ = estimate_frequency(2 * z_axis / c, data_cube)
            F = np.array([1.5 * f0, 1.5 * f0 + f0 / 4, 2.5 * f0, 2.5 * f0 + f0 / 4])
        else:
            F = np.asarray(self.filter_freqs, dtype=np.float64)
        if not fs / 2 > F[-1]:
            raise ValueError(
                f"We need {int(np.ceil(F[-1] * 2 / fs))} times more samples in the z-direction "
                "in the image to be able to do DMAS with filtering around 2 times the center "
                "frequency. And for the Hilbert transform"
            )

        # Sum over pairs i < j of sign(x_i x_j) sqrt(|x_i x_j|) = ((sum s)^2 - sum s^2) / 2
        # with s = sign(x) sqrt(|x|), over the elements with non-zero apodization
        s = np.sign(data_cube) * np.sqrt(np.abs(data_cube)) * (apod_cube != 0)
        y = ((s.sum(axis=2) ** 2 - (s ** 2).sum(axis=2)) / 2).astype(np.float32)

        b = _kaiser_bandpass(F, fs)
        delay = int(np.floor((len(b) - 1) / 2 + 0.5))  # MATLAB round
        padded = np.concatenate([y, np.zeros((delay,) + y.shape[1:], dtype=y.dtype)], axis=0)
        filtered = lfilter(b, 1, padded, axis=0)[delay:]
        return hilbert(filtered, axis=0)

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
                # MATLAB also sets the probe here, which makes uff.apodization compute a
                # receive-style apodization; the transmit (wave) apodization is meant
                self.transmit_apodization.probe = None
                self.transmit_apodization.sequence = self.channel_data.sequence
                self.transmit_apodization.focus = self.input.scan
                tx = np.asarray(self.transmit_apodization.data, dtype=np.float64)
        return rx, tx


def _kaiser_bandpass(F, fs, dev=1e-3):
    """MATLAB fir1(kaiserord(F, [0 1 0], [dev dev dev], fs), ..., 'noscale') band-pass."""
    atten = -20 * np.log10(dev)
    if atten > 50:
        beta = 0.1102 * (atten - 8.7)
    elif atten >= 21:
        beta = 0.5842 * (atten - 21) ** 0.4 + 0.07886 * (atten - 21)
    else:
        beta = 0.0
    f = np.asarray(F, dtype=np.float64) / fs
    D = (atten - 7.95) / (2 * np.pi * 2.285)
    L = max(D / abs(f[1] - f[0]) + 1, D / abs(f[3] - f[2]) + 1)
    order = int(np.ceil(L)) - 1
    Wn = np.array([f[0] + f[1], f[2] + f[3]])  # band-edge midpoints, normalized to Nyquist
    return firwin(order + 1, Wn, window=("kaiser", beta), pass_zero=False, scale=False, fs=2.0)
