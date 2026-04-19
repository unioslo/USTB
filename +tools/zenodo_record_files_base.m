function base = zenodo_record_files_base(record_id)
%ZENODO_RECORD_FILES_BASE  Base URL .../files for any Zenodo record.
%   Use when a dataset lives in a Zenodo deposit other than the main USTB
%   bundle (see tools.zenodo_dataset_files_base).
%
%   RECORD_ID is the numeric id from the record URL, e.g. for
%   https://zenodo.org/records/19651299 use '19651299' or 19651299.
%
%   Example:
%     fn = 'STAI_UFF_CIRS_phantom.uff';
%     tools.download(fn, tools.zenodo_record_files_base('19651299'), data_path());
%     uff_file = fullfile(data_path(), fn);
%
%   The download URL is built as [base '/' filename] (see tools.download).

if isnumeric(record_id)
    record_id = sprintf('%d', record_id);
end
record_id = char(strtrim(string(record_id)));
base = ['https://zenodo.org/records/' record_id '/files'];
end
