"""Minimal example: Python equivalent of the MATLAB minimal_example.m.

Downloads a cardiac phased array dataset, beamforms it with DAS, and displays
the B-mode image. This mirrors the MATLAB code:

    channel_data = uff.read_object('data.uff', '/channel_data');
    scan = uff.sector_scan('azimuth_axis', az, 'depth_axis', depth);
    mid = midprocess.das();
    mid.channel_data = channel_data;
    mid.dimension = dimension.both;
    mid.scan = scan;
    mid.transmit_apodization.window = uff.window.scanline;
    mid.receive_apodization.window = uff.window.none;
    b_data = mid.go();
    b_data.plot([], 'Human Heart');
"""

import os
import urllib.request
import numpy as np

from pyuff_ustb.objects import ChannelData, SectorScan
from ustb.enums import Dimension, Window
from ustb.midprocess import DAS
from ustb.plotting import plot_beamformed_data


def download_dataset(filename, url, local_path):
    """Download dataset if not already present."""
    filepath = os.path.join(local_path, filename)
    if os.path.exists(filepath):
        print(f"Dataset already exists: {filepath}")
        return filepath

    os.makedirs(local_path, exist_ok=True)
    full_url = url.rstrip("/") + "/" + filename
    print(f"Downloading {full_url} ...")
    urllib.request.urlretrieve(full_url, filepath)
    print(f"Saved to {filepath}")
    return filepath


def main():
    # Download and read dataset
    url = "https://www.ustb.no/datasets/"
    local_path = os.path.join(os.path.dirname(__file__), "..", "data")
    filename = "Verasonics_P2-4_parasternal_long_small.uff"
    filepath = download_dataset(filename, url, local_path)

    # Read channel data from UFF file using pyuff_ustb
    from pyuff_ustb.objects.uff import Uff
    uff_file = Uff(filepath)
    channel_data = uff_file.read("channel_data")

    print(f"Channel data: {channel_data.N_samples} samples, "
          f"{channel_data.N_channels} channels, "
          f"{channel_data.N_waves} waves, "
          f"{channel_data.N_frames} frames")
    print(f"Sound speed: {channel_data.sound_speed} m/s")
    print(f"Sampling frequency: {channel_data.sampling_frequency / 1e6:.1f} MHz")

    # Define image scan (sector scan for phased array)
    sequence = channel_data.sequence
    if not isinstance(sequence, (list, tuple)):
        sequence = [sequence]

    depth_axis = np.linspace(0e-3, 110e-3, 1024)
    first_az = float(sequence[0].source.azimuth)
    last_az = float(sequence[-1].source.azimuth)
    azimuth_axis = np.linspace(first_az, last_az, len(sequence))

    from pyuff_ustb.objects.point import Point
    scan = SectorScan()
    scan.__dict__["azimuth_axis"] = azimuth_axis
    scan.__dict__["depth_axis"] = depth_axis
    # Origin at (0,0,0) - standard for phased array
    origin = Point()
    origin.__dict__["distance"] = np.float64(0.0)
    origin.__dict__["azimuth"] = np.float64(0.0)
    origin.__dict__["elevation"] = np.float64(0.0)
    scan.__dict__["origin"] = origin

    N_pixels = len(azimuth_axis) * len(depth_axis)
    print(f"Scan: {len(azimuth_axis)} azimuths x {len(depth_axis)} depths = {N_pixels} pixels")

    # Beamform
    mid = DAS()
    mid.channel_data = channel_data
    mid.dimension = Dimension.both
    mid.scan = scan
    mid.transmit_apodization.window = Window.scanline
    mid.receive_apodization.window = Window.none
    b_data = mid.go()

    # Plot
    import matplotlib
    matplotlib.use("Agg")
    fig, ax = plot_beamformed_data(b_data, title="Human Heart", dynamic_range=60)
    output_path = os.path.join(os.path.dirname(__file__), "human_heart.png")
    fig.savefig(output_path, dpi=150, bbox_inches="tight")
    print(f"Image saved to {output_path}")


if __name__ == "__main__":
    main()
