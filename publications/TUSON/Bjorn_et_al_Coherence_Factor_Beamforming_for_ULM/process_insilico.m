%% DAS and CF beamforming + ULM on the OPULM in silico flow simulation
%
% Processes the 20 chunks (1000 frames each) of the PALA in silico flow RF
% data. For every chunk:
%
% # white Gaussian noise is added to the RF channel data (10 dB SNR),
% # the data is beamformed at lambda/2 with DAS and with the coherence factor,
% # bubbles are localized and tracked with the tuned parameters of each
%   beamformer (ulm_paper_config),
% # localizations are paired with the ground truth (TP, FN, FP per frame).
%
% One result file per chunk is written to cfg.results_path, and chunks that
% already have a result file are skipped, so the script can be stopped and
% restarted. figures_insilico.m turns the result files into the figures.
%
% Set the variable |chunks| before running to process a subset, for example
% |chunks = 1; process_insilico|.

addpath(fileparts(mfilename('fullpath')));
cfg = ulm_paper_config();
if ~exist('chunks', 'var'), chunks = cfg.insilico.chunks; end

for chunk_i = chunks
    result_file = fullfile(cfg.results_path, sprintf('insilico_chunk_%02d.mat', chunk_i));
    if exist(result_file, 'file')
        fprintf('In silico chunk %d: already processed, skipping.\n', chunk_i);
        continue
    end
    t_chunk = tic;
    fprintf('In silico chunk %d: loading ... ', chunk_i);
    [channel_data, scan_native, ground_truth] = insilico_load_chunk(cfg, chunk_i);

    % Noise goes into the RF data, so that it enters the coherence estimate
    rng(chunk_i); % reproducible noise realization per chunk
    channel_data.data = add_white_noise(channel_data.data, cfg.insilico.snr_db);

    fprintf('beamforming ... ');
    scan = tools.scan_integer_upscale(scan_native, cfg.insilico.upscale);
    [b_data.das, b_data.cf] = beamform_das_cf(channel_data, scan, ...
        cfg.insilico.f_number, cfg.window, cfg.frames_per_batch);

    fprintf('ULM ... ');
    result = struct('chunk', chunk_i, 'lambda', channel_data.lambda, ...
        'scan_x_axis', scan.x_axis, 'scan_z_axis', scan.z_axis);
    for name = ["das", "cf"]
        prm = cfg.tuned.(name);
        prm.numberOfParticles = cfg.insilico.numberOfParticles;
        [tracks, tracks_interp, u] = run_ulm(b_data.(name), scan, ...
            channel_data.lambda, cfg.insilico.framerate, cfg.ulm, prm);

        % [N_true, N_localized, TP, FN, FP] per frame, and the errors of the
        % paired localizations [distance, dz, dx] in metres
        [stats, errors] = u.pairing(cell2mat(tracks), ground_truth);

        result.(name) = struct('tracks', {tracks}, 'tracks_interp', {tracks_interp}, ...
            'stats', stats, 'errors', errors, 'parameters', prm);
    end
    save(result_file, '-struct', 'result', '-v7.3');

    jaccard = @(s) 100*sum(s(:,3))/sum(s(:,3) + s(:,4) + s(:,5));
    fprintf('done in %.0f s. Jaccard DAS %.1f %%, CF %.1f %%\n', toc(t_chunk), ...
        jaccard(result.das.stats), jaccard(result.cf.stats));
    clear channel_data b_data
end

function data = add_white_noise(data, snr_db)
% Add complex white Gaussian noise so that the ratio of the mean signal
% power to the noise power is snr_db.
noise_power = mean(abs(data(:)).^2)/10^(snr_db/10);
noise = sqrt(noise_power/2)*(randn(size(data), 'like', real(data)) ...
    + 1j*randn(size(data), 'like', real(data)));
data = data + noise;
end
