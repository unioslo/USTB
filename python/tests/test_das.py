"""Unit tests for the DAS beamformer.

Tests delay calculation, interpolation, and summation logic independently
from file I/O, using synthetic data.
"""

import numpy as np
import pytest
from ustb.midprocess.das import DAS
from ustb.enums import Dimension, Wavefront, Window


class FakePoint:
    def __init__(self, x=0.0, y=0.0, z=0.0, azimuth=0.0, elevation=0.0, distance=0.0):
        self._x = x
        self._y = y
        self._z = z
        self.azimuth = azimuth
        self.elevation = elevation
        self.distance = distance

    @property
    def x(self):
        return self._x

    @property
    def y(self):
        return self._y

    @property
    def z(self):
        return self._z


class FakeWave:
    def __init__(self, wavefront=Wavefront.plane, azimuth=0.0, elevation=0.0,
                 distance=float("inf"), sound_speed=1540.0, delay=0.0):
        self.wavefront = wavefront
        self.source = FakePoint(azimuth=azimuth, elevation=elevation, distance=distance)
        if not np.isinf(distance):
            self.source._x = distance * np.sin(azimuth)
            self.source._z = distance * np.cos(azimuth)
        self.sound_speed = sound_speed
        self.delay = delay


class FakeProbe:
    def __init__(self, N=64, pitch=0.3e-3):
        self._x = (np.arange(N) - (N - 1) / 2) * pitch
        self._y = np.zeros(N)
        self._z = np.zeros(N)

    @property
    def N_elements(self):
        return len(self._x)

    @property
    def x(self):
        return self._x

    @property
    def y(self):
        return self._y

    @property
    def z(self):
        return self._z


class FakeScan:
    def __init__(self, x, z):
        self._x = np.asarray(x, dtype=np.float64).ravel()
        self._z = np.asarray(z, dtype=np.float64).ravel()
        self._y = np.zeros_like(self._x)

    @property
    def x(self):
        return self._x

    @property
    def y(self):
        return self._y

    @property
    def z(self):
        return self._z

    @property
    def reference_distance(self):
        return self._z


class FakeChannelData:
    def __init__(self, data, probe, sequence, fs=40e6, t0=0.0, c=1540.0, fc=0.0):
        self.data = data
        self.probe = probe
        self.sequence = sequence
        self.sampling_frequency = fs
        self.initial_time = t0
        self.sound_speed = c
        self.modulation_frequency = fc

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
        return self.data.shape[3]


def make_simple_test_setup(N_elements=16, N_samples=512, N_waves=1, c=1540.0, fs=40e6):
    """Create a minimal synthetic test setup for DAS testing."""
    probe = FakeProbe(N=N_elements, pitch=0.3e-3)
    scan = FakeScan(x=[0.0], z=[30e-3])
    waves = [FakeWave(wavefront=Wavefront.plane, azimuth=0.0, sound_speed=c) for _ in range(N_waves)]
    data = np.random.randn(N_samples, N_elements, N_waves, 1).astype(np.float32)
    ch_data = FakeChannelData(data, probe, waves, fs=fs, c=c)
    return ch_data, scan


class TestDASConstruction:
    def test_should_create_with_default_properties(self):
        mid = DAS()
        assert mid.dimension == Dimension.both
        assert mid.lens_delay == 0.0
        assert mid.pw_margin == 1e-3
        assert mid.spherical_transmit_delay_model == "hybrid"

    def test_should_accept_dimension_setting(self):
        mid = DAS()
        mid.dimension = Dimension.receive
        assert mid.dimension == Dimension.receive


class TestDASReceiveDelay:
    def test_should_compute_correct_distance_for_on_axis_pixel(self):
        """A pixel at (0, 0, z) should have receive_delay = z/c for center element."""
        mid = DAS()
        ch_data, scan = make_simple_test_setup(N_elements=1)
        mid.channel_data = ch_data
        mid.scan = scan
        mid.receive_apodization.window = Window.none
        mid.transmit_apodization.window = Window.none
        mid.dimension = Dimension.both
        _ = mid.go()

        expected_delay = 30e-3 / 1540.0
        np.testing.assert_allclose(mid.receive_delay[0, 0], expected_delay, rtol=1e-4)


class TestDASTransmitDelay:
    def test_should_be_zero_for_photoacoustic(self):
        mid = DAS()
        probe = FakeProbe(N=4)
        scan = FakeScan(x=[0.0], z=[20e-3])
        waves = [FakeWave(wavefront=Wavefront.photoacoustic, sound_speed=1540.0)]
        data = np.zeros((100, 4, 1, 1), dtype=np.float32)
        ch_data = FakeChannelData(data, probe, waves)
        mid.channel_data = ch_data
        mid.scan = scan
        mid.dimension = Dimension.both
        _ = mid.go()
        np.testing.assert_allclose(mid.transmit_delay[0, 0], 0.0)

    def test_plane_wave_on_axis_should_equal_z_over_c(self):
        mid = DAS()
        probe = FakeProbe(N=4)
        z_val = 20e-3
        scan = FakeScan(x=[0.0], z=[z_val])
        waves = [FakeWave(wavefront=Wavefront.plane, azimuth=0.0, sound_speed=1540.0)]
        data = np.zeros((100, 4, 1, 1), dtype=np.float32)
        ch_data = FakeChannelData(data, probe, waves)
        mid.channel_data = ch_data
        mid.scan = scan
        mid.dimension = Dimension.both
        _ = mid.go()
        expected = z_val / 1540.0
        np.testing.assert_allclose(mid.transmit_delay[0, 0], expected, rtol=1e-5)


