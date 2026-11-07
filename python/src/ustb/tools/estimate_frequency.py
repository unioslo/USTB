"""Center frequency and bandwidth estimate matching MATLAB tools.estimate_frequency."""

import numpy as np
from scipy.signal import lfilter

from ustb.tools.power_spectrum import power_spectrum


def estimate_frequency(time, data):
    """Estimate the center frequency and -6 dB bandwidth of ``data``.

    Mirrors MATLAB tools.estimate_frequency(time, data): the averaged power
    spectrum is smoothed with a 26-point moving average, and the center
    frequency is the middle of the -6 dB band around the positive-frequency
    peak.

    Returns:
        (fc, bw): center frequency and bandwidth [Hz].
    """
    fs = 1.0 / np.mean(np.diff(np.asarray(time, dtype=np.float64).ravel()))
    fx, pw = power_spectrum(data, fs)
    fpw = lfilter(np.ones(26) / 26, 1, pw)
    fpw = np.concatenate([fpw[12:], np.zeros(12)])
    weighted = fpw * (fx > 0)
    ic = int(np.argmax(weighted))
    dc, fc = weighted[ic], fx[ic]
    bw_up = np.min(fx[(fx > fc) & (fpw < dc / 2)])
    bw_down = np.max(fx[(fx < fc) & (fpw < dc / 2)])
    fc = (bw_up + bw_down) / 2
    return fc, 2 * (bw_up - fc)
