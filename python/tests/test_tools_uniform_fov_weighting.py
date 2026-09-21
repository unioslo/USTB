"""Unit tests for ustb.tools.uniform_fov_weighting."""

import numpy as np
from ustb.tools import uniform_fov_weighting
from ustb.apodization import Apodization
from ustb.enums import Window


class FakeProbe:
    def __init__(self, N=8, pitch=0.3e-3):
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


class FakeLinearScan:
    """Minimal linear-scan mock using pyuff_ustb's own pixel flatten order:
    meshgrid(x_axis, z_axis, indexing='ij'), i.e. x varies slowest."""

    def __init__(self, x_axis, z_axis):
        self.x_axis = np.asarray(x_axis, dtype=np.float64)
        self.z_axis = np.asarray(z_axis, dtype=np.float64)
        X, Z = np.meshgrid(self.x_axis, self.z_axis, indexing="ij")
        self._x = X.ravel()
        self._z = Z.ravel()
        self._y = np.zeros_like(self._x)

    @property
    def N_x_axis(self):
        return len(self.x_axis)

    @property
    def N_z_axis(self):
        return len(self.z_axis)

    @property
    def x(self):
        return self._x

    @property
    def y(self):
        return self._y

    @property
    def z(self):
        return self._z


class FakeChannelData:
    def __init__(self, probe, sequence):
        self.probe = probe
        self.sequence = sequence


class FakeMid:
    def __init__(self, channel_data, scan):
        self.channel_data = channel_data
        self.scan = scan
        self.receive_apodization = Apodization()
        self.receive_apodization.window = Window.none
        self.transmit_apodization = Apodization()
        self.transmit_apodization.window = Window.none


class TestUniformFovWeighting:
    def test_should_return_correctly_shaped_arrays(self):
        N_elements, N_waves = 8, 3
        x_axis = np.linspace(-10e-3, 10e-3, 5)
        z_axis = np.linspace(5e-3, 40e-3, 7)

        probe = FakeProbe(N=N_elements)
        sequence = [None] * N_waves
        scan = FakeLinearScan(x_axis, z_axis)
        mid = FakeMid(FakeChannelData(probe, sequence), scan)

        apod, array_gain, geo_spreading = uniform_fov_weighting(mid)

        assert apod.shape == (5, 7)
        assert array_gain.shape == (5, 7)
        assert geo_spreading.shape == (5, 7)

    def test_array_gain_should_equal_elements_times_waves_with_no_apodization(self):
        N_elements, N_waves = 4, 2
        x_axis = np.linspace(-5e-3, 5e-3, 3)
        z_axis = np.linspace(10e-3, 30e-3, 4)

        probe = FakeProbe(N=N_elements)
        sequence = [None] * N_waves
        scan = FakeLinearScan(x_axis, z_axis)
        mid = FakeMid(FakeChannelData(probe, sequence), scan)

        _, array_gain, _ = uniform_fov_weighting(mid)

        np.testing.assert_allclose(array_gain, N_elements * N_waves)

    def test_geo_spreading_should_match_squared_depth_axis(self):
        N_elements, N_waves = 4, 2
        x_axis = np.linspace(-5e-3, 5e-3, 3)
        z_axis = np.linspace(10e-3, 30e-3, 4)

        probe = FakeProbe(N=N_elements)
        sequence = [None] * N_waves
        scan = FakeLinearScan(x_axis, z_axis)
        mid = FakeMid(FakeChannelData(probe, sequence), scan)

        _, _, geo_spreading = uniform_fov_weighting(mid)

        for row in range(geo_spreading.shape[0]):
            np.testing.assert_allclose(geo_spreading[row, :], z_axis**2)

    def test_apod_should_equal_geo_spreading_over_array_gain(self):
        N_elements, N_waves = 4, 2
        x_axis = np.linspace(-5e-3, 5e-3, 3)
        z_axis = np.linspace(10e-3, 30e-3, 4)

        probe = FakeProbe(N=N_elements)
        sequence = [None] * N_waves
        scan = FakeLinearScan(x_axis, z_axis)
        mid = FakeMid(FakeChannelData(probe, sequence), scan)

        apod, array_gain, geo_spreading = uniform_fov_weighting(mid)

        np.testing.assert_allclose(apod, geo_spreading / array_gain)
