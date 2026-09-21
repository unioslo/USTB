"""Unit tests for postprocess.coherent_compounding and incoherent_compounding."""

import numpy as np
import pytest
from ustb.postprocess.coherent_compounding import CoherentCompounding
from ustb.postprocess.incoherent_compounding import IncoherentCompounding
from ustb.beamformed_data import BeamformedData
from ustb.enums import Dimension


def make_input(N_pixels=5, N_channels=1, N_waves=4, N_frames=1, seed=0):
    rng = np.random.default_rng(seed)
    data = (rng.standard_normal((N_pixels, N_channels, N_waves, N_frames))
            + 1j * rng.standard_normal((N_pixels, N_channels, N_waves, N_frames))).astype(np.complex64)
    return BeamformedData(scan="mock_scan", data=data)


class TestCoherentCompounding:
    def test_dimension_both_sums_channels_and_waves(self):
        b_data = make_input(N_channels=3, N_waves=4)
        cc = CoherentCompounding()
        cc.input = b_data
        cc.dimension = Dimension.both

        out = cc.go()

        expected = np.sum(b_data.data, axis=(1, 2), keepdims=True)
        np.testing.assert_allclose(out.data, expected)
        assert out.scan == "mock_scan"

    def test_dimension_transmit_sums_only_waves(self):
        b_data = make_input(N_channels=1, N_waves=6)
        cc = CoherentCompounding()
        cc.input = b_data
        cc.dimension = Dimension.transmit

        out = cc.go()

        expected = np.sum(b_data.data, axis=2, keepdims=True)
        np.testing.assert_allclose(out.data, expected)

    def test_preserves_phase_unlike_incoherent(self):
        """Two waves 180 degrees out of phase should cancel coherently."""
        N_pixels = 3
        data = np.zeros((N_pixels, 1, 2, 1), dtype=np.complex64)
        data[:, 0, 0, 0] = 1.0
        data[:, 0, 1, 0] = -1.0
        b_data = BeamformedData(scan=None, data=data)

        cc = CoherentCompounding()
        cc.input = b_data
        cc.dimension = Dimension.both
        out = cc.go()

        np.testing.assert_allclose(out.data, 0.0, atol=1e-6)

    def test_window_size_moving_sum_shrinks_wave_axis(self):
        N_waves = 6
        window_size = 3
        b_data = make_input(N_channels=1, N_waves=N_waves)
        cc = CoherentCompounding()
        cc.input = b_data
        cc.dimension = Dimension.transmit
        cc.window_size = window_size

        out = cc.go()

        assert out.data.shape[3] == N_waves - window_size + 1

    def test_window_size_larger_than_n_waves_should_raise(self):
        b_data = make_input(N_channels=1, N_waves=3)
        cc = CoherentCompounding()
        cc.input = b_data
        cc.dimension = Dimension.transmit
        cc.window_size = 10

        with pytest.raises(ValueError):
            cc.go()

    def test_window_size_moving_sum_matches_manual_computation(self):
        N_waves = 5
        window_size = 2
        data = np.arange(N_waves, dtype=np.complex64).reshape(1, 1, N_waves, 1)
        b_data = BeamformedData(scan=None, data=data)

        cc = CoherentCompounding()
        cc.input = b_data
        cc.dimension = Dimension.transmit
        cc.window_size = window_size
        out = cc.go()

        expected = np.array([0 + 1, 1 + 2, 2 + 3, 3 + 4], dtype=np.complex64)
        np.testing.assert_allclose(out.data[0, 0, 0, :], expected)


class TestIncoherentCompounding:
    def test_dimension_both_sums_magnitude(self):
        b_data = make_input(N_channels=3, N_waves=4)
        ic = IncoherentCompounding()
        ic.input = b_data
        ic.dimension = Dimension.both

        out = ic.go()

        expected = np.sum(np.abs(b_data.data), axis=(1, 2), keepdims=True)
        np.testing.assert_allclose(out.data, expected)

    def test_out_of_phase_waves_do_not_cancel(self):
        """Unlike coherent compounding, magnitude summation never cancels."""
        N_pixels = 3
        data = np.zeros((N_pixels, 1, 2, 1), dtype=np.complex64)
        data[:, 0, 0, 0] = 1.0
        data[:, 0, 1, 0] = -1.0
        b_data = BeamformedData(scan=None, data=data)

        ic = IncoherentCompounding()
        ic.input = b_data
        ic.dimension = Dimension.both
        out = ic.go()

        np.testing.assert_allclose(out.data, 2.0)

    def test_output_dtype_is_real(self):
        b_data = make_input(N_channels=2, N_waves=2)
        ic = IncoherentCompounding()
        ic.input = b_data
        ic.dimension = Dimension.both

        out = ic.go()

        assert not np.iscomplexobj(out.data)

    def test_unsupported_dimension_should_raise(self):
        b_data = make_input()
        ic = IncoherentCompounding()
        ic.input = b_data
        ic.dimension = Dimension.none

        with pytest.raises(ValueError):
            ic.go()
