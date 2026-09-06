"""Unit tests for USTB enumerations."""

import pytest
from ustb.enums import Dimension, Wavefront, Window, Code


class TestDimension:
    def test_values_match_matlab(self):
        assert int(Dimension.none) == 0
        assert int(Dimension.receive) == 1
        assert int(Dimension.transmit) == 2
        assert int(Dimension.both) == 3

    def test_all_members_exist(self):
        assert len(Dimension) == 4


class TestWavefront:
    def test_values_match_matlab(self):
        assert int(Wavefront.plane) == 0
        assert int(Wavefront.spherical) == 1
        assert int(Wavefront.photoacoustic) == 2

    def test_all_members_exist(self):
        assert len(Wavefront) == 3


class TestWindow:
    def test_key_values_match_matlab(self):
        assert int(Window.none) == 0
        assert int(Window.boxcar) == 1
        assert int(Window.hanning) == 2
        assert int(Window.hamming) == 3
        assert int(Window.scanline) == 8

    def test_boxcar_rectangular_alias(self):
        assert Window.boxcar == Window.rectangular


class TestCode:
    def test_values(self):
        assert int(Code.matlab) == 0
        assert int(Code.mex) == 1
        assert int(Code.python) == 2
