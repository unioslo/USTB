"""Unit tests for GCF, PCF, Capon MV, DMAS and SLSC (no datasets needed).

The MATLAB comparison of GCF, PCF, Capon and DMAS is in
test_processes_vs_matlab.py. SLSC cannot be compared with MATLAB (its
correlations come from a MEX without source), so its definition is checked
here on signals with a known coherence.
"""

import numpy as np
import pytest

from ustb.beamformed_data import BeamformedData
from ustb.enums import Dimension, Window
from ustb import postprocess
from ustb.postprocess.short_lag_spatial_coherence import _kernel_sum, slsc_lags


class _Pulse:
    center_frequency = 5e6


class _ChannelData:
    sound_speed = 1540.0
    pulse = _Pulse()
    probe = None


def _linear_scan(N_x, N_z, dz=15e-6):
    from pyuff_ustb.objects import LinearScan
    scan = LinearScan()
    scan.__dict__["x_axis"] = np.linspace(-2e-3, 2e-3, N_x)
    scan.__dict__["z_axis"] = 10e-3 + dz * np.arange(N_z)
    return scan


def _beamformed(N_x=4, N_z=60, N_channels=8, N_waves=3, seed=0):
    rng = np.random.default_rng(seed)
    scan = _linear_scan(N_x, N_z)
    shape = (N_x * N_z, N_channels, N_waves, 1)
    data = (rng.standard_normal(shape) + 1j * rng.standard_normal(shape)).astype(np.complex64)
    return BeamformedData(scan=scan, data=data)


class TestKernelSum:
    def test_should_sum_a_centered_window_truncated_at_the_edges(self):
        values = np.arange(10, dtype=float)[:, None]
        result = _kernel_sum(values, 5)[:, 0]
        expected = [values[max(0, k - 2):k + 3, 0].sum() for k in range(10)]
        np.testing.assert_allclose(result, expected)


class TestSLSCDefinition:
    def test_should_give_one_at_every_lag_for_identical_signals(self):
        common = np.random.default_rng(1).standard_normal(200)
        signals = np.tile(common[:, None], (1, 10))
        values = slsc_lags(signals, K=9, maxM=4)
        np.testing.assert_allclose(values, 1.0, atol=1e-12)

    def test_should_give_near_zero_for_independent_noise(self):
        signals = np.random.default_rng(2).standard_normal((4000, 32))
        values = slsc_lags(signals, K=401, maxM=5)
        assert np.abs(values[200:-200]).max() < 0.1

    def test_should_match_the_coherence_of_a_partly_common_signal(self):
        """s_i = a*common + b*noise_i has expected correlation a^2 / (a^2 + b^2)."""
        rng = np.random.default_rng(3)
        a, b = 1.0, 0.5
        signals = a * rng.standard_normal((20000, 1)) + b * rng.standard_normal((20000, 16))
        values = slsc_lags(signals, K=4001, maxM=3)
        np.testing.assert_allclose(values[5000:-5000], a ** 2 / (a ** 2 + b ** 2), atol=0.03)

    def test_should_count_lags_over_active_elements_only(self):
        """A dead (all-zero) element is skipped, so its neighbours become lag 1."""
        b_data = _beamformed(N_x=1, N_z=80, N_channels=6, N_waves=1)
        common = np.random.default_rng(4).standard_normal(80)
        data = np.tile(common[:, None], (1, 6)).astype(np.complex64)
        data[:, 2] = 0
        b_data.data = data[:, :, None, None]
        slsc = postprocess.ShortLagSpatialCoherence()
        slsc.input, slsc.channel_data = b_data, _ChannelData()
        slsc.K_in_lambda = 1
        slsc.maxM = 2
        slsc.go()
        np.testing.assert_allclose(slsc.slsc_values, 1.0, atol=1e-6)


