"""CPWC Linear Array (Verasonics L7) - Plane wave compound imaging.

Python equivalent of examples/uff/CPWC_UFF_Verasonics.m.
Downloads L7 CPWC data, beamforms with DAS using plane waves and a linear scan.
"""

import os

import matplotlib.pyplot as plt
import numpy as np
from pyuff_ustb.objects import LinearScan
from pyuff_ustb.objects.uff import Uff

from ustb.enums import Dimension, Window
from ustb.midprocess import DAS
from ustb.tools import download, zenodo_dataset_files_base

HERE = os.path.dirname(os.path.abspath(__file__))
DATA_PATH = os.path.join(HERE, "..", "..", "data")
OUTPUT_PATH = os.path.join(HERE, "output")


def main():
    filename = "L7_CPWC_193328.uff"
    filepath = download(filename, zenodo_dataset_files_base(), DATA_PATH)
    channel_data = Uff(filepath).read("channel_data")

    print(
        f"Channel data: {channel_data.N_samples} samples, "
        f"{channel_data.N_channels} channels, "
        f"{channel_data.N_waves} waves, {channel_data.N_frames} frames"
    )

    probe_x = channel_data.probe.x
    scan = LinearScan(
        x_axis=np.linspace(float(probe_x.min()), float(probe_x.max()), 256),
        z_axis=np.linspace(0, 50e-3, 256),
    )

    mid = DAS()
    mid.channel_data = channel_data
    mid.scan = scan
    mid.dimension = Dimension.both
    mid.transmit_apodization.window = Window.none
    mid.transmit_apodization.f_number = 1.7
    mid.receive_apodization.window = Window.none
    mid.receive_apodization.f_number = 1.7
    b_data = mid.go()

    fig, ax = b_data.plot(title="CPWC Linear Array (L7)")
    os.makedirs(OUTPUT_PATH, exist_ok=True)
    output_file = os.path.join(OUTPUT_PATH, "cpwc_linear.png")
    fig.savefig(output_file, dpi=150, bbox_inches="tight")
    print(f"Image saved to {output_file}")
    return b_data


if __name__ == "__main__":
    main()
    plt.show()
