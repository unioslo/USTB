"""SVD clutter filter on beamformed data (port of MATLAB postprocess.svd_filter)."""

from ustb._svd import svd_filter_frames
from ustb.beamformed_data import BeamformedData
from ustb.postprocess._common import as_4d


class SVDFilter:
    """Spatiotemporal SVD clutter filter applied across the frames of beamformed data.

    ``cutoff`` as in :class:`ustb.preprocess.SVDFilter`: 1-based temporal
    singular components to keep; a scalar c keeps c..N_frames.

    Reference: C. Demene et al., IEEE TMI 34(11):2271-2285, 2015.
    """

    def __init__(self):
        self.input = None
        self.cutoff = None
        self.output = None

    def go(self):
        if self.cutoff is None:
            raise ValueError("Set cutoff before go()")
        data = as_4d(self.input.data)
        self.output = BeamformedData(scan=self.input.scan,
                                     data=svd_filter_frames(data, self.cutoff))
        return self.output
