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
        print(f"Using existing {dest}")
        return dest

    dest_dir = os.path.dirname(dest)
    if dest_dir and not os.path.exists(dest_dir):
        os.makedirs(dest_dir, exist_ok=True)

    print("USTB download tool")
    print(f"File:\t\t{os.path.basename(dest)}")
    print(f"URL:\t\t{src_url}")
    print(f"Path:\t\t{dest_dir or '.'}")

    # Download to a temporary name so an interrupted download is not mistaken
    # for a complete file on the next run
    partial = dest + ".part"
    try:
        urllib.request.urlretrieve(src_url, partial, reporthook=_ProgressPrinter())
    except BaseException:
        if os.path.exists(partial):
            os.remove(partial)
        raise
    os.replace(partial, dest)
    print(f"\nDownloaded {dest}")
    return dest


class _ProgressPrinter:
    """urlretrieve reporthook printing the download progress on one line."""

    def __init__(self):
        self.last_percent = -1

    def __call__(self, block_count, block_size, total_size):
        done_mb = block_count * block_size / 1e6
        if total_size <= 0:  # size unknown: report megabytes only
            print(f"\rDownloaded {done_mb:.1f} MB", end="", flush=True)
            return
        percent = min(100, int(100 * block_count * block_size / total_size))
        if percent != self.last_percent:
            self.last_percent = percent
            total_mb = total_size / 1e6
            print(
                f"\rDownloading {percent:3d}% ({min(done_mb, total_mb):.1f} / {total_mb:.1f} MB)",
                end="",
                flush=True,
            )
