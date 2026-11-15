%% Effect of the clutter-filter placement on a single in vivo B-mode frame
%
% Beamforms one chunk of the rat-brain data in three ways and saves one
% frame of each:
%
%   invivo/svd/das_SVD.jpg        DAS, SVD filter on the RF channel data
%   invivo/svd/cf_SVD_after.jpg   CF, SVD filter on the beamformed CF images
%   invivo/svd/cf_SVD.jpg         CF, SVD filter on the RF channel data
%
% and, for reference, the unfiltered frames das_noSVD.jpg and cf_noSVD.jpg.
% DAS is linear, so filtering before or after beamforming is equivalent.
% The coherence factor is not: when the clutter is still in the channel
% data, the tissue echoes dominate the coherence estimate.

addpath(fileparts(mfilename('fullpath')));
cfg = ulm_paper_config();
set(groot, 'defaultAxesToolbarVisible', 'off'); % keep the toolbar out of exported figures
out_path = fullfile(cfg.figure_path, 'invivo', 'svd');
if ~exist(out_path, 'dir'), mkdir(out_path); end

chunk_i       = 1;
frame         = 100;  % frame shown
dynamic_range = 60;   % [dB]

[channel_data, scan] = invivo_load_chunk(cfg, chunk_i);
scan = tools.scan_integer_upscale(scan, cfg.invivo.upscale);

%% No clutter filter, and SVD filter after beamforming
% All frames are beamformed, since the filter works along slow time.
[b_das, b_cf] = beamform_das_cf(channel_data, scan, cfg.invivo.f_number, ...
    cfg.window, cfg.frames_per_batch);

svd_after = postprocess.svd_filter();
svd_after.input  = b_cf;
svd_after.cutoff = cfg.invivo.svd_cutoff;
b_cf_svd_after = svd_after.go();

%% SVD filter on the channel data, before beamforming
svd_before = preprocess.svd_filter();
svd_before.input  = channel_data;
svd_before.cutoff = cfg.invivo.svd_cutoff;
filtered = svd_before.go();
[b_das_svd, b_cf_svd] = beamform_das_cf(filtered, scan, cfg.invivo.f_number, ...
    cfg.window, cfg.frames_per_batch, frame);

%% Save the frames
panels = {
    b_das.data(:, 1, 1, frame),          'DAS without SVD',               'das_noSVD.jpg'
    b_cf.data(:, 1, 1, frame),           'CF without SVD',                'cf_noSVD.jpg'
    b_das_svd.data,                      'DAS with SVD',                  'das_SVD.jpg'
    b_cf_svd_after.data(:, 1, 1, frame), 'CF with SVD (SVD after BF)',    'cf_SVD_after.jpg'
    b_cf_svd.data,                       'CF with SVD (SVD before BF)',   'cf_SVD.jpg'};
for i = 1:size(panels, 1)
    envelope = reshape(abs(panels{i, 1}), scan.N_z_axis, scan.N_x_axis);
    fig = figure('Color', 'w', 'Position', [50 50 750 620]);
    imagesc(scan.x_axis*1e3, scan.z_axis*1e3, 20*log10(envelope/max(envelope(:))), [-dynamic_range 0]);
    axis image; colormap(gray); colorbar;
    xlabel('x [mm]'); ylabel('z [mm]'); title(panels{i, 2}); set(gca, 'FontSize', 13);
    exportgraphics(fig, fullfile(out_path, panels{i, 3}), 'Resolution', 200);
end
