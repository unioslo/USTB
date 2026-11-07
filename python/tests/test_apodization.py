"""Unit tests for USTB Apodization."""

import numpy as np
import pytest
from pyuff_ustb.objects import LinearScan, SectorScan
from pyuff_ustb.objects.point import Point

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


class FakePoint:
    def __init__(self, x=0.0, y=0.0, z=0.0, azimuth=0.0, elevation=0.0, distance=None):
        self.x, self.y, self.z = x, y, z
        self.azimuth, self.elevation = azimuth, elevation
        self.distance = np.hypot(x, z) if distance is None else distance


class FakeWave:
    def __init__(self, wavefront, source, origin=None):
        self.wavefront = wavefront
        self.source = source
        self.origin = origin if origin is not None else FakePoint()


def plane_wave(azimuth):
    return FakeWave(0, FakePoint(azimuth=azimuth, distance=np.inf))


class TestApodizationPlaneWaveTransmit:
    def test_should_give_each_wave_one_weight_from_its_angle(self):
        """Plane-wave weight is window(|F tan(angle)|), the same for all pixels."""
        f_number = 1.7
        angles = np.array([0.0, np.arctan(0.3 / f_number), np.arctan(0.6 / f_number)])
        apo = Apodization()
        apo.window = Window.tukey50
        apo.f_number = np.array([f_number, f_number])
        apo.sequence = [plane_wave(a) for a in angles]
        apo.focus = FakeScan(np.linspace(-5e-3, 5e-3, 20), np.linspace(5e-3, 40e-3, 20))
        result = apo.data

        # tukey50 at ratio 0.3 (inside the taper): 0.5 * (1 + cos(4*pi*(0.3 - 0.75)))
        expected = [1.0, 0.5 * (1 + np.cos(4 * np.pi * (0.3 - 0.75))), 0.0]
        np.testing.assert_allclose(result, np.tile(expected, (20, 1)), atol=1e-6)

    def test_should_shift_the_window_with_tilt(self):
        apo = Apodization()
        apo.window = Window.boxcar
        apo.f_number = np.array([2.0, 2.0])  # untilted wave: ratio 2*tan(0.4) = 0.85 > 1/2
        apo.tilt = np.array([0.4, 0.0])
        apo.sequence = [plane_wave(0.0), plane_wave(0.4)]
        apo.focus = FakeScan([0.0], [20e-3])
        np.testing.assert_allclose(apo.data, [[0.0, 1.0]])

    def test_should_reject_windows_that_need_a_probe(self):
        apo = Apodization()
        apo.window = Window.sta
        apo.sequence = [plane_wave(0.0)]
        apo.focus = FakeScan([0.0], [20e-3])
        with pytest.raises(ValueError):
            _ = apo.data


class TestApodizationDivergingWaveTransmit:
    def test_should_weight_pixels_by_angle_from_the_virtual_source(self):
        source = FakePoint(x=2e-3, z=-10e-3)
        wave = FakeWave(1, source, origin=FakePoint(x=2e-3))
        apo = Apodization()
        apo.window = Window.boxcar
        apo.f_number = np.array([1.0, 1.0])
        apo.sequence = [wave]
        # On the source axis, and 30 mm off-axis at 20 mm depth (ratio 1 > 1/2)
        apo.focus = FakeScan([2e-3, 32e-3], [20e-3, 20e-3])
        np.testing.assert_allclose(apo.data, [[1.0], [0.0]])


