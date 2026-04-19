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
%   Files covered by examples (non-exhaustive): Verasonics_P2-4_parasternal_long_small,
%   L7_FI_IUS2018, Alpinion CPWC/FI, FieldII_P4_point_scatterers, P4_FI_121444_45mm_focus,
%   PICMUS_carotid_cross, PICMUS_simulation_contrast_speckle, PICMUS_numerical_calib_v2,
%   PICMUS_2_CPWC_numerical_simulated_phantom (present on Zenodo; not referenced in USTB yet).

base = 'https://zenodo.org/records/19550715/files';
end
