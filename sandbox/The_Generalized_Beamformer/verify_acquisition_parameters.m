%% Verify acquisition parameters for manuscript red placeholders
% Run this script to confirm:
%   - Sampling frequency (claimed 20.8 MHz = 4x center)
%   - PW/DW steering angles (claimed -16 to 16 degrees)
%   - P4-2 probe specs (claimed 64 elements, 2.5 MHz center)
%   - Number of transmits per sequence

clear all; close all;

%% L7-4 datasets (Figure 5: PW, DW, STA, FI)
url = tools.zenodo_dataset_files_base();

L7_files = {'L7_CPWC_TheGB.uff', 'L7_DW_TheGB.uff', ...
            'L7_STA_TheGB.uff',  'L7_FI_TheGB.uff'};
labels   = {'PW (CPWC)', 'DW', 'STA', 'FI'};

fprintf('\n========== L7-4 PROBE DATASETS ==========\n');
for f = 1:length(L7_files)
    tools.download(L7_files{f}, url, data_path);
    ch = uff.read_object([data_path filesep L7_files{f}], '/channel_data');

    fprintf('\n--- %s (%s) ---\n', labels{f}, L7_files{f});
    fprintf('  Probe N_elements:       %d\n', ch.probe.N_elements);
    fprintf('  Probe pitch:            %.4f mm\n', ch.probe.pitch*1e3);
    fprintf('  Sound speed:            %.1f m/s\n', ch.sound_speed);
    fprintf('  Sampling frequency:     %.4f MHz\n', ch.sampling_frequency/1e6);
    fprintf('  N_waves (transmits):    %d\n', ch.N_waves);
    center_freq = double(ch.sound_speed) / double(ch.lambda);
    fprintf('  Center frequency (c/lambda): %.4f MHz\n', center_freq/1e6);

    % Extract steering angles from sequence
    angles_deg = zeros(1, ch.N_waves);
    for w = 1:ch.N_waves
        src = ch.sequence(w).source;
        if isinf(src.distance)
            % Plane wave: azimuth angle
            angles_deg(w) = src.azimuth * 180/pi;
        elseif src.distance > 0
            % Diverging/focused: azimuth of virtual source
            angles_deg(w) = atan2(src.x, src.z) * 180/pi;
        else
            angles_deg(w) = NaN;
        end
    end
    if ~all(isnan(angles_deg))
        fprintf('  Steering angles:        [%.2f, %.2f] degrees\n', ...
            min(angles_deg), max(angles_deg));
    end
end

%% P4-2 dataset (coherence factor / transmit wave apodization figure)
fprintf('\n\n========== P4-2 PROBE DATASET ==========\n');
p4_file = 'P4_FI_121444_45mm_focus.uff';
local_path = [ustb_path(), '/data/'];

if exist([local_path, p4_file], 'file')
    ch_p4 = uff.read_object([local_path, p4_file], '/channel_data');

    fprintf('\n--- P4-2 FI (%s) ---\n', p4_file);
    fprintf('  Probe N_elements:       %d\n', ch_p4.probe.N_elements);
    fprintf('  Probe pitch:            %.4f mm\n', ch_p4.probe.pitch*1e3);
    fprintf('  Sound speed:            %.1f m/s\n', ch_p4.sound_speed);
    fprintf('  Sampling frequency:     %.4f MHz\n', ch_p4.sampling_frequency/1e6);
    fprintf('  N_waves (transmits):    %d\n', ch_p4.N_waves);
    center_freq_p4 = double(ch_p4.sound_speed) / double(ch_p4.lambda);
    fprintf('  Center frequency (c/lambda): %.4f MHz\n', center_freq_p4/1e6);
else
    fprintf('  File not found: %s\n', [local_path, p4_file]);
    fprintf('  Try downloading it first or check the path.\n');
end

fprintf('\n========== VERIFICATION COMPLETE ==========\n');
fprintf('Compare above values against manuscript red placeholders:\n');
fprintf('  - Sampling freq: should be ~20.8 MHz (4x 5.2 MHz center)\n');
fprintf('  - PW/DW angles:  should span -16 to +16 degrees\n');
fprintf('  - P4-2 elements: should be 64\n');
fprintf('  - P4-2 center:   should be ~2.5 MHz\n');
