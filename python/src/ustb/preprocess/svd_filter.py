"""SVD clutter filter on channel data (port of MATLAB preprocess.svd_filter)."""

import numpy as np

from ustb._svd import svd_filter_frames
from ustb.preprocess._channel_data_view import DemodulatedChannelData


class SVDFilter:
    """Spatiotemporal SVD clutter filter applied across the frames of channel data.

    ``cutoff`` selects the temporal singular components to keep (1-based, as
    in MATLAB): a scalar c keeps c..N_frames (e.g. 2 removes the strongest,
    tissue, component), [a, b] keeps a..b, and any other vector keeps exactly
    those components. A cutoff starting at 1 leaves the data unfiltered, as in
    MATLAB. The output has the input's probe, sequence etc. with filtered data.

    Reference: C. Demene et al., IEEE TMI 34(11):2271-2285, 2015.
    """

    def __init__(self):
        self.input = None
        self.cutoff = None

    def go(self):
        if self.cutoff is None:
            raise ValueError("Set cutoff before go()")
        data = np.asarray(self.input.data)
        while data.ndim < 4:
            data = data[..., np.newaxis]
        output = DemodulatedChannelData(self.input)
        output._data_override = svd_filter_frames(data, self.cutoff)
        return output
