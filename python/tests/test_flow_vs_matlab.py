"""Python SVD filters and autocorrelation Doppler vs MATLAB, on a committed reference.

tests/ci_reference/flow.h5 (generate_flow_references.m) holds synthetic
multi-frame data (static tissue + phase-shifting blood + noise) and the MATLAB
outputs. No dataset is needed; this runs in CI.
"""

import os
import numpy as np
import pytest
import h5py

from tests.matlab_compare import match_pixels
from ustb.beamformed_data import BeamformedData
from ustb import postprocess, preprocess

REFERENCE_FILE = os.path.join(os.path.dirname(__file__), "ci_reference", "flow.h5")


class _Pulse:
    center_frequency = 5e6


class _ChannelData:
    sound_speed = 1540.0
    pulse = _Pulse()


class _RawChannelData:
    def __init__(self, data):
        self.data = data
        self.sound_speed, self.probe, self.sequence, self.pulse = 1540.0, None, None, None
        self.sampling_frequency, self.initial_time, self.modulation_frequency = 20e6, 0.0, 0.0


@pytest.fixture(scope="module")
def ref():
    from pyuff_ustb.objects import LinearScan

    with h5py.File(REFERENCE_FILE, "r") as f:
        values = {name: f[name][()] for name in f}
    x_axis, z_axis = values["x_axis"].ravel(), values["z_axis"].ravel()
    scan = LinearScan()
    scan.__dict__["x_axis"], scan.__dict__["z_axis"] = x_axis, z_axis
    # MATLAB linear-scan pixel order: z varies fastest
    perm = match_pixels((np.repeat(x_axis, z_axis.size), np.tile(z_axis, x_axis.size)),
                        (scan.x, scan.z))

    def pixels(name):
        """MATLAB [pixel, 1, 1, frame] data in Python pixel order, as [pixel, frame]."""
        if f"{name}_real" in values:
            value = values[f"{name}_real"] + 1j * values[f"{name}_imag"]
        else:
            value = values[name]
        value = np.asarray(value).T
        return value.reshape(value.shape[0], -1)[perm]

    b_data = BeamformedData(scan=scan, data=pixels("input")[:, None, None, :])
    return values, b_data, pixels


@pytest.mark.parametrize("cutoff, key", [(3, "3"), ([2, 6], "2_6"), ([3, 5, 8], "3_5_8")])
def test_postprocess_svd_filter_should_match_matlab(ref, cutoff, key):
    _, b_data, pixels = ref
    svd = postprocess.SVDFilter()
    svd.input, svd.cutoff = b_data, cutoff
    out = svd.go()
    expected = pixels(f"svd_beamformed_{key}")
    np.testing.assert_allclose(out.data[:, 0, 0, :], expected,
                               rtol=0, atol=1e-9 * np.abs(expected).max())


def test_preprocess_svd_filter_should_match_matlab(ref):
    values, _, _ = ref
    data = values["channel_input"].T  # [time, channel, wave, frame]
    svd = preprocess.SVDFilter()
    svd.input, svd.cutoff = _RawChannelData(data), 2
    out = svd.go()
    expected = values["svd_channel_2"].T
    np.testing.assert_allclose(out.data, expected, rtol=0, atol=1e-9 * np.abs(expected).max())


def test_autocorrelation_should_match_matlab(ref):
    _, b_data, pixels = ref
    ac = postprocess.AutocorrelationDisplacementEstimation()
    ac.input, ac.channel_data = b_data, _ChannelData()
    ac.z_gate, ac.x_gate, ac.packet_size = 4, 2, 6
    out = ac.go()
    expected = pixels("autocorrelation")
    np.testing.assert_allclose(out.data[:, 0, 0, :], expected,
                               rtol=0, atol=1e-9 * np.abs(expected).max())


def test_modified_autocorrelation_should_match_matlab(ref):
    values, b_data, pixels = ref
    mac = postprocess.ModifiedAutocorrelationDisplacementEstimation()
    mac.input, mac.channel_data = b_data, _ChannelData()
    mac.z_gate, mac.x_gate, mac.packet_size = 4, 2, 6
    out = mac.go()
    expected = pixels("modified_autocorrelation")
    np.testing.assert_allclose(out.data[:, 0, 0, :], expected,
                               rtol=0, atol=1e-9 * np.abs(expected).max())
    # MATLAB stores it as images: [depth, lateral, 1, 1, frame]
    expected_fc = values["modified_center_frequency"].T.reshape(mac.estimated_center_frequency.shape)
    np.testing.assert_allclose(mac.estimated_center_frequency, expected_fc, rtol=1e-9, atol=1e-3)
