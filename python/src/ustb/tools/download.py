"""Dataset download helper matching MATLAB tools.download."""

import os
import urllib.request


def zenodo_dataset_files_base():
    """Base URL for USTB example datasets hosted on Zenodo.

    Mirrors MATLAB tools.zenodo_dataset_files_base(). Returns the .../files
    path without a trailing slash.

    Record: https://zenodo.org/records/20261898
    """
    return "https://zenodo.org/records/20261898/files"


def download(file, url, local_path=None):
    """Download a dataset from ``url`` to ``file`` if it is not already present.

    Mirrors MATLAB tools.download(file, url). If ``local_path`` is given,
    ``file`` is treated as just the filename: it is joined with ``url`` to
    build the source URL and with ``local_path`` to build the destination
    path, matching the legacy 3-argument MATLAB call signature.

    Example:
        url = tools.zenodo_dataset_files_base()
        tools.download("my_dataset.uff", url, data_path)
    """
    if local_path is not None:
        base = url.rstrip("/")
        src_url = f"{base}/{file}"
        dest = os.path.join(local_path, file)
    else:
        src_url = url
        dest = file

    if os.path.exists(dest):
        return dest

    dest_dir = os.path.dirname(dest)
    if dest_dir and not os.path.exists(dest_dir):
        os.makedirs(dest_dir, exist_ok=True)

    print("USTB download tool")
    print(f"File:\t\t{os.path.basename(dest)}")
    print(f"URL:\t\t{src_url}")
    print(f"Path:\t\t{dest_dir or '.'}")

    urllib.request.urlretrieve(src_url, dest)
    return dest
