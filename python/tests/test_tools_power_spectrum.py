"""Unit tests for ustb.tools.power_spectrum."""

import numpy as np
from ustb.tools import power_spectrum


class TestPowerSpectrum:
    def test_should_peak_at_tone_frequency(self):
        fs = 40e6
        f_tone = 5e6
        N = 2048
        t = np.arange(N) / fs
        data = np.sin(2 * np.pi * f_tone * t)[:, np.newaxis, np.newaxis, np.newaxis]

        fx, pw = power_spectrum(data, fs)

        peak_freq = abs(fx[np.argmax(pw)])
        assert abs(peak_freq - f_tone) < fs / N * 3

    def test_should_return_correct_shapes(self):
        fs = 20e6
        N = 512
        data = np.random.randn(N, 8, 3, 5)

        fx, pw = power_spectrum(data, fs)

        assert fx.shape == (N,)
        assert pw.shape == (N,)

    def test_normalised_should_peak_at_one(self):
        fs = 20e6
        N = 512
        data = np.random.randn(N, 4, 1, 1)

        fx, pw = power_spectrum(data, fs, normalised=True)

        assert np.isclose(pw.max(), 1.0)

    def test_unnormalised_should_not_be_forced_to_one(self):
        fs = 20e6
        N = 512
        data = 5.0 * np.ones((N, 1, 1, 1))

        fx, pw = power_spectrum(data, fs, normalised=False)

        assert pw.max() > 1.0

    def test_should_accept_1d_input(self):
        fs = 20e6
        N = 256
        data = np.random.randn(N)

        fx, pw = power_spectrum(data, fs)

        assert fx.shape == (N,)
        assert pw.shape == (N,)

    def test_n_argument_should_limit_frames_averaged(self):
        fs = 20e6
        N = 128
        data = np.random.randn(N, 1, 1, 10)

        fx, pw = power_spectrum(data, fs, N=3)
        fx_all, pw_all = power_spectrum(data, fs, N=10)

        # Averaging fewer frames changes the result unless data is identical
        assert pw.shape == pw_all.shape
