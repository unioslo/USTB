"""Unit tests for the SVD clutter filters and autocorrelation Doppler (no datasets needed).

The MATLAB comparison is in test_flow_vs_matlab.py.
"""

import numpy as np
import pytest

from ustb._svd import resolve_cutoff
from ustb.beamformed_data import BeamformedData
from ustb import postprocess, preprocess


class _Pulse:
    center_frequency = 5e6


class _ChannelData:
    sound_speed = 1540.0
    pulse = _Pulse()


def _linear_scan(N_x, N_z, dz=50e-6):
    from pyuff_ustb.objects import LinearScan
    scan = LinearScan()
    scan.__dict__["x_axis"] = np.linspace(-2e-3, 2e-3, N_x)
    scan.__dict__["z_axis"] = 10e-3 + dz * np.arange(N_z)
    return scan


class TestCutoff:
    @pytest.mark.parametrize("cutoff, expected", [
        (3, [2, 3, 4, 5]),          # scalar: 3..N (1-based) -> 0-based
        ([2, 4], [1, 2, 3]),        # two values: range
        ([2, 4, 6], [1, 3, 5]),     # vector: exactly those
        ([3, 9], [2, 3, 4, 5]),     # end beyond N_frames: clipped
    ])
    def test_should_follow_the_matlab_rules(self, cutoff, expected):
        np.testing.assert_array_equal(resolve_cutoff(cutoff, 6), expected)

    @pytest.mark.parametrize("cutoff", [1, [1, 4], [1, 2, 3, 4, 5, 6]])
    def test_should_leave_data_unfiltered_when_starting_at_one(self, cutoff):
        assert resolve_cutoff(cutoff, 6) is None

    def test_should_reject_a_cutoff_that_keeps_nothing(self):
        # MATLAB silently returns zeros here
        with pytest.raises(ValueError):
            resolve_cutoff(8, 6)


class TestSVDFilter:
    def test_should_remove_a_static_component(self):
        rng = np.random.default_rng(0)
        static = rng.standard_normal((50, 1))
        moving = 0.01 * rng.standard_normal((50, 20))
        b_data = BeamformedData(scan=None, data=(100 * static + moving)[:, None, None, :])
        svd = postprocess.SVDFilter()
        svd.input, svd.cutoff = b_data, 2
        out = svd.go().data[:, 0, 0, :]
        # The rank-1 static part is gone; what is left is (almost) the moving part
        assert np.linalg.norm(out) < 2 * np.linalg.norm(moving)
        assert np.abs(out.mean(axis=1)).max() < 0.05

    def test_should_not_modify_cutoff(self):
        svd = postprocess.SVDFilter()
        svd.input = BeamformedData(scan=None, data=np.ones((5, 1, 1, 4)))
        svd.cutoff = 2
        svd.go()
        assert svd.cutoff == 2

    def test_should_filter_across_frames_of_channel_data(self):
        """The frame axis is axis 3 even with one wave (MATLAB would pick another axis)."""
        rng = np.random.default_rng(1)

        class Raw:
            data = rng.standard_normal((30, 4, 1, 6))
            probe = sequence = pulse = None
            sound_speed, sampling_frequency, initial_time, modulation_frequency = 1540, 1, 0, 0

        svd = preprocess.SVDFilter()
        svd.input, svd.cutoff = Raw(), 2
        out = svd.go().data
        X = Raw.data.reshape(-1, 6)
        U = np.linalg.svd(X.T @ X)[0]
        expected = (X @ U[:, 1:] @ U[:, 1:].T).reshape(Raw.data.shape)
        np.testing.assert_allclose(out, expected, atol=1e-10)


class TestAutocorrelation:
    @pytest.mark.parametrize("cls", ["AutocorrelationDisplacementEstimation",
                                     "ModifiedAutocorrelationDisplacementEstimation"])
    def test_should_measure_a_known_phase_shift(self, cls):
        """X_{t+1} = X_t exp(i dphi) gives d = -c * dphi / (2 pi) / (2 fc) (MATLAB sign)."""
        N_x, N_z, N_frames, dphi = 6, 30, 10, 0.4
        scan = _linear_scan(N_x, N_z)
        fc, c = 5e6, 1540.0
        # Axial phase at fc, so the modified estimator recovers fc as well
        fs = c / 50e-6 / 2
        rng = np.random.default_rng(2)
        speckle = rng.standard_normal(N_x * N_z) + 1j * rng.standard_normal(N_x * N_z)
        axial = np.exp(2j * np.pi * fc / fs * np.tile(np.arange(N_z), N_x))  # z fastest
        frames = np.exp(1j * dphi * np.arange(N_frames))
        b_data = BeamformedData(scan=scan, data=(np.abs(speckle) * axial)[:, None, None, None]
                                * frames[None, None, None, :])
        estimator = getattr(postprocess, cls)()
        estimator.input, estimator.channel_data = b_data, _ChannelData()
        out = estimator.go().data
        assert out.shape == (N_x * N_z, 1, 1, N_frames - estimator.packet_size + 1)
        inside = out[:, 0, 0, 0] != 0
        assert inside.sum() == (N_z - estimator.z_gate) * (N_x - estimator.x_gate + 1)
        np.testing.assert_allclose(out[inside], -c * dphi / (2 * np.pi) / (2 * fc), rtol=1e-6)

    def test_should_require_more_frames_than_the_packet(self):
        ac = postprocess.AutocorrelationDisplacementEstimation()
        ac.input = BeamformedData(scan=_linear_scan(4, 10), data=np.ones((40, 1, 1, 6)))
        ac.channel_data = _ChannelData()
        with pytest.raises(ValueError):
            ac.go()
