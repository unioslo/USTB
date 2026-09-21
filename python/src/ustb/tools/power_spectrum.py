"""Averaged power spectrum matching MATLAB tools.power_spectrum."""

import numpy as np


def power_spectrum(data, fs, normalised=True, N=None):
    """Compute the averaged power spectrum of channel data.

    Mirrors MATLAB tools.power_spectrum(data, fs, normalised, N). The
    spectrum is averaged over channels, waves, and the first ``N`` frames.

    Args:
        data: array with time as its first axis (1-D to 4-D).
        fs: sampling frequency [Hz].
        normalised: if True, normalize the spectrum to a peak of 1.
        N: number of frames to average (default: min(100, N_frames)).

    Returns:
        (fx, pw): frequency axis [Hz] and averaged power spectrum.
    """
    data = np.asarray(data)
    while data.ndim < 4:
        data = data[..., np.newaxis]

    if N is None:
        N = min(100, data.shape[3])

    pw = np.fft.fftshift(np.fft.fft(data[:, :, :, :N], axis=0), axes=0)
    pw = np.mean(np.abs(pw) ** 2, axis=(1, 2, 3))
    if normalised:
        pw = pw / pw.max()

    fx = np.linspace(-fs / 2, fs / 2, data.shape[0] + 1)[:-1]
    return fx, pw
