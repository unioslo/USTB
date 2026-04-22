function base = zenodo_dataset_files_base()
%ZENODO_DATASET_FILES_BASE  Base URL for USTB example datasets hosted on Zenodo.
%
%   Returns the .../files path without a trailing slash. Pass to tools.download
%   as the second argument together with a filename:
%     tools.download(filename, tools.zenodo_dataset_files_base(), data_path);
%
%   Record: https://zenodo.org/records/19550715 — update this function if the
%   deposit version or record ID changes. For files in *other* Zenodo records,
%   use tools.zenodo_record_files_base(record_id) instead.
%
%   Not every historical example .uff is in this record; upload a new Zenodo version
%   to add files. Current bundle (non-exhaustive): L7_FI_IUS2018, P4_FI_121444_45mm_focus,
%   PICMUS_* subset, FieldII_P4_point_scatterers, Alpinion L3-8 CPWC/FI, etc.

base = 'https://zenodo.org/records/19550715/files';
end
