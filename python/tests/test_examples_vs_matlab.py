"""Integration tests comparing Python examples against MATLAB reference output.

Each test loads the MATLAB reference HDF5, runs the matching Python example,
and compares sorted envelopes to verify the beamformer produces equivalent results
regardless of pixel ordering differences.
"""

import os
import sys
import numpy as np
import pytest
import h5py

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

REF_DIR = os.path.dirname(__file__)
DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "data")


def load_matlab_envelope(ref_file):
    """Load MATLAB beamformed envelope from reference HDF5."""
    with h5py.File(ref_file, "r") as f:
        bf = f["bf_real"][:] + 1j * f["bf_imag"][:]
    return np.abs(bf).ravel()


def compare_envelopes(ml_env, py_env, name, corr_threshold=0.95):
    """Compare sorted envelopes between MATLAB and Python."""
    ml_sorted = np.sort(ml_env) / (ml_env.max() + 1e-20)
    py_sorted = np.sort(py_env) / (py_env.max() + 1e-20)
    n = min(len(ml_sorted), len(py_sorted))
    corr = np.corrcoef(ml_sorted[:n], py_sorted[:n])[0, 1]
    assert corr > corr_threshold, (
        f"{name}: sorted envelope correlation {corr:.4f} < {corr_threshold}"
    )
    return corr


class TestCPWCLinear:
    REF = os.path.join(REF_DIR, "ref_cpwc_linear.h5")
    DATA = os.path.join(DATA_DIR, "L7_CPWC_193328.uff")

    @pytest.fixture(scope="class")
    def result(self):
        if not os.path.exists(self.DATA):
            pytest.skip("Dataset not available")
        from examples.cpwc_linear import main
        import matplotlib; matplotlib.use("Agg")
        return main()

    @pytest.mark.skipif(not os.path.exists(REF), reason="Reference not available")
    def test_should_match_matlab_envelope(self, result):
        ml_env = load_matlab_envelope(self.REF)
        py_env = np.abs(result.data).ravel()
        corr = compare_envelopes(ml_env, py_env, "CPWC Linear")
        print(f"CPWC Linear correlation: {corr:.4f}")

    def test_should_produce_nonzero_output(self, result):
        assert np.abs(result.data).max() > 0

    def test_should_have_correct_pixel_count(self, result):
        assert result.data.shape[0] == 256 * 256


class TestPICMUSExperimentResolution:
    REF = os.path.join(REF_DIR, "ref_picmus_exp_resolution.h5")
    DATA = os.path.join(DATA_DIR, "PICMUS_experiment_resolution_distortion.uff")

    @pytest.fixture(scope="class")
    def result(self):
        if not os.path.exists(self.DATA):
            pytest.skip("Dataset not available")
        from examples.picmus_experiment_resolution import main
        import matplotlib; matplotlib.use("Agg")
        return main()

    @pytest.mark.skipif(not os.path.exists(REF), reason="Reference not available")
    def test_should_match_matlab_envelope(self, result):
        ml_env = load_matlab_envelope(self.REF)
        py_env = np.abs(result.data).ravel()
        corr = compare_envelopes(ml_env, py_env, "PICMUS Exp Resolution")
        print(f"PICMUS Exp Resolution correlation: {corr:.4f}")

    def test_should_produce_nonzero_output(self, result):
        assert np.abs(result.data).max() > 0


class TestPICMUSSimulationResolution:
    REF = os.path.join(REF_DIR, "ref_picmus_sim_resolution.h5")
    DATA = os.path.join(DATA_DIR, "PICMUS_simulation_resolution_distortion.uff")

    @pytest.fixture(scope="class")
    def result(self):
        if not os.path.exists(self.DATA):
            pytest.skip("Dataset not available")
        from examples.picmus_simulation_resolution import main
        import matplotlib; matplotlib.use("Agg")
        return main()

    @pytest.mark.skipif(not os.path.exists(REF), reason="Reference not available")
    def test_should_match_matlab_envelope(self, result):
        ml_env = load_matlab_envelope(self.REF)
        py_env = np.abs(result.data).ravel()
        corr = compare_envelopes(ml_env, py_env, "PICMUS Sim Resolution")
        print(f"PICMUS Sim Resolution correlation: {corr:.4f}")

    def test_should_produce_nonzero_output(self, result):
        assert np.abs(result.data).max() > 0


class TestPICMUSExperimentContrast:
    REF = os.path.join(REF_DIR, "ref_picmus_exp_contrast.h5")
    DATA = os.path.join(DATA_DIR, "PICMUS_experiment_contrast_speckle.uff")

    @pytest.fixture(scope="class")
    def result(self):
        if not os.path.exists(self.DATA):
            pytest.skip("Dataset not available")
        from examples.picmus_experiment_contrast import main
        import matplotlib; matplotlib.use("Agg")
        return main()

    @pytest.mark.skipif(not os.path.exists(REF), reason="Reference not available")
    def test_should_match_matlab_envelope(self, result):
        ml_env = load_matlab_envelope(self.REF)
        py_env = np.abs(result.data).ravel()
        corr = compare_envelopes(ml_env, py_env, "PICMUS Exp Contrast")
        print(f"PICMUS Exp Contrast correlation: {corr:.4f}")

    def test_should_produce_nonzero_output(self, result):
        assert np.abs(result.data).max() > 0


class TestPICMUSSimulationContrast:
    REF = os.path.join(REF_DIR, "ref_picmus_sim_contrast.h5")
    DATA = os.path.join(DATA_DIR, "PICMUS_simulation_contrast_speckle.uff")

    @pytest.fixture(scope="class")
    def result(self):
        if not os.path.exists(self.DATA):
            pytest.skip("Dataset not available")
        from examples.picmus_simulation_contrast import main
        import matplotlib; matplotlib.use("Agg")
        return main()

    @pytest.mark.skipif(not os.path.exists(REF), reason="Reference not available")
    def test_should_match_matlab_envelope(self, result):
        ml_env = load_matlab_envelope(self.REF)
        py_env = np.abs(result.data).ravel()
        corr = compare_envelopes(ml_env, py_env, "PICMUS Sim Contrast")
        print(f"PICMUS Sim Contrast correlation: {corr:.4f}")

    def test_should_produce_nonzero_output(self, result):
        assert np.abs(result.data).max() > 0
