%% DAS and CF beamforming + ULM on the OPULM in vivo rat-brain data
%
% Processes the 800-frame chunks of the PALA rat-brain RF data. For every
% chunk:
%
% # the RF channel data is clutter filtered with the SVD filter, before
%   beamforming, so that the coherence factor is estimated on bubble signal,
% # the data is beamformed at lambda/2 with DAS and with the coherence factor,
% # bubbles are localized and tracked with two parameter sets per beamformer:
%   the shared generic sheet and the simulation-tuned parameters.
%
% One result file per chunk is written to cfg.results_path, and chunks that
% already have a result file are skipped, so the script can be stopped and
% restarted. Chunks whose RF file is not on disk are skipped with a message.
% figures_invivo.m turns the result files into the figures.
%
% Set the variable |chunks| before running to process a subset, for example
% |chunks = 1:5; process_invivo|.

addpath(fileparts(mfilename('fullpath')));
cfg = ulm_paper_config();
if ~exist('chunks', 'var'), chunks = cfg.invivo.chunks; end

for chunk_i = chunks
    result_file = fullfile(cfg.results_path, sprintf('invivo_chunk_%03d.mat', chunk_i));
    if exist(result_file, 'file')
        fprintf('In vivo chunk %d: already processed, skipping.\n', chunk_i);
        continue
    end
    if ~exist(fullfile(cfg.invivo.rf_path, sprintf('RF_%03d.hdf5', chunk_i)), 'file')
        fprintf('In vivo chunk %d: RF file not found, skipping.\n', chunk_i);
        continue
    end
    t_chunk = tic;
    fprintf('In vivo chunk %d: loading ... ', chunk_i);
    [channel_data, scan] = invivo_load_chunk(cfg, chunk_i);
    scan = tools.scan_integer_upscale(scan, cfg.invivo.upscale);

    fprintf('SVD filter ... ');
    svd_filter = preprocess.svd_filter();
    svd_filter.input  = channel_data;
    svd_filter.cutoff = cfg.invivo.svd_cutoff;
    channel_data = svd_filter.go();

    fprintf('beamforming ... ');
    [b_data.das, b_data.cf] = beamform_das_cf(channel_data, scan, ...
        cfg.invivo.f_number, cfg.window, cfg.frames_per_batch);

    fprintf('ULM ... ');
    result = struct('chunk', chunk_i, 'lambda', channel_data.lambda, ...
        'scan_x_axis', scan.x_axis, 'scan_z_axis', scan.z_axis);
    for name = ["das", "cf"]
        parameter_sets = struct('generic', cfg.invivo.generic, 'tuned', cfg.invivo.tuned.(name));
        for sheet = ["generic", "tuned"]
            prm = parameter_sets.(sheet);
            [tracks, tracks_interp] = run_ulm(b_data.(name), scan, ...
                channel_data.lambda, cfg.invivo.framerate, cfg.ulm, prm);
            result.(name + "_" + sheet) = struct('tracks', {tracks}, ...
                'tracks_interp', {tracks_interp}, 'parameters', prm);
        end
    end
    save(result_file, '-struct', 'result', '-v7.3');
    fprintf('done in %.0f s.\n', toc(t_chunk));
    clear channel_data b_data svd_filter
end
