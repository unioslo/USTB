"""Python postprocesses vs MATLAB, pixel by pixel, on a committed reference.

tests/ci_reference/processes.h5 (generate_process_references.m) holds the
per-channel beamformed input (L7 CPWC, 16 x 300 pixels, 64 channels) and the
MATLAB outputs, so the processes are compared on exactly the same input. No
dataset is needed; this runs in CI.
"""

import os
import numpy as np
import pytest
import h5py

from tests.matlab_compare import match_pixels, assert_pixelwise_match
from ustb.beamformed_data import BeamformedData
from ustb.enums import Dimension
from ustb import postprocess

REFERENCE_FILE = os.path.join(os.path.dirname(__file__), "ci_reference", "processes.h5")


class _Pulse:
    def __init__(self, center_frequency):
        self.center_frequency = center_frequency


class _ChannelData:
    """The channel-data properties the processes use."""

    def __init__(self, sound_speed, center_frequency):
        self.sound_speed = sound_speed
        self.pulse = _Pulse(center_frequency)
        self.probe = None


@pytest.fixture(scope="module")
def ref():
    from pyuff_ustb.objects import LinearScan

    with h5py.File(REFERENCE_FILE, "r") as f:
        values = {name: f[name][()] for name in _all_datasets(f)}
    x_axis, z_axis = values["x_axis"].ravel(), values["z_axis"].ravel()
    scan = LinearScan()
    scan.__dict__["x_axis"] = x_axis.astype(np.float64)
    scan.__dict__["z_axis"] = z_axis.astype(np.float64)
    # MATLAB linear-scan pixel order: z varies fastest
    ml_x, ml_z = np.repeat(x_axis, z_axis.size), np.tile(z_axis, x_axis.size)
    perm = match_pixels((ml_x, ml_z), (scan.x, scan.z), atol=1e-7)

    data = (values["input_real"] + 1j * values["input_imag"]).T[perm]  # [pixel, channel]
    b_data = BeamformedData(scan=scan, data=data[:, :, None, None].astype(np.complex64))
    channel_data = _ChannelData(float(values["sound_speed"].squeeze()),
                                float(values["center_frequency"].squeeze()))

    def matlab(name):
        if f"{name}_real" in values:
            out = values[f"{name}_real"] + 1j * values[f"{name}_imag"]
        else:
            out = values[name]
        return np.asarray(out).T.reshape(len(perm), -1)[perm]

    return b_data, channel_data, matlab


def _all_datasets(f):
    names = []
    f.visititems(lambda name, obj: names.append(name) if isinstance(obj, h5py.Dataset) else None)
    return names


def _flat(bd):
    return np.asarray(bd.data if hasattr(bd, "data") else bd).reshape(-1, 1)


def test_coherence_factor_should_match_matlab(ref):
    b_data, _, matlab = ref
    cf = postprocess.CoherenceFactor()
    cf.input, cf.dimension = b_data, Dimension.receive
    out = cf.go()
    np.testing.assert_allclose(_flat(cf.CF), matlab("cf/factor"), atol=1e-5)
    assert_pixelwise_match(matlab("cf/output"), _flat(out), "CF", 0.99999, 1e-4)


def test_generalized_coherence_factor_should_match_matlab(ref):
    b_data, _, matlab = ref
    gcf = postprocess.GeneralizedCoherenceFactor()
    gcf.input, gcf.dimension, gcf.M0 = b_data, Dimension.receive, 4
    out = gcf.go()
    np.testing.assert_allclose(_flat(gcf.GCF), matlab("gcf/factor"), atol=1e-5)
    assert_pixelwise_match(matlab("gcf/output"), _flat(out), "GCF", 0.99999, 1e-4)


def test_phase_coherence_factor_should_match_matlab(ref):
    b_data, _, matlab = ref
    pcf = postprocess.PhaseCoherenceFactor()
    pcf.input, pcf.dimension = b_data, Dimension.receive
    out = pcf.go()
    np.testing.assert_allclose(_flat(pcf.FCC), matlab("pcf/FCC"), atol=1e-4)
    np.testing.assert_allclose(_flat(pcf.FCA), matlab("pcf/FCA"), atol=1e-4)
    assert_pixelwise_match(matlab("pcf/output"), _flat(out), "PCF", 0.99999, 1e-4)


@pytest.mark.parametrize("forward_backward, key", [(False, "capon"), (True, "capon_fb")])
def test_capon_minimum_variance_should_match_matlab(ref, forward_backward, key):
    b_data, channel_data, matlab = ref
    mv = postprocess.CaponMinimumVariance()
    mv.input, mv.dimension = b_data, Dimension.receive
    mv.scan, mv.channel_data = b_data.scan, channel_data
    mv.L_elements, mv.K_in_lambda, mv.regCoef = 16, 1, 1 / 100
    mv.doForwardBackward = forward_backward
    out = mv.go()
    assert_pixelwise_match(matlab(f"{key}/output"), _flat(out), key, 0.99999, 1e-4)


def test_delay_multiply_and_sum_should_match_matlab(ref):
    b_data, channel_data, matlab = ref
    dmas = postprocess.DelayMultiplyAndSum()
    dmas.input, dmas.dimension, dmas.channel_data = b_data, Dimension.receive, channel_data
    out = dmas.go()
    assert_pixelwise_match(matlab("dmas/output"), _flat(out), "DMAS", 0.99999, 1e-4)
