"""Unit tests for ustb.plotting.plot_channel_data."""

import matplotlib
matplotlib.use("Agg")

import numpy as np
import matplotlib.pyplot as plt
from ustb.plotting import plot_channel_data


class FakeChannelData:
    def __init__(self, data, fs=40e6, t0=0.0):
        self.data = data
        self.sampling_frequency = fs
        self.initial_time = t0


class TestPlotChannelData:
    def test_should_return_figure_and_axes_for_abs_mode(self):
        N_samples, N_channels, N_waves = 128, 16, 3
        data = np.random.randn(N_samples, N_channels, N_waves)
        ch_data = FakeChannelData(data)

        fig, ax = plot_channel_data(ch_data, plot_abs=True)

        assert fig is not None
        assert ax is not None
        plt.close(fig)

    def test_should_default_to_middle_wave(self):
        N_samples, N_channels, N_waves = 64, 8, 5
        data = np.zeros((N_samples, N_channels, N_waves))
        data[:, :, 2] = 1.0  # middle wave (index N_waves // 2 == 2)
        ch_data = FakeChannelData(data)

        fig, ax = plot_channel_data(ch_data, plot_abs=True)

        assert ax.get_title() == "Beam 2"
        plt.close(fig)

    def test_should_return_two_axes_for_real_imaginary_mode(self):
        N_samples, N_channels, N_waves = 64, 8, 1
        data = (np.random.randn(N_samples, N_channels, N_waves)
                + 1j * np.random.randn(N_samples, N_channels, N_waves))
        ch_data = FakeChannelData(data)

        fig, axes = plot_channel_data(ch_data, plot_abs=False)

        assert len(axes) == 2
        plt.close(fig)

    def test_should_handle_4d_input_using_first_frame(self):
        N_samples, N_channels, N_waves, N_frames = 32, 4, 1, 3
        data = np.random.randn(N_samples, N_channels, N_waves, N_frames)
        ch_data = FakeChannelData(data)

        fig, ax = plot_channel_data(ch_data)

        assert fig is not None
        plt.close(fig)
