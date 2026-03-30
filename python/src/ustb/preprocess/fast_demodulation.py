"""Fast IQ demodulation matching MATLAB preprocess.fast_demodulation.

Converts RF channel data to IQ (complex baseband) via down-mixing,
low-pass filtering, and decimation.
"""

import numpy as np
from scipy.signal import firwin, filtfilt, decimate


class FastDemodulation:
    """Fast IQ demodulation for channel data.

    Mirrors MATLAB preprocess.fast_demodulation: mixes to baseband,
    low-pass filters, and optionally decimates.
    """

    def __init__(self):
        self.input = None
        self.modulation_frequency = None
        self.downsample_frequency = None
        self.lowpass_frequency_vector = [0.5, 1.0]

    def go(self):
        """Execute demodulation. Returns a modified channel_data copy."""
        from pyuff_ustb.objects.uff import Uff
        from copy import copy

        ch_data = self.input
        data = np.array(ch_data.data, dtype=np.float64)
        if data.ndim == 2:
            data = data[:, :, np.newaxis, np.newaxis]
        elif data.ndim == 3:
            data = data[:, :, :, np.newaxis]

        fs = float(ch_data.sampling_frequency)
        t0 = float(ch_data.initial_time)

        if self.modulation_frequency is None:
            if ch_data.pulse is not None and ch_data.pulse.center_frequency is not None:
                fc = float(ch_data.pulse.center_frequency)
            else:
                fc = float(ch_data.modulation_frequency)
        else:
            fc = float(self.modulation_frequency)

        N_samples = data.shape[0]
        t = t0 + np.arange(N_samples) / fs

        # Down-mix to baseband
        mixer = np.exp(-1j * 2 * np.pi * fc * t)
        iq_data = data * mixer[:, np.newaxis, np.newaxis, np.newaxis]

        # Low-pass filter
        cutoff = fc * self.lowpass_frequency_vector[0]
        numtaps = min(65, N_samples // 3 * 2 - 1)
        if numtaps < 3:
            numtaps = 3
        if numtaps % 2 == 0:
            numtaps += 1
        b = firwin(numtaps, cutoff, fs=fs)
        for ch in range(iq_data.shape[1]):
            for w in range(iq_data.shape[2]):
                for f in range(iq_data.shape[3]):
                    iq_data[:, ch, w, f] = filtfilt(b, 1, iq_data[:, ch, w, f])

        # Decimation
        if self.downsample_frequency is not None:
            dec_factor = max(1, int(np.floor(fs / self.downsample_frequency)))
        else:
            dec_factor = max(1, int(np.floor(fs / (4 * fc))))

        if dec_factor > 1:
            iq_data = iq_data[::dec_factor, :, :, :]
            new_fs = fs / dec_factor
            new_t0 = t0
        else:
            new_fs = fs
            new_t0 = t0

        # Create output channel_data with updated properties
        output = _copy_channel_data(ch_data)
        output._data_override = iq_data.astype(np.complex64)
        output._fs_override = new_fs
        output._t0_override = new_t0
        output._fc_override = fc
        return output


class _DemodulatedChannelData:
    """Lightweight wrapper around channel data with overridden fields."""

    def __init__(self, original):
        self._original = original
        self._data_override = None
        self._fs_override = None
        self._t0_override = None
        self._fc_override = None

    @property
    def data(self):
        if self._data_override is not None:
            return self._data_override
        return self._original.data

    @property
    def sampling_frequency(self):
        return self._fs_override or self._original.sampling_frequency

    @property
    def initial_time(self):
        return self._t0_override if self._t0_override is not None else self._original.initial_time

    @property
    def modulation_frequency(self):
        return self._fc_override or self._original.modulation_frequency

    @property
    def sound_speed(self):
        return self._original.sound_speed

    @property
    def sequence(self):
        return self._original.sequence

    @property
    def probe(self):
        return self._original.probe

    @property
    def pulse(self):
        return self._original.pulse

    @property
    def N_samples(self):
        return self.data.shape[0]

    @property
    def N_channels(self):
        return self.data.shape[1]

    @property
    def N_waves(self):
        return self.data.shape[2]

    @property
    def N_frames(self):
        return self.data.shape[3] if self.data.ndim > 3 else 1


def _copy_channel_data(ch_data):
    return _DemodulatedChannelData(ch_data)