class TestDASBeamformOutput:
    def test_should_output_correct_shape_for_dimension_both(self):
        mid = DAS()
        ch_data, scan = make_simple_test_setup(N_elements=8, N_waves=3)
        scan = FakeScan(x=np.zeros(10), z=np.linspace(5e-3, 50e-3, 10))
        mid.channel_data = ch_data
        mid.scan = scan
        mid.dimension = Dimension.both
        b_data = mid.go()
        assert b_data.data.shape == (10, 1, 1, 1)

    def test_should_output_correct_shape_for_dimension_receive(self):
        mid = DAS()
        ch_data, _ = make_simple_test_setup(N_elements=8, N_waves=3)
        scan = FakeScan(x=np.zeros(10), z=np.linspace(5e-3, 50e-3, 10))
        mid.channel_data = ch_data
        mid.scan = scan
        mid.dimension = Dimension.receive
        b_data = mid.go()
        assert b_data.data.shape == (10, 1, 3, 1)

    def test_should_output_correct_shape_for_dimension_transmit(self):
        mid = DAS()
        ch_data, _ = make_simple_test_setup(N_elements=8, N_waves=3)
        scan = FakeScan(x=np.zeros(10), z=np.linspace(5e-3, 50e-3, 10))
        mid.channel_data = ch_data
        mid.scan = scan
        mid.dimension = Dimension.transmit
        b_data = mid.go()
        assert b_data.data.shape == (10, 8, 1, 1)

    def test_should_output_correct_shape_for_dimension_none(self):
        mid = DAS()
        ch_data, _ = make_simple_test_setup(N_elements=8, N_waves=3)
        scan = FakeScan(x=np.zeros(10), z=np.linspace(5e-3, 50e-3, 10))
        mid.channel_data = ch_data
        mid.scan = scan
        mid.dimension = Dimension.none
        b_data = mid.go()
        assert b_data.data.shape == (10, 8, 3, 1)

    def test_should_produce_nonzero_output_for_nonzero_input(self):
        """If input has IQ signal, output should be nonzero."""
        mid = DAS()
        N_elements = 16
        N_samples = 2048
        fs = 40e6
        fc = 5e6
        c = 1540.0
        probe = FakeProbe(N=N_elements, pitch=0.3e-3)
        z_focus = 30e-3
        scan = FakeScan(x=[0.0], z=[z_focus])
        waves = [FakeWave(wavefront=Wavefront.plane, azimuth=0.0, sound_speed=c)]

        # Compute expected round-trip time range for initial_time
        max_delay = z_focus / c + np.sqrt(probe.x[-1]**2 + z_focus**2) / c
        t0 = z_focus / c * 0.9

        data = np.zeros((N_samples, N_elements, 1, 1), dtype=np.complex64)
        for i in range(N_elements):
            rx_dist = np.sqrt(probe.x[i] ** 2 + z_focus ** 2)
            total_delay = z_focus / c + rx_dist / c
            sample = int((total_delay - t0) * fs)
            if 0 <= sample < N_samples:
                data[sample, i, 0, 0] = 1.0 + 0j

        ch_data = FakeChannelData(data, probe, waves, fs=fs, t0=t0, c=c, fc=fc)
        mid.channel_data = ch_data
        mid.scan = scan
        mid.dimension = Dimension.both
        b_data = mid.go()
        assert np.abs(b_data.data).max() > 0, "Beamformed output should be nonzero"

    def test_should_focus_signal_at_correct_depth(self):
        """A point scatterer at z=30mm should produce peak near that depth."""
        mid = DAS()
        N_elements = 32
        N_samples = 4096
        fs = 40e6
        fc = 5e6
        c = 1540.0
        probe = FakeProbe(N=N_elements, pitch=0.3e-3)
        z_target = 30e-3
        t0 = 0.0

        waves = [FakeWave(wavefront=Wavefront.plane, azimuth=0.0, sound_speed=c)]

        # Use a Gaussian pulse (~3 samples wide) for robustness against
        # sub-sample timing differences
        data = np.zeros((N_samples, N_elements, 1, 1), dtype=np.complex64)
        for i in range(N_elements):
            rx_dist = np.sqrt(probe.x[i] ** 2 + z_target ** 2)
            total_delay = z_target / c + rx_dist / c
            center_sample = total_delay * fs
            t = np.arange(N_samples)
            pulse = np.exp(-0.5 * ((t - center_sample) / 2.0) ** 2)
            data[:, i, 0, 0] = pulse.astype(np.complex64)

        ch_data = FakeChannelData(data, probe, waves, fs=fs, t0=t0, c=c, fc=fc)

        z_axis = np.linspace(10e-3, 50e-3, 200)
        scan = FakeScan(x=np.zeros(200), z=z_axis)

        mid.channel_data = ch_data
        mid.scan = scan
        mid.dimension = Dimension.both
        b_data = mid.go()

        envelope = np.abs(b_data.data[:, 0, 0, 0])
        peak_idx = np.argmax(envelope)
        peak_z = z_axis[peak_idx]
        assert abs(peak_z - z_target) < 2e-3, (
            f"Peak at z={peak_z*1e3:.1f}mm, expected {z_target*1e3:.1f}mm"
        )
