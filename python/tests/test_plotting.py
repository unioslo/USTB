"""Unit tests for ustb.plotting."""

import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt
import numpy as np
import pytest
from pyuff_ustb.objects import LinearScan

from ustb.beamformed_data import BeamformedData
from ustb.plotting import animate_beamformed_data, plot_beamformed_data, plot_channel_data

rng = np.random.default_rng(0)


class FakeChannelData:
    def __init__(self, data, fs=40e6, t0=0.0):
        self.data = data
        self.sampling_frequency = fs
        self.initial_time = t0


class TestPlotChannelData:
    def test_should_return_figure_and_axes_for_abs_mode(self):
        N_samples, N_channels, N_waves = 128, 16, 3
        data = rng.standard_normal((N_samples, N_channels, N_waves))
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
        data = rng.standard_normal((N_samples, N_channels, N_waves)) + 1j * rng.standard_normal(
            (N_samples, N_channels, N_waves)
        )
        ch_data = FakeChannelData(data)

        fig, axes = plot_channel_data(ch_data, plot_abs=False)

        assert len(axes) == 2
        plt.close(fig)

    def test_should_handle_4d_input_using_first_frame(self):
        N_samples, N_channels, N_waves, N_frames = 32, 4, 1, 3
        data = rng.standard_normal((N_samples, N_channels, N_waves, N_frames))
        ch_data = FakeChannelData(data)

        fig, ax = plot_channel_data(ch_data)

        assert fig is not None
        plt.close(fig)


class FakeBeamformedData:
    def __init__(self, data):
        self.data = data
        self.scan = object()  # no axes: falls back to a 1D line plot


class TestPlotBeamformedData:
    def test_should_plot_first_frame_by_default(self):
        data = np.zeros((2, 1, 1, 3))
        data[:, 0, 0, 0] = [1.0, 0.1]
        data[:, 0, 0, 2] = [0.1, 1.0]

        fig, ax = plot_beamformed_data(FakeBeamformedData(data))

        np.testing.assert_allclose(ax.lines[0].get_ydata(), [0.0, -20.0])
        plt.close(fig)

    def test_should_plot_selected_frame(self):
        data = np.zeros((2, 1, 1, 3))
        data[:, 0, 0, 0] = [1.0, 0.1]
        data[:, 0, 0, 2] = [0.1, 1.0]

        fig, ax = plot_beamformed_data(FakeBeamformedData(data), frame=2)

        np.testing.assert_allclose(ax.lines[0].get_ydata(), [-20.0, 0.0])
        plt.close(fig)

    def test_should_handle_2d_input(self):
        data = np.array([[1.0], [0.1]])

        fig, ax = plot_beamformed_data(FakeBeamformedData(data))

        np.testing.assert_allclose(ax.lines[0].get_ydata(), [0.0, -20.0])
        plt.close(fig)


# The tests step frames by hand instead of playing the animation
@pytest.mark.filterwarnings("ignore:Animation was deleted without rendering")
class TestAnimateBeamformedData:
    def test_should_step_through_frames_normalized_to_sequence_peak(self):
        data = np.zeros((2, 1, 1, 3))
        data[:, 0, 0, 0] = [1.0, 0.1]
        data[:, 0, 0, 2] = [0.1, 0.1]

        anim = animate_beamformed_data(FakeBeamformedData(data), title="Movie")
        ax = anim._fig.axes[0]

        np.testing.assert_allclose(ax.lines[0].get_ydata(), [0.0, -20.0])
        anim._func(2)
        np.testing.assert_allclose(ax.lines[0].get_ydata(), [-20.0, -20.0])
        assert ax.get_title() == "Movie, Frame 3/3"
        plt.close(anim._fig)

    def test_should_update_the_image_of_a_linear_scan(self):
        scan = LinearScan(x_axis=np.linspace(-1e-3, 1e-3, 4), z_axis=np.linspace(1e-3, 2e-3, 5))
        data = rng.random((20, 1, 1, 2)) + 0.1
        b_data = BeamformedData(scan=scan, data=data)

        anim = b_data.animate(dynamic_range=40)
        mesh = anim._fig.axes[0].collections[0]
        anim._func(1)

        expected = np.clip(20 * np.log10(data[:, 0, 0, 1] / data.max()), -40, 0)
        np.testing.assert_allclose(np.asarray(mesh.get_array()).ravel(), expected)
        plt.close(anim._fig)

    def test_should_not_add_controls_without_a_window(self):
        anim = animate_beamformed_data(FakeBeamformedData(np.ones((2, 1, 1, 3))))

        assert len(anim._fig.axes) == 1
        plt.close(anim._fig)

    def test_should_step_slider_and_toggle_play_with_controls(self):
        data = np.zeros((2, 1, 1, 3))
        data[:, 0, 0, 0] = [1.0, 0.1]
        data[:, 0, 0, 1] = [0.1, 1.0]

        anim = animate_beamformed_data(FakeBeamformedData(data), controls=True)
        slider, button = anim.ustb_controls
        ax = anim._fig.axes[0]

        anim._fig.canvas.draw()  # the first draw starts the animation
        val = slider.val
        anim._func(None)  # a playback step moves the slider without pausing
        assert slider.val == val % 3 + 1
        assert button.label.get_text() == "Pause"

        button._observers.process("clicked", None)
        assert button.label.get_text() == "Play"

        slider.set_val(2)  # dragging the slider shows that frame
        np.testing.assert_allclose(ax.lines[0].get_ydata(), [-20.0, 0.0])
        assert button.label.get_text() == "Play"

        button._observers.process("clicked", None)
        assert button.label.get_text() == "Pause"
        plt.close(anim._fig)

    def test_should_save_as_gif(self, tmp_path):
        data = rng.random((2, 1, 1, 3)) + 0.1

        anim = animate_beamformed_data(FakeBeamformedData(data))
        anim.save(tmp_path / "movie.gif", writer="pillow")

        assert (tmp_path / "movie.gif").stat().st_size > 0
        plt.close(anim._fig)
