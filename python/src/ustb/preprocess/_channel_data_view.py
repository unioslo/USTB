"""Shared lightweight channel_data view used by preprocess outputs."""


class DemodulatedChannelData:
    """Wraps a channel_data object, overriding a handful of fields.

    Used as the output of FastDemodulation and Demodulation: everything
    (probe, sequence, sound_speed, pulse, ...) is passed through to the
    original object except data/sampling_frequency/initial_time/
    modulation_frequency, which reflect the demodulated result.
    """

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
        return self._fs_override if self._fs_override is not None else self._original.sampling_frequency

    @property
    def initial_time(self):
        return self._t0_override if self._t0_override is not None else self._original.initial_time

    @property
    def modulation_frequency(self):
        return self._fc_override if self._fc_override is not None else self._original.modulation_frequency

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
