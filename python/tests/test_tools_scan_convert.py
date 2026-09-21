"""Unit tests for ustb.tools.scan_convert."""

import numpy as np
from ustb.tools import scan_convert


class TestScanConvert:
    def test_should_return_expected_output_shape(self):
        ranges = np.linspace(10e-3, 50e-3, 40)
        thetas = np.linspace(-np.pi / 4, np.pi / 4, 20)
        img = np.random.rand(len(ranges), len(thetas))

        out, xs, zs = scan_convert(img, thetas, ranges, size_x=64, size_z=32)

        assert out.shape == (32, 64)
        assert xs.shape == (64,)
        assert zs.shape == (32,)

    def test_axes_should_span_the_polar_footprint(self):
        ranges = np.linspace(10e-3, 50e-3, 40)
        thetas = np.linspace(-np.pi / 4, np.pi / 4, 20)
        img = np.ones((len(ranges), len(thetas)))

        _, xs, zs = scan_convert(img, thetas, ranges, size_x=64, size_z=32)

        theta_grid, range_grid = np.meshgrid(thetas, ranges)
        z = range_grid * np.cos(theta_grid)
        x = range_grid * np.sin(theta_grid)

        np.testing.assert_allclose(xs.min(), x.min())
        np.testing.assert_allclose(xs.max(), x.max())
        np.testing.assert_allclose(zs.min(), z.min())
        np.testing.assert_allclose(zs.max(), z.max())

    def test_constant_image_should_stay_constant_inside_footprint(self):
        """A uniform polar image, once resampled, should still equal that
        constant everywhere well inside the fan (away from the -inf-filled
        edges outside the polar footprint)."""
        ranges = np.linspace(10e-3, 50e-3, 60)
        thetas = np.linspace(-np.pi / 6, np.pi / 6, 30)
        img = np.full((len(ranges), len(thetas)), 3.0)

        out, xs, zs = scan_convert(img, thetas, ranges, size_x=50, size_z=50)

        center = out[out.shape[0] // 2, out.shape[1] // 2]
        assert np.isclose(center, 3.0, atol=1e-6)

    def test_pixels_outside_footprint_should_be_filled_with_negative_infinity(self):
        ranges = np.linspace(10e-3, 50e-3, 40)
        thetas = np.linspace(-np.pi / 8, np.pi / 8, 20)
        img = np.ones((len(ranges), len(thetas)))

        out, xs, zs = scan_convert(img, thetas, ranges, size_x=64, size_z=64)

        # Top corners of the output grid lie outside the narrow polar fan.
        assert out[0, 0] == -np.inf
