"""Enumerations matching the MATLAB USTB enums."""

from enum import IntEnum


class Dimension(IntEnum):
    """Controls which axes are summed in the generalized beamformer."""
    none = 0
    receive = 1
    transmit = 2
    both = 3


class Wavefront(IntEnum):
    """Type of transmitted wave."""
    plane = 0
    spherical = 1
    photoacoustic = 2


class Window(IntEnum):
    """Window functions for apodization."""
    none = 0
    boxcar = 1
    rectangular = 1
    hanning = 2
    hamming = 3
    tukey25 = 4
    tukey50 = 5
    tukey75 = 6
    sta = 7
    scanline = 8
    triangle = 9


class Code(IntEnum):
    """Implementation backend for DAS."""
    matlab = 0
    mex = 1
    python = 2
    matlab_gpu = 3
    mex_gpu = 4
