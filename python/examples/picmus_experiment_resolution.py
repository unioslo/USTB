"""PICMUS Experiment Resolution Distortion.

Python equivalent of examples/picmus/experiment_resolution_distortion.m.
75 plane-wave dataset recorded on a CIRS phantom with a Verasonics L11 probe.
"""

import numpy as np
import matplotlib
matplotlib.use("Agg")

from examples.utils import read_channel_data, read_uff_object, save_image
from ustb.midprocess import DAS
from ustb.enums import Dimension, Window


def main():
    filename = "PICMUS_experiment_resolution_distortion.uff"
    channel_data = read_channel_data(filename)
    scan = read_uff_object(filename, "scan")

    print(f"Channel data: {channel_data.N_samples} samples, "
          f"{channel_data.N_channels} channels, "
          f"{channel_data.N_waves} waves")
    print(f"Scan: {scan.x.size} pixels")

    mid = DAS()
    mid.channel_data = channel_data
    mid.scan = scan
    mid.dimension = Dimension.both
    mid.receive_apodization.window = Window.tukey50
    mid.receive_apodization.f_number = np.array([1.7, 1.7])
    mid.transmit_apodization.window = Window.tukey50
    mid.transmit_apodization.f_number = np.array([1.7, 1.7])
    b_data = mid.go()

    fig, ax = b_data.plot(title="PICMUS Experiment Resolution")
    save_image(fig, "picmus_exp_resolution.png")
    return b_data


if __name__ == "__main__":
    main()
