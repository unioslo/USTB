"""Plotting utilities for USTB beamformed data."""

import matplotlib
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.animation import FuncAnimation
from matplotlib.backends import BackendFilter, backend_registry
from matplotlib.widgets import Button, Slider


def plot_beamformed_data(b_data, title="", dynamic_range=60, frame=0):
    """Plot beamformed data as a B-mode image.

    For sector scans, displays scan-converted (fan-shaped) images using the
    physical (x, z) pixel coordinates, matching MATLAB's pcolor-based display.
    For linear scans, displays a rectangular image.

    ``frame`` selects which frame of multi-frame data to plot (0-based). The
    image is normalized to the peak of that frame.
    """
    scan = b_data.scan
    data = np.array(b_data.data)
    while data.ndim < 4:
        data = data[..., np.newaxis]
    data = data[:, 0, 0, frame]

    envelope = np.abs(data)
    envelope[envelope < np.finfo(float).eps] = np.finfo(float).eps
    img_db = 20.0 * np.log10(envelope / envelope.max())
    img_db = np.clip(img_db, -dynamic_range, 0)

    is_sector = hasattr(scan, "azimuth_axis") and scan.azimuth_axis is not None
    is_linear = hasattr(scan, "x_axis") and scan.x_axis is not None

    if is_sector and not is_linear:
        return _plot_sector_scan(scan, img_db, title, dynamic_range)
    elif is_linear:
        return _plot_linear_scan(scan, img_db, title, dynamic_range)
    else:
        fig, ax = plt.subplots(1, 1, figsize=(8, 6))
        ax.plot(img_db)
        ax.set_ylabel("Amplitude [dB]")
        ax.set_title(title if title else "B-mode Image")
        return fig, ax


def animate_beamformed_data(b_data, title="", dynamic_range=60, fps=5, controls=None):
    """Play the frames of multi-frame beamformed data as a looping movie.

    Mirrors the "Play movie loop" button of MATLAB uff.beamformed_data.plot.
    Each frame is drawn like plot_beamformed_data, but all frames are
    normalized to the peak of the whole sequence so brightness changes between
    frames are kept.

    Returns the matplotlib FuncAnimation; keep a reference to it while it
    plays. Run as a script, plt.show() plays it in a window with a Play/Pause
    button and a frame slider (space toggles play, left/right arrows step).
    In Jupyter or the VS Code Interactive Window, set
    plt.rcParams["animation.html"] = "jshtml" and end the cell with the
    animation to get a player with its own controls. Save it with
    anim.save("movie.gif") or anim.save("movie.mp4") (needs ffmpeg).

    ``controls`` adds the button and slider; by default they are added only
    when the figure opens in a window (an interactive matplotlib backend).
    """
    data = np.array(b_data.data)
    while data.ndim < 4:
        data = data[..., np.newaxis]
    envelope = np.abs(data[:, 0, 0, :])
    envelope[envelope < np.finfo(float).eps] = np.finfo(float).eps
    img_db = np.clip(20.0 * np.log10(envelope / envelope.max()), -dynamic_range, 0)
    N_frames = img_db.shape[1]

    fig, ax = plot_beamformed_data(b_data, title=title, dynamic_range=dynamic_range)
    mesh = ax.collections[0] if ax.collections else None
    line = None if mesh is not None else ax.lines[0]

    def draw_frame(i):
        if mesh is not None:
            mesh.set_array(img_db[:, i].reshape(mesh.get_array().shape))
        else:
            line.set_ydata(img_db[:, i])
        label = f"Frame {i + 1}/{N_frames}"
        ax.set_title(f"{title}, {label}" if title else label)
        return [mesh if mesh is not None else line]

    draw_frame(0)
    if controls is None:
        controls = _opens_in_window()
    if not controls:
        return FuncAnimation(fig, draw_frame, frames=N_frames, interval=1000 / fps)

    fig.subplots_adjust(bottom=0.14)
    slider = Slider(
        fig.add_axes((0.15, 0.04, 0.5, 0.03)), "Frame", 1, N_frames, valinit=1, valstep=1
    )
    button = Button(fig.add_axes((0.75, 0.025, 0.12, 0.05)), "Pause")
    state = {"frame": N_frames - 1, "playing": True}  # the first step shows frame 0

    def show(i):
        state["frame"] = i
        draw_frame(i)
        # Moving the slider here must not count as a user drag (which pauses).
        # Restore rather than set True: set_val can redraw, start the animation
        # and re-enter show() before it returns.
        eventson, slider.eventson = slider.eventson, False
        slider.set_val(i + 1)
        slider.eventson = eventson
        fig.canvas.draw_idle()

    def step(_):
        show((state["frame"] + 1) % N_frames)

    anim = FuncAnimation(fig, step, frames=N_frames, interval=1000 / fps)

    def toggle(_event=None):
        if state["playing"]:
            anim.pause()
        else:
            anim.resume()
        state["playing"] = not state["playing"]
        button.label.set_text("Pause" if state["playing"] else "Play")
        fig.canvas.draw_idle()

    def go_to(i):
        if state["playing"]:
            toggle()
        show(i % N_frames)

    def on_key(event):
        if event.key == " ":
            toggle()
        elif event.key in ("left", "right"):
            go_to(state["frame"] + (1 if event.key == "right" else -1))

    slider.on_changed(lambda value: go_to(int(value) - 1))
    button.on_clicked(toggle)
    fig.canvas.mpl_connect("key_press_event", on_key)
    anim.ustb_controls = (slider, button)  # widgets stop working without a reference
    return anim