class TestApodizationReceiveWindows:
    def test_should_limit_boxcar_aperture_to_depth_over_f_number(self):
        """At 10 mm depth and F = 2 the active aperture is 5 mm wide."""
        probe = FakeProbe(64, pitch=0.3e-3)
        apo = Apodization()
        apo.window = Window.boxcar
        apo.f_number = np.array([2.0, 2.0])
        apo.probe = probe
        apo.focus = FakeScan([0.0], [10e-3])
        expected = (np.abs(probe.x) <= 2.5e-3).astype(float)
        np.testing.assert_allclose(apo.data[0], expected)

    def test_should_use_matlab_hamming_coefficients(self):
        apo = Apodization()
        apo.window = Window.hamming
        apo.f_number = np.array([1.0, 1.0])
        apo.probe = FakeProbe(1)
        # Element 2.5 mm off-axis at 10 mm depth: ratio = |x/z| = 0.25
        apo.probe._x = np.array([2.5e-3])
        apo.focus = FakeScan([0.0], [10e-3])
        np.testing.assert_allclose(
            apo.data, [[0.53836 + 0.46164 * np.cos(2 * np.pi * 0.25)]], atol=1e-6
        )

    def test_should_be_finite_at_zero_depth(self):
        apo = Apodization()
        apo.window = Window.tukey50
        apo.f_number = np.array([1.7, 1.7])
        apo.probe = FakeProbe(16)
        apo.focus = FakeScan(np.linspace(-2e-3, 2e-3, 5), np.zeros(5))
        assert np.all(np.isfinite(apo.data))


def _sector_scan(azimuth_axis, depth_axis):
    scan = SectorScan()
    scan.azimuth_axis = np.asarray(azimuth_axis, dtype=float)
    scan.depth_axis = np.asarray(depth_axis, dtype=float)
    origin = Point(distance=np.float64(0.0), azimuth=np.float64(0.0), elevation=np.float64(0.0))
    scan.origin = origin
    return scan


def _linear_scan(x_axis, z_axis):
    scan = LinearScan()
    scan.x_axis = np.asarray(x_axis, dtype=float)
    scan.z_axis = np.asarray(z_axis, dtype=float)
    return scan


class TestApodizationScanline:
    def test_should_assign_sector_pixels_by_azimuth_index_including_the_origin(self):
        """Depth-0 pixels all sit at the origin; each still belongs to its own scanline."""
        azimuth = np.linspace(-0.5, 0.5, 5)
        scan = _sector_scan(azimuth, np.linspace(0, 40e-3, 6))
        apo = Apodization()
        apo.window = Window.scanline
        apo.sequence = [None] * 5
        apo.focus = scan
        result = apo.data

        # pyuff_ustb sector scans: azimuth varies fastest
        azimuth_index = np.arange(scan.x.size) % azimuth.size
        np.testing.assert_array_equal(result, np.eye(5)[azimuth_index])

    def test_should_light_mla_scanlines_per_wave_on_a_linear_scan(self):
        scan = _linear_scan(np.linspace(-5e-3, 5e-3, 8), np.linspace(0, 20e-3, 4))
        apo = Apodization()
        apo.window = Window.scanline
        apo.MLA = np.array([2, 1])
        apo.sequence = [None] * 4
        apo.focus = scan
        result = apo.data

        # pyuff_ustb linear scans: z varies fastest
        x_index = np.arange(scan.x.size) // 4
        np.testing.assert_array_equal(result, np.eye(4)[x_index // 2])

    def test_should_share_edge_scanlines_with_mla_overlap(self):
        scan = _linear_scan(np.linspace(-5e-3, 5e-3, 8), [10e-3])
        apo = Apodization()
        apo.window = Window.scanline
        apo.MLA = np.array([4, 1])
        apo.MLA_overlap = np.array([1, 0])
        apo.sequence = [None] * 2
        apo.focus = scan
        result = apo.data

        # MATLAB filter2(ones(2,1)/2, ..., 'same'): each wave's 4 scanlines are
        # smoothed with the next one, so scanline 4 is shared by both waves
        expected = np.array([[1, 1, 1, 0.5, 0, 0, 0, 0], [0, 0, 0, 0.5, 1, 1, 1, 0.5]]).T
        np.testing.assert_allclose(result, expected)

    def test_should_reject_a_wave_count_that_does_not_match_the_scanlines(self):
        apo = Apodization()
        apo.window = Window.scanline
        apo.sequence = [None] * 3
        apo.focus = _linear_scan(np.linspace(-5e-3, 5e-3, 8), [10e-3])
        with pytest.raises(ValueError):
            _ = apo.data
