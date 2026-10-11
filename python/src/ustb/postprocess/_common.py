"""Helpers shared by the coherence-based postprocesses (as in the MATLAB classes)."""

import warnings

import numpy as np

from ustb.enums import Dimension, Window


def as_4d(data):
    """Beamformed data as ``[pixel, channel, wave, frame]``."""
    data = np.asarray(data)
    while data.ndim < 4:
        data = data[..., np.newaxis]
    return data


def resolve_dimension(dimension, N_channels, N_waves):
    """Validate ``dimension`` for the data size, falling back like MATLAB does."""
    dimension = Dimension(int(getattr(dimension, "value", dimension)))
    if dimension == Dimension.receive and N_channels < 2:
        raise ValueError("Not enough channels to compute factor")
    if dimension == Dimension.transmit and N_waves < 2:
        raise ValueError("Not enough waves to compute factor")
    if dimension == Dimension.both:
        if N_channels < 2 and N_waves > 1:
            warnings.warn("Not enough channels to compute factor. "
                          "Changing dimension to dimension.transmit")
            return Dimension.transmit
        if N_waves < 2 and N_channels > 1:
            warnings.warn("Not enough waves to compute factor. "
                          "Changing dimension to dimension.receive")
            return Dimension.receive
        if N_waves < 2 and N_channels < 2:
            raise ValueError("Not enough waves and channels to compute factor")
    return dimension


def receive_weights(apodization, scan, N_pixels, N_channels):
    """Receive apodization ``[pixel, channel]``; ones when unset or window none."""
    if apodization is None or apodization.window == Window.none:
        return np.ones((N_pixels, N_channels))
    apodization.focus = scan
    return np.asarray(apodization.data, dtype=np.float64)


def transmit_weights(apodization, scan, sequence, N_pixels, N_waves):
    """Transmit apodization ``[pixel, wave]``; ones when unset, window none or no sequence."""
    if (apodization is None or apodization.window == Window.none
            or (apodization.sequence is None and sequence is None)):
        return np.ones((N_pixels, N_waves))
    apodization.focus = scan
    if apodization.sequence is None:
        apodization.sequence = sequence
    return np.asarray(apodization.data, dtype=np.float64)
