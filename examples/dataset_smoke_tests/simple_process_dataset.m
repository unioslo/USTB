function R = simple_process_dataset(uff_file, varargin)
%SIMPLE_PROCESS_DATASET  Minimal download + one processing step for one UFF dataset.
%
%   R = SIMPLE_PROCESS_DATASET(UFF_FILE)
%   R = SIMPLE_PROCESS_DATASET(..., 'channel_h5', '/channel_data', 'mode', 'beamform')
%
%   mode:
%     'beamform'        — load uff.channel_data, run midprocess.das, optional plot
%     'beamformed_only' — load first uff.beamformed_data group, show stored image
%
%   R fields: ok (logical), message (char), mode, filename, b_data (optional)

p = inputParser;
addParameter(p, 'channel_h5', '', @(s) ischar(s) || isstring(s));
addParameter(p, 'mode', 'beamform', @(s) any(strcmpi(s, {'beamform', 'beamformed_only'})));
addParameter(p, 'plot', false, @islogical);
addParameter(p, 'return_b_data', false, @islogical);
parse(p, varargin{:});

mode = lower(char(p.Results.mode));
want_plot = p.Results.plot;
preferred_ch = char(p.Results.channel_h5);
want_bd = p.Results.return_b_data;

R = struct('ok', false, 'message', '', 'mode', mode, 'filename', '', 'b_data', []);

[~, fn] = fileparts(uff_file);
R.filename = [fn '.uff'];

if exist(uff_file, 'file') ~= 2
    R.message = sprintf('File not found: %s', uff_file);
    return
end

repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repo_root, 'examples', 'dataset_catalog_previews'));

try
    b_data = dataset_preview_beamform(uff_file);

    if want_plot
        b_data.plot([], R.filename);
    end

    img = b_data.get_image('none');
    R.ok = true;
    R.message = sprintf('OK, max(abs(image))=%g', max(abs(img(:))));
    if want_bd
        R.b_data = b_data;
    end
catch ME
    R.message = ME.message;
end
end
