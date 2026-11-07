%% ULM of the PALA in vivo rat brain data with the shared ULM pipeline
%
% Same processing as ULM_ULMShare_pipeline_example.m, only the data loading
% and the dataset-dependent parameters differ. Run
% examples/ulm/OPLUM_data_preparation_RatBrain.m first to create
% data/RF_channeldata/InVivoRatBrain_###.uff and data/InVivoRatBrain_scan.uff.
%
% Data: Heiles et al. (2022), PALA, https://zenodo.org/records/7883227

clear all; close all;
addpath(fullfile(ustb_path(), 'sandbox', 'ulm_pipeline'));

local_path = fullfile(ustb_path(), 'data');
files = dir(fullfile(local_path, 'RF_channeldata', 'InVivoRatBrain_*.uff'));
track_folder = fullfile(local_path, 'tracks_RatBrain');
if ~exist(track_folder, 'dir'), mkdir(track_folder); end

% PALA grid (lambda x lambda) upsampled to lambda/2, as in Simon A. Bjørn's
% master's thesis, Figure 5.1 (http://hdl.handle.net/10852/120821)
scan = uff.read_object(fullfile(local_path, 'InVivoRatBrain_scan.uff'), '/scan');
scan = tools.scan_integer_upscale(scan, 2);

%% Dataset-dependent parameters
p = ulm_pipeline_parameters();
p.framerate = 1000;             % [Hz] compounded frame rate of PALA
p.svd_cutoff = 5;               % removes the first 4 of 800 components
p.receive_window = uff.window.hamming;
p.batch_size = 20;
p.use_lag1 = false;             % try true to compare with ULMShare
p.number_of_particles = 90;     % as PALA
p.max_linking_distance = 3;     % [lambda]

%% Process one buffer (file) at a time; existing tracks are reused
for n = 1:numel(files)
    track_file = fullfile(track_folder, sprintf('tracks_%03d.mat', n));
    if exist(track_file, 'file'), continue; end

    channel_data = uff.read_object(fullfile(files(n).folder, files(n).name), '/channel_data');
    out = ulm_process_buffer(channel_data, scan, p);
    save(track_file, '-struct', 'out');
    fprintf('File %d/%d done\n', n, numel(files));
end

%% Render
ulm_pipeline_show(track_folder, scan, p, 'PALA rat brain');
