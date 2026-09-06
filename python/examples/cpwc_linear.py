"""CPWC Linear Array (Verasonics L7) - Plane wave compound imaging.

Python equivalent of examples/uff/CPWC_UFF_Verasonics.m.
Downloads L7 CPWC data, beamforms with DAS using plane waves and a linear scan.
"""

import numpy as np
import matplotlib
matplotlib.use("Agg")

from examples.utils import read_channel_data, make_linear_scan, save_image
from ustb.midprocess import DAS
from ustb.enums import Dimension, Window


def main():
    channel_data = read_channel_data("L7_CPWC_193328.uff")

    print(f"Channel data: {channel_data.N_samples} samples, "
          f"{channel_data.N_channels} channels, "
          f"{channel_data.N_waves} waves, {channel_data.N_frames} frames")

    scan = make_linear_scan(channel_data, N_x=256, N_z=256, z_max=50e-3)

    mid = DAS()
    mid.channel_data = channel_data
    mid.scan = scan
    mid.dimension = Dimension.both
    mid.transmit_apodization.window = Window.none
    mid.transmit_apodization.f_number = np.array([1.7, 1.7])
    mid.receive_apodization.window = Window.none
    mid.receive_apodization.f_number = np.array([1.7, 1.7])
    b_data = mid.go()

    fig, ax = b_data.plot(title="CPWC Linear Array (L7)")
    save_image(fig, "cpwc_linear.png")
    return b_data


if __name__ == "__main__":
    main()
