"""Generalized Delay-And-Sum beamformer.

Python reimplementation of MATLAB midprocess.das, implementing Eq. (2) of
Rindal et al., "The Generalized Beamformer".
"""

import time
import numpy as np
from scipy.interpolate import interp1d

from ustb.enums import Dimension, Wavefront
from ustb.apodization import Apodization


class DAS:
    """Generalized DAS beamformer matching MATLAB midprocess.das.

    Properties mirror the MATLAB class: channel_data, scan, dimension,
    receive_apodization, transmit_apodization.

    Example:
        mid = DAS()
        mid.channel_data = channel_data
        mid.scan = scan
        mid.dimension = Dimension.both
        b_data = mid.go()
    """

    def __init__(self):
        self.channel_data = None
        self.scan = None
        self.dimension = Dimension.both
        self.receive_apodization = Apodization()
        self.transmit_apodization = Apodization()
        self.lens_delay = 0.0
        self.pw_margin = 1e-3
        self.spherical_transmit_delay_model = "hybrid"
        self.beamformed_data = None
        self.transmit_delay = None
        self.receive_delay = None
        self.elapsed_time = None

    def go(self):
        """Execute the DAS beamformer. Returns BeamformedData."""
        from ustb.beamformed_data import BeamformedData

        N_pixels = getattr(self.scan, "N_pixels", None) or self.scan.x.size
        N_channels = self.channel_data.N_channels
        N_waves = self.channel_data.N_waves
        N_frames = self.channel_data.N_frames

        sampling_frequency = np.float32(self.channel_data.sampling_frequency)
        initial_time = np.float32(self.channel_data.initial_time)
        modulation_frequency = np.float32(self.channel_data.modulation_frequency)
        w0 = 2.0 * np.pi * modulation_frequency

        # Transmit apodization
        self.transmit_apodization.probe = None
        self.transmit_apodization.sequence = self.channel_data.sequence
        self.transmit_apodization.focus = self.scan
        tx_apodization = self.transmit_apodization.data.astype(np.float32)

        # Receive apodization
        self.receive_apodization.probe = self.channel_data.probe
        self.receive_apodization.focus = self.scan
        rx_apodization = self.receive_apodization.data.astype(np.float32)

        # Receive delay: distance from each pixel to each element
        probe_x = self.channel_data.probe.x.ravel()
        probe_y = self.channel_data.probe.y.ravel()
        probe_z = self.channel_data.probe.z.ravel()
        scan_x = self.scan.x.ravel()
        scan_y = self.scan.y.ravel()
        scan_z = self.scan.z.ravel()

        xm = probe_x[np.newaxis, :] - scan_x[:, np.newaxis]
        ym = probe_y[np.newaxis, :] - scan_y[:, np.newaxis]
        zm = probe_z[np.newaxis, :] - scan_z[:, np.newaxis]
        receive_delay = np.float32(
            np.sqrt(xm**2 + ym**2 + zm**2) / self.channel_data.sound_speed
            + self.lens_delay
        )
        self.receive_delay = receive_delay

        # Transmit delay per wave
        transmit_delay = np.zeros((N_pixels, N_waves), dtype=np.float64)
        sequence = self.channel_data.sequence
        if not isinstance(sequence, (list, tuple)):
            sequence = [sequence]

        for n_wave, wave in enumerate(sequence):
            wf_val = wave.wavefront.value if hasattr(wave.wavefront, 'value') else int(wave.wavefront)
            src = wave.source
            src_x, src_y, src_z = float(src.x), float(src.y), float(src.z)
            src_az = float(src.azimuth)
            src_el = float(src.elevation)
            src_dist = float(src.distance)
            wave_ss = float(wave.sound_speed) if wave.sound_speed is not None else float(self.channel_data.sound_speed)

            if wf_val == int(Wavefront.spherical):
                if np.isinf(src_dist):
                    transmit_delay[:, n_wave] = (
                        scan_z * np.cos(src_az) * np.cos(src_el)
                        + scan_x * np.sin(src_az) * np.cos(src_el)
                        + scan_y * np.sin(src_el)
                    )
                else:
                    dist = ((-1.0) ** (scan_z < src_z)) * np.sqrt(
                        (src_x - scan_x) ** 2
                        + (src_y - scan_y) ** 2
                        + (src_z - scan_z) ** 2
                    )
                    if src_z < 0:
                        transmit_delay[:, n_wave] = dist - abs(src_dist)
                    else:
                        self._focused_transmit_delay(
                            transmit_delay, n_wave, dist, wave, scan_x, scan_y, scan_z, src_az, src_el, src_dist
                        )

            elif wf_val == int(Wavefront.plane):
                transmit_delay[:, n_wave] = (
                    scan_z * np.cos(src_az) * np.cos(src_el)
                    + scan_x * np.sin(src_az) * np.cos(src_el)
                    + scan_y * np.sin(src_el)
                )

            elif wf_val == int(Wavefront.photoacoustic):
                transmit_delay[:, n_wave] = 0.0

            wave_delay = float(wave.delay) if wave.delay is not None else 0.0
            transmit_delay[:, n_wave] = transmit_delay[:, n_wave] / wave_ss - wave_delay

        transmit_delay = transmit_delay.astype(np.float32)
        self.transmit_delay = transmit_delay

        # Channel data
        ch_data = np.asarray(self.channel_data.data)
        if ch_data.ndim == 2:
            ch_data = ch_data[:, :, np.newaxis, np.newaxis]
        elif ch_data.ndim == 3:
            ch_data = ch_data[:, :, :, np.newaxis]

        if abs(w0) < np.finfo(np.float32).eps:
            from scipy.signal import hilbert
            ch_data = hilbert(ch_data.real.astype(np.float32), axis=0).astype(np.complex64)
        else:
            ch_data = ch_data.astype(np.complex64)

        # Time axis
        N_samples = ch_data.shape[0]
        ch_data_time = initial_time + np.arange(N_samples, dtype=np.float32) / sampling_frequency

        # Beamform
        print(f"USTB Python beamformer...", end="", flush=True)
        t_start = time.time()
        bf_data = self._beamform(
            ch_data, ch_data_time, tx_apodization, rx_apodization,
            transmit_delay, receive_delay, w0, self.dimension,
            N_pixels, N_channels, N_waves, N_frames,
        )
        self.elapsed_time = time.time() - t_start
        print(f"Completed in {self.elapsed_time:.2f} seconds.")

        # Phase correction for IQ data
        if abs(w0) > np.finfo(np.float32).eps:
            try:
                ref_dist = self.scan.reference_distance.ravel()
            except (NotImplementedError, AttributeError):
                ref_dist = self.scan.z.ravel()
            phase = np.exp(
                -1j * 2 * w0 * ref_dist / self.channel_data.sound_speed
            ).astype(np.complex64)
            bf_data = bf_data * phase.reshape(-1, *([1] * (bf_data.ndim - 1)))

        # Create output
        b_data = BeamformedData(scan=self.scan, data=bf_data)
        self.beamformed_data = b_data
        return b_data

    def _focused_transmit_delay(self, transmit_delay, n_wave, dist, wave, scan_x, scan_y, scan_z, src_az, src_el, src_dist):
        """Handle focused (virtual source in front of transducer) transmit delays."""
        model = self.spherical_transmit_delay_model

        if model == "spherical":
            transmit_delay[:, n_wave] = dist + src_dist

        elif model == "hybrid":
            plane_delay = (
                scan_z * np.cos(src_az) * np.cos(src_el)
                + scan_x * np.sin(src_az) * np.cos(src_el)
                + scan_y * np.sin(src_el)
            )
            z_mask = (scan_z < (wave.source.z + self.pw_margin)) & (
                scan_z > (wave.source.z - self.pw_margin)
            )
            td = dist + src_dist
            td[z_mask] = plane_delay[z_mask]
            transmit_delay[:, n_wave] = td

        else:
            transmit_delay[:, n_wave] = dist + src_dist

    @staticmethod
    def _beamform(ch_data, ch_data_time, tx_apodization, rx_apodization,
                  transmit_delay, receive_delay, w0, dim,
                  N_pixels, N_channels, N_waves, N_frames):
        """Pure-Python DAS beamformer matching MATLAB tools.matlab_beamformer."""
        if dim == Dimension.none:
            bf_data = np.zeros((N_pixels, N_channels, N_waves, N_frames), dtype=np.complex64)
        elif dim == Dimension.receive:
            bf_data = np.zeros((N_pixels, 1, N_waves, N_frames), dtype=np.complex64)
        elif dim == Dimension.transmit:
            bf_data = np.zeros((N_pixels, N_channels, 1, N_frames), dtype=np.complex64)
        elif dim == Dimension.both:
            bf_data = np.zeros((N_pixels, 1, 1, N_frames), dtype=np.complex64)

        t0 = float(ch_data_time[0])
        dt = float(ch_data_time[1] - ch_data_time[0]) if len(ch_data_time) > 1 else 1.0
        N_samples = len(ch_data_time)

        for n_wave in range(N_waves):
            if not np.any(tx_apodization[:, n_wave]):
                continue
            for n_rx in range(N_channels):
                if not np.any(rx_apodization[:, n_rx]):
                    continue

                apo = rx_apodization[:, n_rx] * tx_apodization[:, n_wave]
                delay = receive_delay[:, n_rx] + transmit_delay[:, n_wave]

                # Interpolate: map delay (seconds) to sample index
                sample_idx = (delay - t0) / dt
                idx_floor = np.floor(sample_idx).astype(np.int32)
                frac = sample_idx - idx_floor

                valid = (idx_floor >= 0) & (idx_floor < N_samples - 1)

                for n_frame in range(N_frames):
                    trace = ch_data[:, n_rx, n_wave, n_frame]
                    interp_val = np.zeros(N_pixels, dtype=trace.dtype)
                    v = valid
                    interp_val[v] = (
                        trace[idx_floor[v]] * (1.0 - frac[v])
                        + trace[idx_floor[v] + 1] * frac[v]
                    )

                    temp = apo * interp_val

                    if abs(w0) > np.finfo(np.float32).eps:
                        temp = np.exp(1j * w0 * delay) * temp

                    if dim == Dimension.none:
                        bf_data[:, n_rx, n_wave, n_frame] = temp
                    elif dim == Dimension.receive:
                        bf_data[:, 0, n_wave, n_frame] += temp
                    elif dim == Dimension.transmit:
                        bf_data[:, n_rx, 0, n_frame] += temp
                    elif dim == Dimension.both:
                        bf_data[:, 0, 0, n_frame] += temp

        return bf_data
