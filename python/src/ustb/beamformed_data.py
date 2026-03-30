"""BeamformedData container matching MATLAB uff.beamformed_data."""

import numpy as np


class BeamformedData:
    """Container for beamformed data with associated scan grid.

    Properties mirror the MATLAB uff.beamformed_data class.
    """

    def __init__(self, scan=None, data=None):
        self.scan = scan
        self.data = data

    @property
    def N_pixels(self):
        if self.data is not None:
            return self.data.shape[0]
        return 0

    def plot(self, title="", dynamic_range=60):
        from ustb.plotting import plot_beamformed_data
        return plot_beamformed_data(self, title=title, dynamic_range=dynamic_range)
