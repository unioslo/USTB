function results = run_dataset_smoke_tests(varargin)
%RUN_DATASET_SMOKE_TESTS  Download and run simple processing on registered datasets.
%
%   RESULTS = RUN_DATASET_SMOKE_TESTS()
%   RESULTS = RUN_DATASET_SMOKE_TESTS('url', 'https://.../datasets/', ...
%       'plot', false, 'stop_on_error', false)
%
%   Walks UFF_DATASET_REGISTRY: for each entry, downloads the file to data_path()
%   (if missing) and runs SIMPLE_PROCESS_DATASET.
%
%   Requires network access on first run for each file.

p = inputParser;
addParameter(p, 'url', tools.zenodo_dataset_files_base(), @(s) ischar(s) || isstring(s));
addParameter(p, 'plot', false, @islogical);
addParameter(p, 'stop_on_error', false, @islogical);
parse(p, varargin{:});

base_url = char(p.Results.url);
if endsWith(base_url, '/')
    base_url = base_url(1:end-1);
end
want_plot = p.Results.plot;
stop_on_error = p.Results.stop_on_error;

local_path = data_path();
if local_path(end) ~= filesep
    local_path = [local_path filesep];
end

T = uff_dataset_registry();
n = numel(T);
results = repmat(struct('filename', '', 'ok', false, 'message', '', 'note', ''), n, 1);

fprintf('Dataset smoke tests: %d registered file(s), data_path=%s\n', n, local_path);

for i = 1:n
    fn = T(i).filename;
    results(i).filename = fn;
    results(i).note = T(i).note;

    try
        tools.download(fn, base_url, local_path);
    catch ME
        results(i).message = ['Download failed: ' ME.message];
        fprintf('[FAIL] %s — %s\n', fn, results(i).message);
        if stop_on_error
            return
        else
            continue
        end
    end

    uff_file = fullfile(local_path, fn);
    R = simple_process_dataset(uff_file, 'channel_h5', T(i).channel_h5, ...
        'mode', T(i).mode, 'plot', want_plot);

    results(i).ok = R.ok;
    results(i).message = R.message;

    if R.ok
        fprintf('[ OK ] %s — %s\n', fn, R.message);
    else
        fprintf('[FAIL] %s — %s\n', fn, R.message);
        if stop_on_error
            return
        end
    end
end

n_ok = sum([results.ok]);
fprintf('Finished: %d / %d succeeded.\n', n_ok, n);
end
