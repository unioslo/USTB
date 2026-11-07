"""PICMUS Experiment Contrast Speckle.

Python equivalent of examples/picmus/experiment_contrast_speckle.m.
"""

import os

import matplotlib.pyplot as plt
from pyuff_ustb.objects.uff import Uff

from ustb.enums import Dimension, Window
from ustb.midprocess import DAS
from ustb.tools import download, zenodo_dataset_files_base

HERE = os.path.dirname(os.path.abspath(__file__))
DATA_PATH = os.path.join(HERE, "..", "..", "data")
OUTPUT_PATH = os.path.join(HERE, "output")


def main():
    filename = "PICMUS_experiment_contrast_speckle.uff"
    uff_file = Uff(download(filename, zenodo_dataset_files_base(), DATA_PATH))
    channel_data = uff_file.read("channel_data")
    scan = uff_file.read("scan")

    print(
        f"Channel data: {channel_data.N_samples} samples, "
        f"{channel_data.N_channels} channels, "
        f"{channel_data.N_waves} waves"
    )
    print(f"Scan: {scan.x.size} pixels")

    mid = DAS()
    mid.channel_data = channel_data
    mid.scan = scan
    mid.dimension = Dimension.both
    mid.receive_apodization.window = Window.tukey50
    mid.receive_apodization.f_number = 1.7
    mid.transmit_apodization.window = Window.tukey50
    mid.transmit_apodization.f_number = 1.7
    b_data = mid.go()

    fig, ax = b_data.plot(title="PICMUS Experiment Contrast")
    os.makedirs(OUTPUT_PATH, exist_ok=True)
    output_file = os.path.join(OUTPUT_PATH, "picmus_exp_contrast.png")
    fig.savefig(output_file, dpi=150, bbox_inches="tight")
    print(f"Image saved to {output_file}")
    return b_data


if __name__ == "__main__":
    main()
    plt.show()
