function base = zenodo_dataset_files_base()
%ZENODO_DATASET_FILES_BASE  Base URL for USTB datasets hosted on Zenodo.
%
%   Returns the .../files path without a trailing slash. Pass to tools.download
%   as the second argument together with a filename:
%     tools.download(filename, tools.zenodo_dataset_files_base(), data_path);
%
%   Record: https://zenodo.org/records/20261898
%   Update this function if the deposit version or record ID changes.

base = 'https://zenodo.org/records/20261898/files';
end
