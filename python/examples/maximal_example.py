"""Maximal example: demonstrating preprocessing, DAS, and postprocessing.

Python equivalent of examples/UiO_course/.../maximal_example.m.
Pipeline: demodulation -> DAS (transmit dimension) -> coherence factor -> median filter.
"""

import numpy as np
import matplotlib
matplotlib.use("Agg")

from examples.utils import read_channel_data, save_image
from pyuff_ustb.objects import SectorScan
from pyuff_ustb.objects.point import Point
from ustb.preprocess import FastDemodulation
from ustb.midprocess import DAS
from ustb.postprocess import CoherenceFactor, Median
from ustb.enums import Dimension, Window


def main():
    channel_data = read_channel_data("Verasonics_P2-4_parasternal_long_small.uff")
    print(f"Channel data: {channel_data.N_samples} samples, "
          f"{channel_data.N_channels} channels, "
          f"{channel_data.N_waves} waves, {channel_data.N_frames} frames")

    sequence = channel_data.sequence
    if not isinstance(sequence, (list, tuple)):
        sequence = [sequence]

    depth_axis = np.linspace(0e-3, 110e-3, 1024)
    azimuth_axis = np.linspace(
        float(sequence[0].source.azimuth),
        float(sequence[-1].source.azimuth),
        len(sequence),
    )
    scan = SectorScan()
    scan.__dict__["azimuth_axis"] = azimuth_axis
    scan.__dict__["depth_axis"] = depth_axis
    origin = Point()
    origin.__dict__["distance"] = 0.0
    origin.__dict__["azimuth"] = 0.0
    origin.__dict__["elevation"] = 0.0
    scan.__dict__["origin"] = origin

    # Step 1: Demodulation
    print("Step 1: Demodulation...")
    demod = FastDemodulation()
    demod.modulation_frequency = float(channel_data.pulse.center_frequency)
    demod.input = channel_data
    channel_data_demod = demod.go()
    print(f"  Demodulated: {channel_data_demod.N_samples} samples, "
          f"fc={channel_data_demod.modulation_frequency/1e6:.1f} MHz")

    # Step 2: DAS beamforming (transmit dimension only — keep Rx channels)
    print("Step 2: DAS (dimension=transmit)...")
    mid = DAS()
    mid.channel_data = channel_data_demod
    mid.scan = scan
    mid.dimension = Dimension.transmit
    mid.transmit_apodization.window = Window.scanline
    mid.receive_apodization.window = Window.none
    b_data = mid.go()
    print(f"  Beamformed: {b_data.data.shape}")

    # Step 3: Coherence factor
    print("Step 3: Coherence factor...")
    cf = CoherenceFactor()
    cf.dimension = Dimension.receive
    cf.input = b_data
    b_data_cf = cf.go()
    print(f"  CF output: {b_data_cf.data.shape}")

    # Step 4: Median filter
    print("Step 4: Median filter...")
    me = Median()
    me.m = 5
    me.n = 5
    me.input = b_data_cf
    b_data_me = me.go()
    print(f"  Median output: {b_data_me.data.shape}")

    fig, ax = b_data_me.plot(title="Human Heart (Maximal Example)", dynamic_range=80)
    save_image(fig, "maximal_example.png")
    return b_data_me


if __name__ == "__main__":
    main()