class TestSLSCProcess:
    def test_should_default_to_receive_and_thirty_percent_of_the_aperture(self):
        slsc = postprocess.ShortLagSpatialCoherence()
        slsc.input, slsc.channel_data = _beamformed(N_channels=10, N_waves=1), _ChannelData()
        slsc.K_in_lambda = 1
        out = slsc.go()
        assert slsc.dimension == Dimension.receive
        assert slsc.maxM == 3
        assert out.data.shape == (4 * 60, 1, 1, 1)
        assert np.isclose(out.data.max(), 1.0)

    def test_should_reject_apodization(self):
        from ustb.apodization import Apodization
        slsc = postprocess.ShortLagSpatialCoherence()
        slsc.input, slsc.channel_data = _beamformed(), _ChannelData()
        slsc.K_in_lambda = 1
        slsc.receive_apodization = Apodization()
        slsc.receive_apodization.window = Window.hanning
        with pytest.raises(ValueError):
            slsc.go()

    def test_should_reject_both_dimensions(self):
        slsc = postprocess.ShortLagSpatialCoherence()
        slsc.input, slsc.channel_data = _beamformed(), _ChannelData()
        slsc.K_in_lambda = 1
        slsc.dimension = Dimension.both
        with pytest.raises(ValueError):
            slsc.go()


def _run(process_name, dimension):
    b_data = _beamformed()
    process = getattr(postprocess, process_name)()
    process.input = b_data
    process.dimension = dimension
    if process_name == "GeneralizedCoherenceFactor":
        process.M0 = 2  # at most N - 1 for the 3 waves
    if process_name == "CaponMinimumVariance":
        process.scan, process.channel_data = b_data.scan, _ChannelData()
        process.L_elements, process.K_in_lambda, process.regCoef = 3, 1, 1 / 100
    if process_name == "DelayMultiplyAndSum":
        process.channel_data = _ChannelData()
        process.filter_freqs = [7.5e6, 8.75e6, 12.5e6, 13.75e6]
    if process_name == "ShortLagSpatialCoherence":
        process.channel_data = _ChannelData()
        process.K_in_lambda = 1
    return b_data, process.go()


EXPECTED_SHAPE = {
    Dimension.receive: lambda P, C, W: (P, 1, W, 1),
    Dimension.transmit: lambda P, C, W: (P, C, 1, 1),
    Dimension.both: lambda P, C, W: (P, 1, 1, 1),
}


@pytest.mark.filterwarnings("ignore::UserWarning")
@pytest.mark.parametrize("process_name, dimensions", [
    ("GeneralizedCoherenceFactor", list(EXPECTED_SHAPE)),
    ("PhaseCoherenceFactor", list(EXPECTED_SHAPE)),
    ("CaponMinimumVariance", list(EXPECTED_SHAPE)),
    ("DelayMultiplyAndSum", list(EXPECTED_SHAPE)),
    ("ShortLagSpatialCoherence", [Dimension.receive, Dimension.transmit]),
])
def test_should_produce_finite_output_of_the_right_shape(process_name, dimensions):
    for dimension in dimensions:
        b_data, out = _run(process_name, dimension)
        P, C, W, _ = b_data.data.shape
        assert out.data.shape == EXPECTED_SHAPE[dimension](P, C, W), (process_name, dimension)
        assert np.all(np.isfinite(out.data)), (process_name, dimension)


def test_capon_should_reduce_to_the_coherent_sum_for_two_identical_channels():
    """With L = 1 every subarray weight is 1, so MV returns conj of the channel sum."""
    b_data = _beamformed(N_channels=8, N_waves=1)
    mv = postprocess.CaponMinimumVariance()
    mv.input, mv.dimension = b_data, Dimension.receive
    mv.scan, mv.channel_data = b_data.scan, _ChannelData()
    mv.L_elements, mv.K_in_lambda, mv.regCoef = 1, 1, 1 / 100
    out = mv.go()
    # MATLAB convention: the output is the complex conjugate of w^H x
    expected = np.conj(b_data.data.sum(axis=1, keepdims=True))
    np.testing.assert_allclose(out.data, expected, rtol=1e-4, atol=1e-4)


def test_gcf_should_reject_an_m0_larger_than_the_aperture():
    gcf = postprocess.GeneralizedCoherenceFactor()
    gcf.input, gcf.dimension, gcf.M0 = _beamformed(N_waves=3), Dimension.transmit, 4
    with pytest.raises(ValueError):
        gcf.go()


def test_gcf_should_only_check_m0_against_the_summed_axis():
    gcf = postprocess.GeneralizedCoherenceFactor()
    gcf.input, gcf.dimension, gcf.M0 = _beamformed(N_channels=8, N_waves=3), Dimension.receive, 4
    assert gcf.go().data.shape == (240, 1, 3, 1)
