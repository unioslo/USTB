%% ULM of the OpenH-RF ULMShare mouse brain data with the shared ULM pipeline
%
% Same processing as ULM_PALA_pipeline_example.m, only the data loading and
% the dataset-dependent parameters differ. Download the buffers first, see
% sandbox/OpenHRF/ULMShare_ULM_example.m.
%
% Data: Rauby et al. (2026), ULMShare, doi:10.20383/103.01550 (CC BY 4.0)

clear all; close all;
addpath(fullfile(ustb_path(), 'sandbox', 'ulm_pipeline'));
addpath(fullfile(ustb_path(), 'sandbox', 'OpenHRF'));   % openhrf_to_uff

data_folder = fullfile(ustb_path(), 'sandbox', 'OpenHRF', 'Data', 'OpenH-RF', 'ulmshare', 'mouse_16_acquisition_1');
track_folder = fullfile(data_folder, 'tracks');
if ~exist(track_folder, 'dir'), mkdir(track_folder); end
buffers = 50;                   % 50:149 for the full Grade A acquisition

% Beamforming grid: 25 um axially as the ULMShare reference processing,
% 31.25 um laterally. fwhm and normalization_sigma are in pixels and were
% set on the earlier 80 um pitch geometry, whose 25 um lateral pixels were
% 31.25 um wide in reality.
scan = uff.linear_scan();
scan.x_axis = (-5e-3:31.25e-6:5e-3-31.25e-6).';
% With the +2.56 us time offset everything is ~2 mm deeper than in the
% ULMShare processing (skull top ~2.7 mm, skull base of mouse 16 ~9 mm)
scan.z_axis = (2.5e-3:25e-6:10e-3-25e-6).';

%% Dataset-dependent parameters
p = ulm_pipeline_parameters();
p.svd_cutoff = 0.15;            % removes the first 59 of 400 components (ULMShare: 0.05)
p.receive_window = uff.window.hanning;
p.batch_size = 10;
p.use_lag1 = true;              % as ULMShare
p.number_of_particles = 300;
p.max_linking_distance = 1.5;   % [lambda] (~150 mm/s at 1 kHz)

%% Process one buffer at a time; existing tracks are reused
for n_buffer = buffers
    track_file = fullfile(track_folder, sprintf('tracks_%03d.mat', n_buffer));
    if exist(track_file, 'file'), continue; end
    buffer_file = fullfile(data_folder, sprintf('buffer_%03d.hdf5', n_buffer));
    if ~exist(buffer_file, 'file')
        warning('Missing %s, skipping.', buffer_file);
        continue;
    end

    channel_data = load_buffer(buffer_file);
    p.framerate = channel_data.PRF;     % frame rate stored by openhrf_to_uff
    out = ulm_process_buffer(channel_data, scan, p);
    save(track_file, '-struct', 'out');
    fprintf('Buffer %d done\n', n_buffer);
end

%% Render
ulm_pipeline_show(track_folder, scan, p, 'ULMShare mouse 16');

function channel_data = load_buffer(buffer_file)
% openhrf_to_uff corrects the ULMShare geometry (100 um pitch, +2.56 us
% receive time offset); the stored 1540 m/s is kept
channel_data = openhrf_to_uff(buffer_file);
end
