"""Unit tests for preprocess.demodulation.Demodulation."""

import numpy as np
import pytest
from ustb.preprocess.demodulation import Demodulation


class FakePulse:
    def __init__(self, center_frequency):
        self.center_frequency = center_frequency


class FakeChannelData:
    def __init__(self, data, fs, t0=0.0, sound_speed=1540.0, pulse=None,
                 probe="mock_probe", sequence="mock_sequence"):
        self.data = data
        self.sampling_frequency = fs
        self.initial_time = t0
        self.sound_speed = sound_speed
        self.pulse = pulse
        self.probe = probe
        self.sequence = sequence


def make_rf_tone(fs, fc, N_samples=4096, N_channels=2, amplitude=1.0):
    t = np.arange(N_samples) / fs
    tone = amplitude * np.cos(2 * np.pi * fc * t)
    data = np.tile(tone[:, np.newaxis, np.newaxis, np.newaxis], (1, N_channels, 1, 1))
    return data


class TestDemodulationBasic:
    def test_should_produce_complex_iq_output(self):
        fs = 40e6
        fc = 5e6
        data = make_rf_tone(fs, fc)
        ch_data = FakeChannelData(data, fs, pulse=FakePulse(fc))

        demod = Demodulation()
        demod.modulation_frequency = fc
        demod.input = ch_data
        out = demod.go()

        assert np.iscomplexobj(out.data)

    def test_should_downsample_sampling_frequency(self):
        fs = 40e6
        fc = 5e6
        data = make_rf_tone(fs, fc)
        ch_data = FakeChannelData(data, fs, pulse=FakePulse(fc))

        demod = Demodulation()
        demod.modulation_frequency = fc
        demod.downsample_frequency = 4 * fc
        demod.input = ch_data
        out = demod.go()

        assert out.sampling_frequency < fs
        assert out.sampling_frequency == pytest.approx(fs / np.floor(fs / (4 * fc)), rel=1e-6)

    def test_output_data_should_have_fewer_samples_than_input(self):
        fs = 40e6
        fc = 5e6
        data = make_rf_tone(fs, fc, N_samples=4096)
        ch_data = FakeChannelData(data, fs, pulse=FakePulse(fc))

        demod = Demodulation()
        demod.modulation_frequency = fc
        demod.input = ch_data
        out = demod.go()

        assert out.data.shape[0] < data.shape[0]

    def test_should_recover_constant_envelope_of_pure_tone(self):
        """After demodulation, a pure RF tone at fc should collapse to a
        near-constant-magnitude baseband signal (steady-state, away from
        filter transients at the start/end)."""
        fs = 40e6
        fc = 5e6
        data = make_rf_tone(fs, fc, N_samples=8192, amplitude=2.0)
        ch_data = FakeChannelData(data, fs, pulse=FakePulse(fc))

        demod = Demodulation()
        demod.modulation_frequency = fc
        demod.input = ch_data
        out = demod.go()

        envelope = np.abs(out.data[:, 0, 0, 0])
        steady = envelope[len(envelope) // 4: 3 * len(envelope) // 4]
        assert steady.std() / steady.mean() < 0.1

    def test_should_preserve_pass_through_properties(self):
        fs = 40e6
        fc = 5e6
        data = make_rf_tone(fs, fc)
        ch_data = FakeChannelData(data, fs, sound_speed=1480.0, pulse=FakePulse(fc),
                                   probe="my_probe", sequence="my_sequence")

        demod = Demodulation()
        demod.modulation_frequency = fc
        demod.input = ch_data
        out = demod.go()

        assert out.sound_speed == 1480.0
        assert out.probe == "my_probe"
        assert out.sequence == "my_sequence"

    def test_initial_time_should_shift_by_filter_group_delay(self):
        fs = 40e6
        fc = 5e6
        data = make_rf_tone(fs, fc)
        ch_data = FakeChannelData(data, fs, t0=1e-6, pulse=FakePulse(fc))

        demod = Demodulation()
        demod.modulation_frequency = fc
        demod.input = ch_data
        out = demod.go()

        assert out.initial_time < ch_data.initial_time

    def test_should_auto_estimate_modulation_frequency_when_not_set(self):
        fs = 40e6
        fc = 5e6
        data = make_rf_tone(fs, fc, N_samples=8192)
        ch_data = FakeChannelData(data, fs, pulse=FakePulse(fc))

        demod = Demodulation()
        demod.input = ch_data
        demod.go()

        assert abs(demod.modulation_frequency - fc) < 0.5e6

    def test_modulation_frequency_should_stay_positive(self):
        fs = 40e6
        fc = 5e6
        data = make_rf_tone(fs, fc, N_samples=8192)
        ch_data = FakeChannelData(data, fs, pulse=FakePulse(fc))

        demod = Demodulation()
        demod.input = ch_data
        demod.go()

        assert demod.modulation_frequency > 0
