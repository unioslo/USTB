%% Generate DAS beamformed labels for all USTB datasets (OpenH-RF contribution)
%
% Produces reference B-mode images (DAS, coherent compounding) for each dataset
% that has channel_data. Output: .mat files with the beamformed envelope.
%
% Usage:
%   addpath(genpath(ustb_path()));
%   run('sandbox/OpenHRF/generate_labels.m');

clear; close all;

output_dir = fullfile(fileparts(mfilename('fullpath')), 'labels');
if ~isfolder(output_dir)
    mkdir(output_dir);
end

url = tools.zenodo_dataset_files_base();
local_path = data_path();

datasets = {
    'Verasonics_P2-4_parasternal_long_small.uff'
    'L7_CPWC_193328.uff'
    'L7_FI_IUS2018.uff'
    'PICMUS_experiment_resolution_distortion.uff'
    'PICMUS_simulation_resolution_distortion.uff'
    'PICMUS_experiment_contrast_speckle.uff'
    'PICMUS_simulation_contrast_speckle.uff'
    'PICMUS_carotid_cross.uff'
    'PICMUS_carotid_long.uff'
    'Alpinion_L3-8_FI_hypoechoic.uff'
    'Alpinion_L3-8_FI_hyperechoic_scatterers.uff'
    'Alpinion_L3-8_CPWC_hypoechoic.uff'
    'Alpinion_L3-8_CPWC_hyperechoic_scatterers.uff'
    'FieldII_STAI_uniform_fov.uff'
    'FieldII_CPWC_point_scatterers_res_v2.uff'
    'L7_CPWC_TheGB.uff'
    'L7_FI_TheGB.uff'
    'L7_DW_TheGB.uff'
    'L7_STA_TheGB.uff'
    'ARFI_dataset.uff'
    'SWE_L7_type_I.uff'
    'P4_FI_121444_45mm_focus.uff'
    'STAI_UFF_CIRS_phantom.uff'
    };

fprintf('=== OpenH-RF Label Generation (DAS beamforming) ===\n');
fprintf('Output: %s\n\n', output_dir);

for k = 1:numel(datasets)
    fn = datasets{k};
    fprintf('[%02d/%02d] %s ... ', k, numel(datasets), fn);

    try
        tools.download(fn, url, local_path);
        channel_data = uff.read_object(fullfile(local_path, fn), '/channel_data');

        scan = default_scan(channel_data);

        mid = midprocess.das();
        mid.channel_data = channel_data;
        mid.scan = scan;
        mid.dimension = dimension.both();
        mid.receive_apodization.window = uff.window.hanning;
        mid.receive_apodization.f_number = 1.75;
        mid.transmit_apodization.window = uff.window.hanning;
        mid.transmit_apodization.f_number = 1.75;

        b_data = mid.go();

        envelope = b_data.get_image('none');
        label_file = fullfile(output_dir, strrep(fn, '.uff', '_label.mat'));
        save(label_file, 'envelope', 'scan', '-v7.3');
        fprintf('OK\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    close all;
end

fprintf('\nDone.\n');


function scan = default_scan(channel_data)
    if isprop(channel_data.sequence(1).source, 'azimuth') && ...
            ~isempty(channel_data.sequence(1).source.azimuth) && ...
            abs(channel_data.sequence(1).source.azimuth) > 0.01
        az = zeros(channel_data.N_waves, 1);
        for n = 1:channel_data.N_waves
            az(n) = channel_data.sequence(n).source.azimuth;
        end
        scan = uff.sector_scan('azimuth_axis', az, ...
            'depth_axis', linspace(0, 110e-3, 512).');
    else
        x_range = max(channel_data.probe.x) - min(channel_data.probe.x);
        scan = uff.linear_scan(...
            'x_axis', linspace(-x_range/2, x_range/2, 256).', ...
            'z_axis', linspace(0, 50e-3, 256).');
    end
end
