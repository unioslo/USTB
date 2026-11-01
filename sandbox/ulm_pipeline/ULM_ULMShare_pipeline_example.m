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

% Beamforming grid of the ULMShare reference processing (25 um, ~lambda/4)
scan = uff.linear_scan();
scan.x_axis = (-5e-3:25e-6:5e-3-25e-6).';
scan.z_axis = (0.5e-3:25e-6:8.5e-3-25e-6).';

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
% openhrf_to_uff gives the ULMShare plane waves the transmit delay
% -(D/2)|sin a|/c. The angle images only line up in depth with 1.2 times
% that (residual axial shift 2-3 um rms instead of 11-12 um), where the
% compounding gain also peaks; the cause is not known.
channel_data = openhrf_to_uff(buffer_file);
D = max(channel_data.probe.x) - min(channel_data.probe.x);
seq = channel_data.sequence;
for k = 1:numel(seq)
    seq(k).delay = -1.2*(D/2)*abs(sin(seq(k).source.azimuth))/channel_data.sound_speed;
end
channel_data.sequence = seq;
end
