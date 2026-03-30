"""Shared utilities for examples."""

import os
import urllib.request
import numpy as np

DATA_URL = "https://www.ustb.no/datasets/"
DATA_PATH = os.path.join(os.path.dirname(__file__), "..", "..", "data")


def download_dataset(filename):
    """Download dataset if not already present, return full path."""
    filepath = os.path.join(DATA_PATH, filename)
    if os.path.exists(filepath):
        return filepath
    os.makedirs(DATA_PATH, exist_ok=True)
    url = DATA_URL + filename
    print(f"Downloading {url} ...")
    urllib.request.urlretrieve(url, filepath)
    print(f"Saved to {filepath}")
    return filepath


def read_channel_data(filename):
    """Download and read channel data from a UFF file."""
    from pyuff_ustb.objects.uff import Uff
    filepath = download_dataset(filename)
    uff_file = Uff(filepath)
    return uff_file.read("channel_data")


def read_uff_object(filename, name):
    """Read any object from a UFF file."""
    from pyuff_ustb.objects.uff import Uff
    filepath = download_dataset(filename)
    uff_file = Uff(filepath)
    return uff_file.read(name)


def make_linear_scan(channel_data, N_x=256, N_z=256, z_max=50e-3):
    """Create a linear scan from channel data probe geometry."""
    from pyuff_ustb.objects import LinearScan
    probe_x = channel_data.probe.x
    scan = LinearScan()
    scan.__dict__["x_axis"] = np.linspace(float(probe_x.min()), float(probe_x.max()), N_x)
    scan.__dict__["z_axis"] = np.linspace(0, z_max, N_z)
    return scan


def save_image(fig, name):
    """Save figure to examples output directory."""
    outdir = os.path.join(os.path.dirname(__file__), "output")
    os.makedirs(outdir, exist_ok=True)
    path = os.path.join(outdir, name)
    fig.savefig(path, dpi=150, bbox_inches="tight")
    print(f"Image saved to {path}")
    return path
