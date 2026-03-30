"""PICMUS Simulation Contrast Speckle.

Python equivalent of examples/picmus/simulation_contrast_speckle.m.
"""

import numpy as np
import matplotlib
matplotlib.use("Agg")

from examples.utils import read_channel_data, read_uff_object, save_image
from ustb.midprocess import DAS
from ustb.enums import Dimension, Window


def main():
    filename = "PICMUS_simulation_contrast_speckle.uff"
    channel_data = read_channel_data(filename)
    scan = read_uff_object(filename, "scan")

    mid = DAS()
    mid.channel_data = channel_data
    mid.scan = scan
    mid.dimension = Dimension.both
    mid.receive_apodization.window = Window.tukey50
    mid.receive_apodization.f_number = np.array([1.7, 1.7])
    mid.transmit_apodization.window = Window.tukey50
    mid.transmit_apodization.f_number = np.array([1.7, 1.7])
    b_data = mid.go()

    fig, ax = b_data.plot(title="PICMUS Simulation Contrast")
    save_image(fig, "picmus_sim_contrast.png")
    return b_data


if __name__ == "__main__":
    main()
