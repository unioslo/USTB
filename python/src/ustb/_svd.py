"""SVD (spatiotemporal) clutter filter core, shared by the pre- and postprocess.

Reference: C. Demene et al., "Spatiotemporal Clutter Filtering of Ultrafast
Ultrasound Data Highly Increases Doppler and fUltrasound Sensitivity",
IEEE TMI 34(11):2271-2285, 2015.
"""

import numpy as np


def resolve_cutoff(cutoff, N_frames):
    """MATLAB svd_filter cutoff rules, as 0-based component indices.

    - scalar c: components c..N_frames
    - two values [a, b]: components a..b
    - any other vector: exactly those components
    Values are 1-based, as in MATLAB. Returns ``None`` when MATLAB leaves the
    data unfiltered (all components kept, or a cutoff starting below 2).
    """
    cutoff = np.atleast_1d(np.asarray(cutoff, dtype=int)).ravel()
    if cutoff.size == 0:
        raise ValueError("cutoff is empty")
    if cutoff[-1] > N_frames:
        cutoff = np.arange(cutoff[0], N_frames + 1)
    elif cutoff.size == 1:
        cutoff = np.arange(cutoff[0], N_frames + 1)
    elif cutoff.size == 2:
        cutoff = np.arange(cutoff[0], cutoff[1] + 1)
    if cutoff.size == 0:
        # MATLAB silently returns zeros here (e.g. a scalar cutoff above N_frames)
        raise ValueError(f"cutoff selects no singular components for {N_frames} frames")
    if np.array_equal(cutoff, np.arange(1, N_frames + 1)) or cutoff[0] < 2:
        return None
    return cutoff - 1


def svd_filter_frames(data, cutoff):
    """Keep the temporal singular components ``cutoff`` of ``[..., frame]`` data.

    Port of MATLAB preprocess/postprocess.svd_filter: the data are reshaped to
    a Casorati matrix X (everything else x frames), the temporal singular
    vectors U come from svd(X^H X), and the result is X U_c U_c^H. Unlike
    MATLAB, the frame axis is always the last axis of ``data`` (MATLAB uses
    the last non-singleton dimension, which is a different axis when there is
    one frame), and ``cutoff`` is not modified.
    """
    data = np.asarray(data)
    N_frames = data.shape[-1]
    keep = resolve_cutoff(cutoff, N_frames)
    if keep is None:
        return data.copy()
    X = data.reshape(-1, N_frames)
    U, _, _ = np.linalg.svd(X.conj().T @ X)
    V = X @ U
    filtered = V[:, keep] @ U[:, keep].conj().T
    return filtered.reshape(data.shape).astype(data.dtype, copy=False)
