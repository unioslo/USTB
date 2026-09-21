"""Unit tests for ustb.tools.download."""

import os
import pathlib

import pytest
from ustb.tools import download, zenodo_dataset_files_base


class TestZenodoDatasetFilesBase:
    def test_should_return_files_url_without_trailing_slash(self):
        base = zenodo_dataset_files_base()
        assert base.startswith("https://zenodo.org/records/")
        assert base.endswith("/files")
        assert not base.endswith("//files")


class TestDownload:
    def test_should_download_file_when_missing(self, tmp_path):
        src_dir = tmp_path / "src"
        src_dir.mkdir()
        src_file = src_dir / "data.txt"
        src_file.write_text("hello world")

        dest_file = tmp_path / "dest" / "data.txt"
        url = src_file.as_uri()

        result = download(str(dest_file), url)

        assert result == str(dest_file)
        assert dest_file.exists()
        assert dest_file.read_text() == "hello world"

    def test_should_skip_download_when_file_already_present(self, tmp_path):
        dest_file = tmp_path / "data.txt"
        dest_file.write_text("already here")

        # A URL that would fail to resolve, to prove it was never touched.
        result = download(str(dest_file), "file:///does/not/exist.txt")

        assert result == str(dest_file)
        assert dest_file.read_text() == "already here"

    def test_should_support_legacy_three_argument_signature(self, tmp_path):
        src_dir = tmp_path / "src"
        src_dir.mkdir()
        src_file = src_dir / "legacy.uff"
        src_file.write_text("legacy data")

        dest_dir = tmp_path / "data"
        base_url = src_dir.as_uri() + "/"  # trailing slash should be stripped

        result = download("legacy.uff", base_url, str(dest_dir))

        expected = os.path.join(str(dest_dir), "legacy.uff")
        assert result == expected
        assert pathlib.Path(expected).read_text() == "legacy data"

    def test_should_create_destination_directory_if_missing(self, tmp_path):
        src_file = tmp_path / "src.txt"
        src_file.write_text("x")
        dest_file = tmp_path / "nested" / "sub" / "dest.txt"

        download(str(dest_file), src_file.as_uri())

        assert dest_file.exists()
