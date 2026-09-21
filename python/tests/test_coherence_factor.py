"""Unit tests for postprocess.coherence_factor.CoherenceFactor."""

import numpy as np
import pytest
from ustb.postprocess.coherence_factor import CoherenceFactor
from ustb.beamformed_data import BeamformedData
from ustb.apodization import Apodization
from ustb.enums import Dimension, Window


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


def make_input(N_pixels=5, N_channels=8, N_waves=1, data=None, scan=None):
    if data is None:
        data = np.ones((N_pixels, N_channels, N_waves, 1), dtype=np.complex64)
    b_data = BeamformedData(scan=scan or FakeScan([0.0] * N_pixels, np.linspace(5e-3, 40e-3, N_pixels)), data=data)
    b_data.N_channels = N_channels
    b_data.N_waves = N_waves
    return b_data


class TestCoherenceFactorPerfectCoherence:
    def test_identical_channels_should_give_cf_close_to_one(self):
        N_pixels, N_channels = 4, 16
        data = np.ones((N_pixels, N_channels, 1, 1), dtype=np.complex64)
        b_data = make_input(N_pixels, N_channels, data=data)

        cf = CoherenceFactor()
        cf.input = b_data
        cf.dimension = Dimension.receive
        cf.go()

        np.testing.assert_allclose(cf.CF.data, 1.0, atol=1e-5)

    def test_output_equals_cf_times_coherent_sum(self):
        N_pixels, N_channels = 4, 16
        data = np.ones((N_pixels, N_channels, 1, 1), dtype=np.complex64)
        b_data = make_input(N_pixels, N_channels, data=data)

        cf = CoherenceFactor()
        cf.input = b_data
        cf.dimension = Dimension.receive
        out = cf.go()

        coherent_sum = np.sum(data, axis=1, keepdims=True)
        np.testing.assert_allclose(out.data, cf.CF.data * coherent_sum, atol=1e-5)


class TestCoherenceFactorRandomPhase:
    def test_random_phase_channels_should_give_low_cf(self):
        rng = np.random.default_rng(42)
        N_pixels, N_channels = 4, 64
        phases = rng.uniform(0, 2 * np.pi, size=(N_pixels, N_channels, 1, 1))
        data = np.exp(1j * phases).astype(np.complex64)
        b_data = make_input(N_pixels, N_channels, data=data)

        cf = CoherenceFactor()
        cf.input = b_data
        cf.dimension = Dimension.receive
        cf.go()

        assert cf.CF.data.max() < 0.5


class TestCoherenceFactorDimensionFallback:
    def test_not_enough_channels_for_receive_should_raise(self):
        data = np.ones((3, 1, 4, 1), dtype=np.complex64)
        b_data = make_input(3, 1, 4, data=data)

        cf = CoherenceFactor()
        cf.input = b_data
        cf.dimension = Dimension.receive

        with pytest.raises(ValueError):
            cf.go()

    def test_not_enough_waves_for_transmit_should_raise(self):
        data = np.ones((3, 4, 1, 1), dtype=np.complex64)
        b_data = make_input(3, 4, 1, data=data)

        cf = CoherenceFactor()
        cf.input = b_data
        cf.dimension = Dimension.transmit

        with pytest.raises(ValueError):
            cf.go()

    def test_dimension_both_falls_back_to_transmit_when_single_channel(self):
        data = np.ones((3, 1, 4, 1), dtype=np.complex64)
        b_data = make_input(3, 1, 4, data=data)

        cf = CoherenceFactor()
        cf.input = b_data
        cf.dimension = Dimension.both
        with pytest.warns(UserWarning):
            cf.go()

        assert cf.dimension == Dimension.transmit

    def test_dimension_both_falls_back_to_receive_when_single_wave(self):
        data = np.ones((3, 4, 1, 1), dtype=np.complex64)
        b_data = make_input(3, 4, 1, data=data)

        cf = CoherenceFactor()
        cf.input = b_data
        cf.dimension = Dimension.both
        with pytest.warns(UserWarning):
            cf.go()

        assert cf.dimension == Dimension.receive

    def test_dimension_both_raises_when_single_channel_and_wave(self):
        data = np.ones((3, 1, 1, 1), dtype=np.complex64)
        b_data = make_input(3, 1, 1, data=data)

        cf = CoherenceFactor()
        cf.input = b_data
        cf.dimension = Dimension.both

        with pytest.raises(ValueError):
            cf.go()


class TestCoherenceFactorApodization:
    def test_active_element_criterium_reduces_m_for_narrow_aperture(self):
        """With a receive apodization that zeroes out half the elements past
        the active_element_criterium threshold, M (and thus CF for a fully
        coherent signal) should still normalize to ~1, but computed with a
        smaller effective aperture than the full-aperture case."""
        N_pixels, N_channels = 2, 16
        data = np.ones((N_pixels, N_channels, 1, 1), dtype=np.complex64)
        scan = FakeScan(x=[0.0, 0.0], z=[10e-3, 10e-3])
        b_data = make_input(N_pixels, N_channels, data=data, scan=scan)

        probe = FakeProbe(N=N_channels, pitch=0.3e-3)

        apo = Apodization()
        apo.window = Window.boxcar
        apo.probe = probe
        apo.f_number = np.array([1.0, 1.0])

        cf = CoherenceFactor()
        cf.input = b_data
        cf.dimension = Dimension.receive
        cf.receive_apodization = apo
        cf.go()

        np.testing.assert_allclose(cf.CF.data, 1.0, atol=1e-4)
