"""IQ demodulation matching MATLAB preprocess.demodulation.

Converts RF channel data to IQ (complex baseband) via band-pass filtering,
down-mixing, low-pass filtering, and decimation -- using Kaiser-windowed FIR
filters designed the same way as MATLAB's kaiserord + fir1, in contrast to
FastDemodulation's simpler fixed-length low-pass-only design.
"""

import numpy as np
from scipy.signal import kaiserord, firwin, lfilter

from ustb.preprocess._channel_data_view import DemodulatedChannelData
from ustb.tools.power_spectrum import power_spectrum

# MATLAB's kaiserord accepts one ripple deviation per band; a single Kaiser
# window is then designed for the smallest (most restrictive) deviation.
_LOWPASS_DEV = (1e-2, 1e-3)
_BANDPASS_DEV = (1e-3, 1e-2, 1e-3)


def _ripple_db(dev):
    return -20.0 * np.log10(min(dev))


def _design_lowpass(fs, fc, lowpass_frequency_vector):
    f_pass, f_stop = np.asarray(lowpass_frequency_vector) * fc
    width = (f_stop - f_pass) / (fs / 2.0)
    numtaps, beta = kaiserord(_ripple_db(_LOWPASS_DEV), width)
    numtaps = numtaps + 1 if numtaps % 2 == 0 else numtaps
    numtaps = max(numtaps, 3)
    cutoff = (f_pass + f_stop) / 2.0
    return firwin(numtaps, cutoff, window=("kaiser", beta), fs=fs)


def _design_bandpass(fs, fc, bandpass_frequency_vector):
    f_stop1, f_pass1, f_pass2, f_stop2 = np.asarray(bandpass_frequency_vector) * fc
    width = min(f_pass1 - f_stop1, f_stop2 - f_pass2) / (fs / 2.0)
    numtaps, beta = kaiserord(_ripple_db(_BANDPASS_DEV), width)
    numtaps = numtaps + 1 if numtaps % 2 == 0 else numtaps
    numtaps = max(numtaps, 3)
    return firwin(numtaps, [f_pass1, f_pass2], window=("kaiser", beta),
                   pass_zero=False, fs=fs)


def _estimate_center_frequency(data, fs):
    """Estimate the RF center frequency from the -6dB edges of the power spectrum."""
    fx, pw = power_spectrum(data, fs)
    pos = fx >= 0
    fx_pos, pw_pos = fx[pos], pw[pos]
    ic = int(np.argmax(pw_pos))
    dc = pw_pos[ic]

    try:
        bw_lo = np.interp(dc / 2.0, pw_pos[: ic + 1], fx_pos[: ic + 1])
    except Exception:
        bw_lo = fx_pos[ic]
    try:
        upper = pw_pos[ic:]
        upper_fx = fx_pos[ic:]
        bw_up = np.interp(-dc / 2.0, -upper, upper_fx)
    except Exception:
        bw_up = fx_pos[ic]

    return (bw_lo + bw_up) / 2.0


class Demodulation:
    """IQ demodulation for channel data.

    Mirrors MATLAB preprocess.demodulation: band-pass filters, down-mixes
    to baseband, low-pass filters, and decimates.
    """

    def __init__(self):
        self.input = None
        self.modulation_frequency = None
        self.downsample_frequency = None
        self.bandpass_frequency_vector = [0.25, 0.5, 1.5, 1.75]
        self.lowpass_frequency_vector = [0.5, 1.0]

    def go(self):
        """Execute demodulation. Returns a modified channel_data copy."""
        ch_data = self.input
        data = np.asarray(ch_data.data)
        data = data.astype(np.complex128) if np.iscomplexobj(data) else data.astype(np.float64)
        while data.ndim < 4:
            data = data[..., np.newaxis]

        fs = float(ch_data.sampling_frequency)
        t0 = float(ch_data.initial_time)

        fc = float(self.modulation_frequency) if self.modulation_frequency is not None \
            else _estimate_center_frequency(data, fs)
        self.modulation_frequency = fc

        downsample_frequency = self.downsample_frequency \
            if self.downsample_frequency is not None else 2.0 * fc
        Ndown = max(1, int(np.floor(fs / downsample_frequency)))
        downsample_frequency = fs / Ndown
        self.downsample_frequency = downsample_frequency

        bbp = _design_bandpass(fs, fc, self.bandpass_frequency_vector)
        blp = _design_lowpass(fs, fc, self.lowpass_frequency_vector)

        delay0 = (len(bbp) - 1) / 2.0 / fs
        delay1 = (len(blp) - 1) / 2.0 / fs

        filtered = lfilter(bbp, [1.0], data, axis=0)

        t = np.arange(data.shape[0]) / fs
        mixer = np.exp(-1j * 2 * np.pi * fc * t)
        mixed = filtered * mixer[:, np.newaxis, np.newaxis, np.newaxis]

        baseband = lfilter(blp, [1.0], mixed, axis=0)
        iq_data = baseband[::Ndown]

        output = DemodulatedChannelData(ch_data)
        output._data_override = iq_data.astype(np.complex64)
        output._fs_override = downsample_frequency
        output._t0_override = t0 - delay0 - delay1
        output._fc_override = fc
        return output
