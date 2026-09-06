"""Unit tests for USTB Apodization."""

import numpy as np
import pytest
from ustb.apodization import Apodization
from ustb.enums import Window


class FakeProbe:
    """Minimal probe mock for testing."""
    def __init__(self, N, pitch=0.3e-3):
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
    """Minimal scan mock for testing."""
    def __init__(self, x, z):
        self._x = np.asarray(x).ravel()
        self._z = np.asarray(z).ravel()
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


class TestApodizationNone:
    def test_should_return_all_ones_when_window_is_none(self):
        apo = Apodization()
        apo.window = Window.none
        apo.probe = FakeProbe(64)
        apo.focus = FakeScan([0.0], [30e-3])
        result = apo.data
        assert result.shape == (1, 64)
        np.testing.assert_allclose(result, 1.0)

    def test_should_return_correct_shape_for_multiple_pixels(self):
        apo = Apodization()
        apo.window = Window.none
        apo.probe = FakeProbe(32)
        apo.focus = FakeScan(np.zeros(100), np.linspace(5e-3, 50e-3, 100))
        result = apo.data
        assert result.shape == (100, 32)


class TestApodizationHanning:
    def test_should_produce_values_between_zero_and_one(self):
        apo = Apodization()
        apo.window = Window.hanning
        apo.f_number = np.array([1.0, 1.0])
        apo.probe = FakeProbe(64)
        apo.focus = FakeScan(np.zeros(10), np.linspace(10e-3, 50e-3, 10))
        result = apo.data
        assert result.min() >= 0.0
        assert result.max() <= 1.0

    def test_should_be_symmetric_for_centered_pixel(self):
        apo = Apodization()
        apo.window = Window.hanning
        apo.f_number = np.array([1.0, 1.0])
        apo.probe = FakeProbe(64)
        apo.focus = FakeScan([0.0], [30e-3])
        result = apo.data[0, :]
        np.testing.assert_allclose(result, result[::-1], atol=1e-6)


class TestApodizationBoxcar:
    def test_should_return_all_ones(self):
        apo = Apodization()
        apo.window = Window.boxcar
        apo.probe = FakeProbe(64)
        apo.focus = FakeScan([0.0], [30e-3])
        result = apo.data
        np.testing.assert_allclose(result, 1.0)


class TestApodizationTransmit:
    def test_should_return_correct_shape_with_none_window(self):
        apo = Apodization()
        apo.window = Window.none
        apo.sequence = [None] * 10
        apo.focus = FakeScan(np.zeros(50), np.linspace(5e-3, 50e-3, 50))
        result = apo.data
        assert result.shape == (50, 10)
        np.testing.assert_allclose(result, 1.0)
