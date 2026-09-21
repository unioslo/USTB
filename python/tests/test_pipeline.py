"""Unit tests for ustb.pipeline.Pipeline."""

import numpy as np
import pytest
from ustb.pipeline import Pipeline, _classify
from ustb.apodization import Apodization


class FakePreprocess:
    __module__ = "ustb.preprocess.fake"

    def __init__(self):
        self.input = None
        self.went = False

    def go(self):
        self.went = True
        return f"preprocessed({self.input})"


class FakeMidprocess:
    __module__ = "ustb.midprocess.fake"

    def __init__(self):
        self.channel_data = None
        self.receive_apodization = None
        self.transmit_apodization = None
        self.scan = None

    def go(self):
        return f"beamformed({self.channel_data})"


class FakePostprocess:
    __module__ = "ustb.postprocess.fake"

    def __init__(self):
        self.input = None
        self.receive_apodization = None
        self.transmit_apodization = None

    def go(self):
        return f"postprocessed({self.input})"


class Unclassifiable:
    __module__ = "some.random.module"

    def go(self):
        return "?"


class TestClassify:
    def test_should_classify_by_module_path(self):
        assert _classify(FakePreprocess()) == "preprocess"
        assert _classify(FakeMidprocess()) == "midprocess"
        assert _classify(FakePostprocess()) == "postprocess"

    def test_should_raise_for_unknown_module(self):
        with pytest.raises(TypeError):
            _classify(Unclassifiable())


class TestPipelineDefaultDAS:
    def test_should_run_default_das_when_no_process_list_given(self):
        pipe = Pipeline()
        pipe.channel_data = "mock_channel_data"
        pipe.scan = "mock_scan"

        # Patch DAS with a fake for isolation from beamforming numerics.
        import ustb.midprocess as midprocess_module

        class FakeDAS:
            def __init__(self):
                self.channel_data = None
                self.scan = None
                self.receive_apodization = None
                self.transmit_apodization = None

            def go(self):
                return f"das({self.channel_data},{self.scan})"

        original = midprocess_module.DAS
        midprocess_module.DAS = FakeDAS
        try:
            output = pipe.go()
        finally:
            midprocess_module.DAS = original

        assert output == "das(mock_channel_data,mock_scan)"


class TestPipelineChaining:
    def test_midprocess_only(self):
        pipe = Pipeline()
        pipe.channel_data = "cd"
        pipe.scan = "sc"

        mid = FakeMidprocess()
        output = pipe.go([mid])

        assert output == "beamformed(cd)"
        assert mid.scan == "sc"

    def test_preprocess_then_midprocess(self):
        pipe = Pipeline()
        pipe.channel_data = "raw_cd"
        pipe.scan = "sc"

        pre = FakePreprocess()
        mid = FakeMidprocess()
        output = pipe.go([pre, mid])

        assert pre.went
        assert mid.channel_data == "preprocessed(raw_cd)"
        assert output == "beamformed(preprocessed(raw_cd))"

    def test_midprocess_then_postprocess(self):
        pipe = Pipeline()
        pipe.channel_data = "cd"
        pipe.scan = "sc"
        pipe.receive_apodization = "rx_apo"
        pipe.transmit_apodization = "tx_apo"

        mid = FakeMidprocess()
        post = FakePostprocess()
        output = pipe.go([mid, post])

        assert post.input == "beamformed(cd)"
        assert post.receive_apodization == "rx_apo"
        assert post.transmit_apodization == "tx_apo"
        assert output == "postprocessed(beamformed(cd))"

    def test_full_chain_pre_mid_post(self):
        pipe = Pipeline()
        pipe.channel_data = "raw_cd"
        pipe.scan = "sc"

        pre = FakePreprocess()
        mid = FakeMidprocess()
        post = FakePostprocess()
        output = pipe.go([pre, mid, post])

        assert output == "postprocessed(beamformed(preprocessed(raw_cd)))"

    def test_first_process_must_be_pre_or_midprocess(self):
        pipe = Pipeline()
        pipe.channel_data = "cd"

        with pytest.raises(ValueError):
            pipe.go([FakePostprocess()])

    def test_postprocess_after_preprocess_should_raise(self):
        pipe = Pipeline()
        pipe.channel_data = "cd"

        with pytest.raises(ValueError):
            pipe.go([FakePreprocess(), FakePostprocess()])

    def test_midprocess_after_midprocess_should_raise(self):
        pipe = Pipeline()
        pipe.channel_data = "cd"
        pipe.scan = "sc"

        with pytest.raises(ValueError):
            pipe.go([FakeMidprocess(), FakeMidprocess()])

    def test_preprocess_after_midprocess_should_raise(self):
        pipe = Pipeline()
        pipe.channel_data = "cd"
        pipe.scan = "sc"

        with pytest.raises(ValueError):
            pipe.go([FakeMidprocess(), FakePreprocess()])
