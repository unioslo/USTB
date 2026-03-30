"""Unit tests for BeamformedData container."""

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
