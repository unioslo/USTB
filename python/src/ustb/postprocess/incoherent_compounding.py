"""Incoherent compounding postprocess matching MATLAB postprocess.incoherent_compounding.

Sums the magnitude of beamformed data across the transmit/receive
dimension(s), trading phase information for reduced speckle.
"""

import numpy as np

from ustb.enums import Dimension
from ustb.beamformed_data import BeamformedData


class IncoherentCompounding:
    """Incoherent compounding postprocess matching MATLAB postprocess.incoherent_compounding."""

    def __init__(self):
        self.input = None
        self.dimension = Dimension.both

    def go(self):
        data = np.asarray(self.input.data)
        while data.ndim < 4:
            data = data[..., np.newaxis]

        if self.dimension == Dimension.both:
            out = np.sum(np.abs(data), axis=(1, 2), keepdims=True)
        elif self.dimension == Dimension.transmit:
            out = np.sum(np.abs(data), axis=2, keepdims=True)
        elif self.dimension == Dimension.receive:
            out = np.sum(np.abs(data), axis=1, keepdims=True)
        else:
            raise ValueError(f"Unsupported dimension: {self.dimension}")

        return BeamformedData(scan=self.input.scan, data=out.astype(np.float32))