def _opens_in_window():
    """True when the current matplotlib backend shows figures in a window."""
    backend = matplotlib.get_backend().lower()
    return backend in backend_registry.list_builtin(BackendFilter.INTERACTIVE)


def _plot_sector_scan(scan, img_db, title, dynamic_range):
    """Scan-converted sector scan display using physical (x, z) coordinates.

    Matches MATLAB's pcolor(x_matrix, z_matrix, image) display where the
    image is shown in its physical fan-shaped geometry.
    """
    N_depth = len(scan.depth_axis)
    N_az = len(scan.azimuth_axis)

    # Reshape pixel coordinates and image to 2D grid
    # pyuff_ustb meshgrid(depth, az, indexing='ij') with C-order: (N_depth, N_az)
    x_matrix = scan.x.reshape(N_depth, N_az)
    z_matrix = scan.z.reshape(N_depth, N_az)
    img_2d = img_db.reshape(N_depth, N_az)

    fig, ax = plt.subplots(1, 1, figsize=(8, 8))

    # pcolormesh is Python's equivalent of MATLAB's pcolor
    pcm = ax.pcolormesh(
        x_matrix * 1e3,
        z_matrix * 1e3,
        img_2d,
        cmap="gray",
        vmin=-dynamic_range,
        vmax=0,
        shading="gouraud",
    )

    ax.set_aspect("equal")
    ax.invert_yaxis()
    ax.set_xlabel("x [mm]")
    ax.set_ylabel("z [mm]")
    ax.set_title(title if title else "B-mode Image")
    ax.set_facecolor("black")
    plt.colorbar(pcm, ax=ax, label="dB")
    plt.tight_layout()
    return fig, ax


def plot_channel_data(channel_data, n_wave=None, plot_abs=True, title=None):
    """Plot raw or demodulated channel data as a (channel, time) image.

    Mirrors MATLAB uff.channel_data.plot(figure, n_wave, plot_abs).

    Args:
        channel_data: object with .data [samples x channels x waves x
            frames], .sampling_frequency, .initial_time.
        n_wave: which transmit wave to plot (default: the middle one).
        plot_abs: if True, plot the envelope magnitude; if False, plot the
            real and imaginary parts side by side (for IQ data).
        title: plot title.
    """
    data = np.asarray(channel_data.data)
    if data.ndim == 2:
        data = data[:, :, np.newaxis]
    elif data.ndim == 4:
        data = data[:, :, :, 0]

    N_samples, N_channels, N_waves = data.shape
    if n_wave is None:
        n_wave = N_waves // 2

    fs = float(channel_data.sampling_frequency)
    t0 = float(channel_data.initial_time)
    time_us = (t0 + np.arange(N_samples) / fs) * 1e6

    trace = data[:, :, n_wave]

    if plot_abs:
        fig, ax = plt.subplots(1, 1, figsize=(6, 6))
        img = np.abs(trace)
        pcm = ax.pcolormesh(
            np.arange(1, N_channels + 1), time_us, img, cmap="inferno", shading="gouraud"
        )
        ax.invert_yaxis()
        ax.set_xlabel("Channel")
        ax.set_ylabel("time [us]")
        ax.set_title(title if title else f"Beam {n_wave}")
        plt.colorbar(pcm, ax=ax)
        plt.tight_layout()
        return fig, ax
    else:
        fig, axes = plt.subplots(1, 2, figsize=(11, 6))
        for ax, part, label in zip(
            axes, [trace.real, trace.imag], ["Real", "Imaginary"], strict=True
        ):
            pcm = ax.pcolormesh(
                np.arange(1, N_channels + 1), time_us, part, cmap="inferno", shading="gouraud"
            )
            ax.invert_yaxis()
            ax.set_xlabel("Channel")
            ax.set_ylabel("time [us]")
            ax.set_title(f"{label} Part - Beam {n_wave}")
            plt.colorbar(pcm, ax=ax)
        plt.tight_layout()
        return fig, axes


def _plot_linear_scan(scan, img_db, title, dynamic_range):
    """Rectangular linear scan display using pcolormesh for scan conversion."""
    x_axis = np.asarray(scan.x_axis).ravel()
    z_axis = np.asarray(scan.z_axis).ravel()
    N_x = len(x_axis)
    N_z = len(z_axis)

    # pyuff_ustb LinearScan uses meshgrid(x_axis, z_axis, indexing='ij')
    # with C-order flatten, giving shape (N_x, N_z)
    x_matrix = scan.x.reshape(N_x, N_z)
    z_matrix = scan.z.reshape(N_x, N_z)
    img_2d = img_db.reshape(N_x, N_z)

    fig, ax = plt.subplots(1, 1, figsize=(8, 8))
    pcm = ax.pcolormesh(
        x_matrix * 1e3,
        z_matrix * 1e3,
        img_2d,
        cmap="gray",
        vmin=-dynamic_range,
        vmax=0,
        shading="gouraud",
    )
    ax.set_aspect("equal")
    ax.invert_yaxis()
    ax.set_xlabel("x [mm]")
    ax.set_ylabel("z [mm]")
    ax.set_title(title if title else "B-mode Image")
    plt.colorbar(pcm, ax=ax, label="dB")
    plt.tight_layout()
    return fig, ax
