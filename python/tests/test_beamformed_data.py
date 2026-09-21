"""Unit tests for BeamformedData container."""

import os

import numpy as np
import pytest
from ustb.beamformed_data import BeamformedData


class TestBeamformedData:
    def test_should_store_data_and_scan(self):
        data = np.zeros((100, 1, 1, 1), dtype=np.complex64)
        b_data = BeamformedData(scan="mock_scan", data=data)
        assert b_data.scan == "mock_scan"
        assert b_data.data is data

    def test_should_return_correct_n_pixels(self):
        data = np.zeros((256, 1, 1, 1), dtype=np.complex64)
        b_data = BeamformedData(data=data)
        assert b_data.N_pixels == 256

    def test_should_return_zero_n_pixels_when_no_data(self):
        b_data = BeamformedData()
        assert b_data.N_pixels == 0


class FakeLinearScan:
    """Mock using pyuff_ustb's flatten order: meshgrid(x_axis, z_axis, 'ij')."""

    def __init__(self, x_axis, z_axis):
        self.x_axis = np.asarray(x_axis, dtype=np.float64)
        self.z_axis = np.asarray(z_axis, dtype=np.float64)

    @property
    def N_x_axis(self):
        return len(self.x_axis)

    @property
    def N_z_axis(self):
        return len(self.z_axis)


class TestGetImage:
    def test_should_reshape_to_scan_grid(self):
        scan = FakeLinearScan(x_axis=np.linspace(-1, 1, 4), z_axis=np.linspace(0, 1, 5))
        data = np.arange(20, dtype=np.complex64).reshape(20, 1, 1, 1)
        b_data = BeamformedData(scan=scan, data=data)

        img = b_data.get_image(compression="abs")

        assert img.shape == (4, 5, 1, 1)
        np.testing.assert_allclose(img[:, :, 0, 0], np.abs(data[:, 0, 0, 0]).reshape(4, 5))

    def test_log_compression_should_peak_at_zero_db(self):
        scan = FakeLinearScan(x_axis=np.linspace(-1, 1, 2), z_axis=np.linspace(0, 1, 2))
        data = np.array([1.0, 2.0, 3.0, 10.0], dtype=np.complex64).reshape(4, 1, 1, 1)
        b_data = BeamformedData(scan=scan, data=data)

        img = b_data.get_image(compression="log")

        assert img.max() == pytest.approx(0.0, abs=1e-6)

    def test_sqrt_compression(self):
        scan = FakeLinearScan(x_axis=[0.0], z_axis=[0.0, 1.0, 2.0])
        data = np.array([4.0, 9.0, 16.0], dtype=np.complex64).reshape(3, 1, 1, 1)
        b_data = BeamformedData(scan=scan, data=data)

        img = b_data.get_image(compression="sqrt")

        np.testing.assert_allclose(img[:, :, 0, 0].ravel(), [2.0, 3.0, 4.0])

    def test_should_preserve_multiple_frames(self):
        scan = FakeLinearScan(x_axis=[0.0], z_axis=[0.0, 1.0])
        data = np.arange(6, dtype=np.complex64).reshape(2, 1, 1, 3)
        b_data = BeamformedData(scan=scan, data=data)

        img = b_data.get_image(compression="none")

        assert img.shape == (1, 2, 1, 3)

    def test_should_raise_for_unsupported_compression(self):
        scan = FakeLinearScan(x_axis=[0.0], z_axis=[0.0])
        data = np.ones((1, 1, 1, 1), dtype=np.complex64)
        b_data = BeamformedData(scan=scan, data=data)

        with pytest.raises(ValueError):
            b_data.get_image(compression="bogus")

    def test_should_raise_when_channel_dimension_not_reduced(self):
        scan = FakeLinearScan(x_axis=[0.0], z_axis=[0.0])
        data = np.ones((1, 4, 1, 1), dtype=np.complex64)
        b_data = BeamformedData(scan=scan, data=data)

        with pytest.raises(ValueError):
            b_data.get_image()

    def test_should_raise_when_pixel_count_mismatches_scan(self):
        scan = FakeLinearScan(x_axis=[0.0, 1.0], z_axis=[0.0, 1.0])
        data = np.ones((3, 1, 1, 1), dtype=np.complex64)
        b_data = BeamformedData(scan=scan, data=data)

        with pytest.raises(ValueError):
            b_data.get_image()


class TestSaveAsGif:
    def test_should_write_gif_file(self, tmp_path):
        scan = FakeLinearScan(x_axis=np.linspace(-1, 1, 6), z_axis=np.linspace(0, 1, 8))
        N_frames = 3
        data = (np.random.rand(48, 1, 1, N_frames) + 1j * np.random.rand(48, 1, 1, N_frames)).astype(np.complex64)
        b_data = BeamformedData(scan=scan, data=data)

        out_path = tmp_path / "movie.gif"
        result = b_data.save_as_gif(str(out_path))

        assert result == str(out_path)
        assert out_path.exists()
        assert out_path.stat().st_size > 0

    def test_should_raise_for_multi_channel_stack(self, tmp_path):
        scan = FakeLinearScan(x_axis=[0.0], z_axis=[0.0])
        data = np.ones((1, 1, 2, 3), dtype=np.complex64)
        b_data = BeamformedData(scan=scan, data=data)

        with pytest.raises(ValueError):
            b_data.save_as_gif(str(tmp_path / "movie.gif"))
