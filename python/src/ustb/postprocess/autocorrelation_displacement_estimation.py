"""Autocorrelation (Kasai) and modified autocorrelation (Loupas) displacement estimation.

Estimate the axial displacement between consecutive frames from the phase of
the lag-one autocorrelation over a packet of frames, smoothed over a
z_gate x x_gate region. The modified estimator also estimates the local
center frequency from the axial lag-one autocorrelation.

References: C. Kasai et al., "Real-Time Two-Dimensional Blood Flow Imaging
Using an Autocorrelation Technique", IEEE TSU 32(3), 1985; T. Loupas,
J. T. Powers and R. W. Gill, "An Axial Velocity Estimator for Ultrasound
Blood Flow Imaging, Based on a Full Evaluation of the Doppler Equation by
Means of a Two-Dimensional Autocorrelation Approach", IEEE TUFFC 42(4), 1995.
"""

import numpy as np
from scipy.signal import convolve2d

from ustb._scan_grid import from_image, to_image
from ustb.beamformed_data import BeamformedData
from ustb.postprocess._common import as_4d


def _gate_sum(values, z_gate, x_gate):
    """MATLAB conv2(conv2(R, ones(U,1), 'valid'), ones(1,V), 'valid')."""
    values = convolve2d(values, np.ones((z_gate, 1)), mode="valid")
    return convolve2d(values, np.ones((1, x_gate)), mode="valid")


class AutocorrelationDisplacementEstimation:
    """Port of MATLAB postprocess.autocorrelation_displacement_estimation.

    Input: beamformed IQ data with one channel and one wave and more frames
    than ``packet_size``; ``channel_data`` gives the sound speed and the pulse
    center frequency. Output: displacement [m] for each packet, i.e.
    N_frames - packet_size + 1 frames, zero outside the gate-valid region.
    """

    modified = False

    def __init__(self):
        self.input = None
        self.channel_data = None
        self.z_gate = 4
        self.x_gate = 2
        self.packet_size = 6
        self.output = None

    def go(self):
        data = as_4d(self.input.data)
        N_pixels, N_rx, N_tx, N_frames = data.shape
        if N_frames <= self.packet_size:
            raise ValueError("The number of frames needs to be higher than the packet size")
        if N_rx != 1 or N_tx != 1:
            raise ValueError("Displacement estimation can only be used between frames "
                             "(one channel and one wave)")
        if self.z_gate % 2 or self.x_gate % 2:
            raise ValueError("Please use even numbers for z_gate and x_gate")

        scan = self.input.scan
        images = to_image(data[:, 0, 0, :], scan)  # [depth, lateral, frame]
        N_out = N_frames - self.packet_size + 1
        displacement = np.zeros((N_pixels, 1, 1, N_out))
        self._prepare(images.shape, N_out)
        U, V = self.z_gate, self.x_gate
        rows = slice(U // 2 - 1, images.shape[0] - U // 2 - 1)
        cols = slice(V // 2 - 1, images.shape[1] - V // 2)
        for n in range(N_out):
            packet = images[:, :, n:n + self.packet_size]
            gated = np.zeros(images.shape[:2])
            gated[rows, cols] = self._estimate(packet, n, rows, cols)
            displacement[:, 0, 0, n] = from_image(gated, scan)

        self.output = BeamformedData(scan=scan, data=displacement)
        return self.output

    def _prepare(self, shape, N_out):
        pass

    def _lag_one_temporal(self, X):
        return _gate_sum(np.sum(X[:-1, :, :-1] * np.conj(X[:-1, :, 1:]), axis=2),
                         self.z_gate, self.x_gate)

    def _estimate(self, X, n, rows, cols):
        f_hat = np.angle(self._lag_one_temporal(X)) / (2 * np.pi)
        c = self.channel_data.sound_speed
        fc = self.channel_data.pulse.center_frequency
        return c * f_hat / (2 * fc)


class ModifiedAutocorrelationDisplacementEstimation(AutocorrelationDisplacementEstimation):
    """Port of MATLAB postprocess.modified_autocorrelation_displacement_estimation.

    Like :class:`AutocorrelationDisplacementEstimation`, but the center
    frequency is estimated per pixel from the axial lag-one autocorrelation
    (Loupas et al.). After go(), ``estimated_center_frequency`` holds it as
    [depth, lateral, frame] (zero outside the gate-valid region and for the
    last packet_size - 1 frames, as in MATLAB).
    """

    def __init__(self):
        super().__init__()
        self.estimated_center_frequency = None

    def _prepare(self, shape, N_out):
        self.estimated_center_frequency = np.zeros(shape)
        z_axis = getattr(self.input.scan, "z_axis", None)
        if z_axis is None:
            z_axis = self.input.scan.depth_axis
        dz = np.mean(np.diff(np.asarray(z_axis, dtype=np.float64).ravel()))
        self._fs = self.channel_data.sound_speed / dz / 2  # image sampling frequency

    def _estimate(self, X, n, rows, cols):
        f_hat = np.angle(self._lag_one_temporal(X)) / (2 * np.pi)
        R_1_0 = _gate_sum(np.sum(X[:-1] * np.conj(X[1:]), axis=2), self.z_gate, self.x_gate)
        fc_hat = np.abs(np.angle(R_1_0) / (2 * np.pi / self._fs))
        self.estimated_center_frequency[rows, cols, n] = fc_hat
        return self.channel_data.sound_speed * f_hat / (2 * fc_hat)
