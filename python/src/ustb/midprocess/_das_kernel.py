"""Numba-compiled DAS kernel (the inner loop of the generalized beamformer).

Same algorithm as DAS._beamform and MATLAB tools.matlab_beamformer: for each
pixel, wave and receive channel, linearly interpolate the channel data at
receive + transmit delay (zero outside the recorded time), multiply by the
receive and transmit apodization, apply the IQ phase term and accumulate
according to the dimension. Pixels are processed in parallel.
"""

import numpy as np
from numba import njit, prange

# Must match ustb.enums.Dimension
_NONE, _RECEIVE, _TRANSMIT, _BOTH = 0, 1, 2, 3


@njit(parallel=True, fastmath=False, cache=True)
def das_kernel(ch_data, t0, dt, tx_apodization, rx_apodization,
               transmit_delay, receive_delay, w0, dim, bf_data):
    """Beamform into ``bf_data`` (preallocated, zeroed, shaped by ``dim``).

    ch_data:         [samples, channels, waves, frames] complex64
    tx_apodization:  [pixels, waves] float32
    rx_apodization:  [pixels, channels] float32
    transmit_delay:  [pixels, waves] float32 (seconds)
    receive_delay:   [pixels, channels] float32 (seconds)
    """
    N_samples, N_channels, N_waves, N_frames = ch_data.shape
    N_pixels = tx_apodization.shape[0]
    apply_phase = abs(w0) > np.finfo(np.float32).eps

    for p in prange(N_pixels):
        for n_wave in range(N_waves):
            tx_apo = tx_apodization[p, n_wave]
            if tx_apo == 0.0:
                continue
            for n_rx in range(N_channels):
                apo = rx_apodization[p, n_rx] * tx_apo
                if apo == 0.0:
                    continue
                delay = np.float64(receive_delay[p, n_rx] + transmit_delay[p, n_wave])
                sample = (delay - t0) / dt
                i0 = int(np.floor(sample))
                if i0 < 0 or i0 >= N_samples - 1:
                    continue  # interpolation outside the recorded time gives 0
                frac = sample - i0
                if apply_phase:
                    weight = apo * np.exp(1j * w0 * delay)
                else:
                    weight = apo + 0j
                for n_frame in range(N_frames):
                    value = weight * (ch_data[i0, n_rx, n_wave, n_frame] * (1.0 - frac)
                                      + ch_data[i0 + 1, n_rx, n_wave, n_frame] * frac)
                    if dim == _NONE:
                        bf_data[p, n_rx, n_wave, n_frame] = value
                    elif dim == _RECEIVE:
                        bf_data[p, 0, n_wave, n_frame] += value
                    elif dim == _TRANSMIT:
                        bf_data[p, n_rx, 0, n_frame] += value
                    else:
                        bf_data[p, 0, 0, n_frame] += value
