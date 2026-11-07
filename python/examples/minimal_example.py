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

The ``# %%`` markers split the script into cells that can be run one at a time
in the VS Code / Cursor Interactive Window, with plots shown inline.
"""

# %% Imports
import os

import matplotlib.pyplot as plt
import numpy as np
from pyuff_ustb.objects import SectorScan
from pyuff_ustb.objects.point import Point
from pyuff_ustb.objects.uff import Uff

from ustb.enums import Dimension, Window
from ustb.midprocess import DAS
from ustb.plotting import plot_beamformed_data
from ustb.tools import download, zenodo_dataset_files_base

try:
    here = os.path.dirname(os.path.abspath(__file__))
except NameError:  # Interactive Window runs from the file's folder
    here = os.getcwd()


# %% Download and read dataset
data_path = os.path.join(here, "..", "..", "data")
filename = "Verasonics_P2-4_parasternal_long_small.uff"
filepath = download(filename, zenodo_dataset_files_base(), data_path)

uff_file = Uff(filepath)
channel_data = uff_file.read("channel_data")

print(
    f"Channel data: {channel_data.N_samples} samples, "
    f"{channel_data.N_channels} channels, "
    f"{channel_data.N_waves} waves, "
    f"{channel_data.N_frames} frames"
)
print(f"Sound speed: {channel_data.sound_speed} m/s")
print(f"Sampling frequency: {channel_data.sampling_frequency / 1e6:.1f} MHz")

# %% Define image scan (sector scan for phased array)
sequence = channel_data.sequence
if not isinstance(sequence, (list, tuple)):
    sequence = [sequence]

depth_axis = np.linspace(0e-3, 110e-3, 1024)
first_az = float(sequence[0].source.azimuth)
last_az = float(sequence[-1].source.azimuth)
azimuth_axis = np.linspace(first_az, last_az, len(sequence))

scan = SectorScan(
    azimuth_axis=azimuth_axis,
    depth_axis=depth_axis,
    # Origin at (0,0,0) - standard for phased array
    origin=Point(distance=0.0, azimuth=0.0, elevation=0.0),
)

N_pixels = len(azimuth_axis) * len(depth_axis)
print(f"Scan: {len(azimuth_axis)} azimuths x {len(depth_axis)} depths = {N_pixels} pixels")

# %% Beamform
mid = DAS()
mid.channel_data = channel_data
mid.dimension = Dimension.both
mid.scan = scan
mid.transmit_apodization.window = Window.scanline
mid.receive_apodization.window = Window.none
b_data = mid.go()

# %% Plot
fig, ax = plot_beamformed_data(b_data, title="Human Heart", dynamic_range=60)
output_path = os.path.join(here, "output", "human_heart.png")
os.makedirs(os.path.dirname(output_path), exist_ok=True)
fig.savefig(output_path, dpi=150, bbox_inches="tight")
print(f"Image saved to {output_path}")

# %% Play all frames as a movie loop
# Run as a script, plt.show() opens the plot and plays the movie in windows.
# In the Interactive Window the last line shows the movie as a player with
# loop controls, so it has to stay last in the cell.
plt.rcParams["animation.html"] = "jshtml"
anim = b_data.animate(title="Human Heart", dynamic_range=60, fps=5)
plt.show()
anim  # noqa: B018 (displayed by the Interactive Window)
