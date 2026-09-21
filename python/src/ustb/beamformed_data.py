"""BeamformedData container matching MATLAB uff.beamformed_data."""

import numpy as np


class BeamformedData:
    """Container for beamformed data with associated scan grid.

    Properties mirror the MATLAB uff.beamformed_data class.
    """

    def __init__(self, scan=None, data=None):
        self.scan = scan
        self.data = data

    @property
    def N_pixels(self):
        if self.data is not None:
            return self.data.shape[0]
        return 0

    def plot(self, title="", dynamic_range=60):
        from ustb.plotting import plot_beamformed_data
        return plot_beamformed_data(self, title=title, dynamic_range=dynamic_range)

    def _image_shape(self):
        """Return (N_rows, N_cols) for reshaping self.data's pixel axis.

        Follows pyuff_ustb's own pixel flatten order (see ustb.plotting):
        LinearScan is (x, z), SectorScan is (depth, azimuth).
        """
        scan = self.scan
        if hasattr(scan, "x_axis") and scan.x_axis is not None:
            return scan.N_x_axis, scan.N_z_axis
        elif hasattr(scan, "depth_axis") and scan.depth_axis is not None:
            return scan.N_depth_axis, scan.N_azimuth_axis
        raise ValueError(f"Don't know how to reshape image for scan of type {type(scan)}")

    def get_image(self, compression="log"):
        """Reshape (and optionally compress) the beamformed data into an image.

        Mirrors MATLAB uff.beamformed_data.get_image(compression). Assumes
        data has a single receive/transmit column (e.g. dimension.both, or
        after compounding) -- shape (N_pixels, 1, N_waves_or_1, N_frames).

        Args:
            compression: one of "log" (dB, normalized to peak), "sqrt",
                "abs", "none", "none-complex" (the last two are equivalent
                in Python -- both return the raw data).

        Returns:
            Array of shape (N_rows, N_cols, N_waves_or_1, N_frames).
        """
        data = np.asarray(self.data)
        while data.ndim < 4:
            data = data[..., np.newaxis]

        N_pixels, N_dim2, N_dim3, N_frames = data.shape
        if N_dim2 != 1:
            raise ValueError(
                "get_image() expects a single receive/transmit-combined "
                f"column (got N_channels={N_dim2}); reduce the dimension "
                "(e.g. dimension.both) before calling get_image()."
            )

        if compression == "log":
            envelope = np.abs(data)
            peak = envelope.max()
            with np.errstate(divide="ignore"):
                img = 20.0 * np.log10(envelope / peak) if peak > 0 else envelope
        elif compression == "sqrt":
            img = np.sqrt(np.abs(data))
        elif compression == "abs":
            img = np.abs(data)
        elif compression in ("none", "none-complex"):
            img = data
        else:
            raise ValueError(f"Unknown compression mode: {compression}")

        n_rows, n_cols = self._image_shape()
        if n_rows * n_cols != N_pixels:
            raise ValueError(
                f"Scan grid ({n_rows}x{n_cols}={n_rows * n_cols} pixels) does "
                f"not match data ({N_pixels} pixels)"
            )
        return img.reshape(n_rows, n_cols, N_dim3, N_frames)

    def save_as_gif(self, filename, dynamic_range=60, fps=10, title=""):
        """Save a multi-frame B-mode image sequence as an animated GIF.

        Mirrors MATLAB uff.beamformed_data.save_as_gif(filename). Requires
        a single-channel image stack (e.g. dimension.both output).
        """
        import matplotlib.pyplot as plt
        from matplotlib.animation import FuncAnimation, PillowWriter

        img_stack = self.get_image(compression="log")
        if img_stack.shape[2] != 1:
            raise ValueError(
                "save_as_gif() expects a single-channel image stack "
                f"(got N_waves_or_channels={img_stack.shape[2]})"
            )
        img_stack = np.clip(img_stack[:, :, 0, :], -dynamic_range, 0)
        N_frames = img_stack.shape[2]

        fig, ax = plt.subplots()
        frame0 = img_stack[:, :, 0].T
        im = ax.imshow(frame0, cmap="gray", vmin=-dynamic_range, vmax=0,
                        origin="upper", aspect="auto")
        ax.axis("off")

        def _title(i):
            return f"{title}, Frame = {i + 1}/{N_frames}" if title else f"Frame = {i + 1}/{N_frames}"

        ax.set_title(_title(0))

        def update(i):
            im.set_data(img_stack[:, :, i].T)
            ax.set_title(_title(i))
            return [im]

        anim = FuncAnimation(fig, update, frames=N_frames, blit=False)
        anim.save(filename, writer=PillowWriter(fps=fps))
        plt.close(fig)
        return filename
