%% Convert USTB UFF datasets to OpenH-RF (zea) HDF5 format — MATLAB version
%
% Reads .uff files from Zenodo via tools.download and writes .hdf5 files
% in the OpenH-RF / zea data format.
%
% The zea HDF5 format stores:
%   /data/raw_data          — [frames, tx, samples, elements, 1] float32
%   /scan/probe_geometry    — [elements, 3] float32
%   /scan/sampling_frequency — scalar
%   /scan/center_frequency  — scalar
%   /scan/sound_speed       — scalar
%   /scan/polar_angles      — [tx, 1] float32
%   /scan/azimuth_angles    — [tx, 1] float32
%   /scan/focus_distances   — [tx, 1] float32
%   /scan/initial_times     — [tx, 1] float32
%   /scan/t0_delays         — [tx, elements] float32
%   /scan/tx_apodizations   — [tx, elements] float32
%   /scan/transmit_origins  — [tx, 3] float32
%   /metadata/probe_name    — string
%   /metadata/us_machine    — string
%   /metadata/description   — string
%   /metadata/credit        — string
%
% Usage:
%   addpath(genpath(ustb_path()));
%   run('sandbox/OpenHRF/convert_ustb_to_openh_rf_matlab.m');
%
% Or call the function directly:
%   convert_ustb_to_openh_rf_matlab('output_dir', './openh_rf_hdf5');

function convert_ustb_to_openh_rf_matlab(varargin)

p = inputParser;
addParameter(p, 'output_dir', fullfile(fileparts(mfilename('fullpath')), 'openh_rf_hdf5'), @ischar);
addParameter(p, 'limit', 0, @isnumeric);
parse(p, varargin{:});

output_dir = p.Results.output_dir;
limit = p.Results.limit;

if ~isfolder(output_dir)
    mkdir(output_dir);
end

url = tools.zenodo_dataset_files_base();
local_path = data_path();

datasets = get_dataset_list();
if limit > 0
    datasets = datasets(1:min(limit, numel(datasets)));
end

fprintf('=== USTB → OpenH-RF (zea HDF5) Conversion ===\n');
fprintf('Output: %s\n', output_dir);
fprintf('Datasets: %d\n\n', numel(datasets));

ok_count = 0;
for k = 1:numel(datasets)
    ds = datasets(k);
    fn = ds.filename;
    fprintf('[%02d/%02d] %s ... ', k, numel(datasets), fn);

    try
        tools.download(fn, url, local_path);
        uff_file = fullfile(local_path, fn);

        channel_data = uff.read_object(uff_file, '/channel_data');

        out_file = fullfile(output_dir, strrep(fn, '.uff', '.hdf5'));
        write_openh_rf_hdf5(out_file, channel_data, ds);

        fprintf('OK\n');
        ok_count = ok_count + 1;
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
end

fprintf('\n=== Done: %d/%d converted ===\n', ok_count, numel(datasets));
end


function write_openh_rf_hdf5(filepath, channel_data, meta)
%WRITE_OPENH_RF_HDF5  Write a single dataset in zea/OpenH-RF HDF5 format.

if isfile(filepath)
    delete(filepath);
end

% --- raw_data: reshape from UFF [samples, channels, waves, frames]
%               to zea [frames, tx, samples, elements, 1]
raw = single(channel_data.data);
sz = size(raw);
n_samples = sz(1);
n_channels = sz(2);
n_tx = 1; if ndims(raw) >= 3, n_tx = sz(3); end
n_frames = 1; if ndims(raw) >= 4, n_frames = sz(4); end

% Permute: MATLAB [samples, channels, tx, frames] → [frames, tx, samples, channels]
raw = permute(raw, [4, 3, 1, 2]);
raw = reshape(raw, [n_frames, n_tx, n_samples, n_channels, 1]);

h5create(filepath, '/data/raw_data', size(raw), 'Datatype', 'single');
h5write(filepath, '/data/raw_data', raw);

% --- scan parameters
n_el = channel_data.probe.N_elements;
probe_geom = zeros(n_el, 3, 'single');
probe_geom(:, 1) = single(channel_data.probe.x(:));
if ~isempty(channel_data.probe.y)
    probe_geom(:, 2) = single(channel_data.probe.y(:));
end
if ~isempty(channel_data.probe.z)
    probe_geom(:, 3) = single(channel_data.probe.z(:));
end

h5create(filepath, '/scan/probe_geometry', size(probe_geom), 'Datatype', 'single');
h5write(filepath, '/scan/probe_geometry', probe_geom);

h5create(filepath, '/scan/sampling_frequency', 1, 'Datatype', 'double');
h5write(filepath, '/scan/sampling_frequency', channel_data.sampling_frequency);

cf = 0;
if ~isempty(channel_data.pulse) && isprop(channel_data.pulse, 'center_frequency')
    cf = channel_data.pulse.center_frequency;
    if isempty(cf), cf = 0; end
end
h5create(filepath, '/scan/center_frequency', 1, 'Datatype', 'double');
h5write(filepath, '/scan/center_frequency', cf);

h5create(filepath, '/scan/sound_speed', 1, 'Datatype', 'double');
h5write(filepath, '/scan/sound_speed', channel_data.sound_speed);

% Per-transmit parameters
polar_angles = zeros(n_tx, 1, 'single');
azimuth_angles = zeros(n_tx, 1, 'single');
focus_distances = inf(n_tx, 1, 'single');
initial_times = zeros(n_tx, 1, 'single');
transmit_origins = zeros(n_tx, 3, 'single');

for i = 1:n_tx
    w = channel_data.sequence(i);
    if ~isempty(w.source) && ~isempty(w.source.azimuth)
        polar_angles(i) = single(w.source.azimuth);
    end
    if ~isempty(w.source) && isprop(w.source, 'elevation') && ~isempty(w.source.elevation)
        azimuth_angles(i) = single(w.source.elevation);
    end
    if ~isempty(w.source) && ~isempty(w.source.distance)
        focus_distances(i) = single(w.source.distance);
    end
    if ~isempty(w.delay)
        initial_times(i) = single(w.delay);
    end
    if ~isempty(w.source)
        transmit_origins(i, 1) = single(w.source.x);
        transmit_origins(i, 2) = single(w.source.y);
        transmit_origins(i, 3) = single(w.source.z);
    end
end

h5create(filepath, '/scan/polar_angles', [n_tx, 1], 'Datatype', 'single');
h5write(filepath, '/scan/polar_angles', polar_angles);
h5create(filepath, '/scan/azimuth_angles', [n_tx, 1], 'Datatype', 'single');
h5write(filepath, '/scan/azimuth_angles', azimuth_angles);
h5create(filepath, '/scan/focus_distances', [n_tx, 1], 'Datatype', 'single');
h5write(filepath, '/scan/focus_distances', focus_distances);
h5create(filepath, '/scan/initial_times', [n_tx, 1], 'Datatype', 'single');
h5write(filepath, '/scan/initial_times', initial_times);
h5create(filepath, '/scan/transmit_origins', [n_tx, 3], 'Datatype', 'single');
h5write(filepath, '/scan/transmit_origins', transmit_origins);

% t0_delays and tx_apodizations (default: zeros / ones)
h5create(filepath, '/scan/t0_delays', [n_tx, n_el], 'Datatype', 'single');
h5write(filepath, '/scan/t0_delays', zeros(n_tx, n_el, 'single'));
h5create(filepath, '/scan/tx_apodizations', [n_tx, n_el], 'Datatype', 'single');
h5write(filepath, '/scan/tx_apodizations', ones(n_tx, n_el, 'single'));

% --- metadata (as HDF5 attributes on root group)
h5writeatt(filepath, '/', 'probe_name', meta.probe);
h5writeatt(filepath, '/', 'us_machine', 'Verasonics / Alpinion / Field II simulation');
h5writeatt(filepath, '/', 'description', ...
    sprintf('USTB dataset: %s. %s. Tier: %s.', meta.filename, meta.view, meta.tier));
h5writeatt(filepath, '/', 'credit', 'USTB - UltraSound ToolBox (University of Oslo)');
h5writeatt(filepath, '/', 'anatomy', meta.anatomy);
h5writeatt(filepath, '/', 'tier', meta.tier);

end


function datasets = get_dataset_list()
%GET_DATASET_LIST  Return struct array of all USTB datasets for conversion.

datasets = struct('filename', {}, 'probe', {}, 'tier', {}, 'anatomy', {}, 'view', {});

datasets(end+1) = ds('Verasonics_P2-4_parasternal_long_subject_1.uff', 'P2-4', 'in-vivo-human', 'heart', 'parasternal long');
datasets(end+1) = ds('Verasonics_P2-4_parasternal_long_small.uff', 'P2-4', 'in-vivo-human', 'heart', 'parasternal long');
datasets(end+1) = ds('Verasonics_P2-4_apical_four_chamber_subject_1.uff', 'P2-4', 'in-vivo-human', 'heart', 'apical four-chamber');
datasets(end+1) = ds('L7_FI_carotid_cross_1.uff', 'L7-4', 'in-vivo-human', 'carotid', 'cross-section');
datasets(end+1) = ds('L7_FI_carotid_cross_2.uff', 'L7-4', 'in-vivo-human', 'carotid', 'cross-section');
datasets(end+1) = ds('L7_FI_carotid_cross_sub_2.uff', 'L7-4', 'in-vivo-human', 'carotid', 'cross-section');
datasets(end+1) = ds('PICMUS_carotid_long.uff', 'L7-4', 'in-vivo-human', 'carotid', 'longitudinal');
datasets(end+1) = ds('PICMUS_carotid_cross.uff', 'L7-4', 'in-vivo-human', 'carotid', 'cross-section');
datasets(end+1) = ds('PICMUS_experiment_resolution_distortion.uff', 'L7-4', 'phantom', 'CIRS phantom', 'resolution');
datasets(end+1) = ds('PICMUS_experiment_contrast_speckle.uff', 'L7-4', 'phantom', 'CIRS phantom', 'contrast');
datasets(end+1) = ds('experimental_STAI_dynamic_range.uff', 'L7-4', 'phantom', 'phantom', 'dynamic range');
datasets(end+1) = ds('experimental_dynamic_range_phantom.uff', 'L7-4', 'phantom', 'phantom', 'dynamic range');
datasets(end+1) = ds('STAI_UFF_CIRS_phantom.uff', 'L7-4', 'phantom', 'CIRS phantom', 'STA');
datasets(end+1) = ds('L7_CPWC_193328.uff', 'L7-4', 'phantom', 'phantom', 'CPWC');
datasets(end+1) = ds('L7_FI_IUS2018.uff', 'L7-4', 'phantom', 'phantom', 'focused imaging');
datasets(end+1) = ds('L7_FI_Verasonics.uff', 'L7-4', 'phantom', 'phantom', 'focused imaging');
datasets(end+1) = ds('L7_FI_Verasonics_CIRS.uff', 'L7-4', 'phantom', 'CIRS phantom', 'focused imaging');
datasets(end+1) = ds('L7_FI_Verasonics_CIRS_points.uff', 'L7-4', 'phantom', 'CIRS phantom', 'point targets');
datasets(end+1) = ds('Alpinion_L3-8_FI_hypoechoic.uff', 'L3-8', 'phantom', 'phantom', 'hypoechoic cyst');
datasets(end+1) = ds('Alpinion_L3-8_FI_hyperechoic_scatterers.uff', 'L3-8', 'phantom', 'phantom', 'hyperechoic scatterers');
datasets(end+1) = ds('Alpinion_L3-8_CPWC_hypoechoic.uff', 'L3-8', 'phantom', 'CPWC hypoechoic', 'CPWC');
datasets(end+1) = ds('Alpinion_L3-8_CPWC_hyperechoic_scatterers.uff', 'L3-8', 'phantom', 'phantom', 'CPWC hyperechoic');
datasets(end+1) = ds('ARFI_dataset.uff', 'L7-4', 'phantom', 'phantom', 'ARFI');
datasets(end+1) = ds('SWE_L7_type_I.uff', 'L7-4', 'phantom', 'elastography phantom', 'shear wave');
datasets(end+1) = ds('SWE_L7_type_III.uff', 'L7-4', 'phantom', 'elastography phantom', 'shear wave');
datasets(end+1) = ds('SWE_L7_type_IV.uff', 'L7-4', 'phantom', 'elastography phantom', 'shear wave');
datasets(end+1) = ds('reference_RTB_data.uff', 'L7-4', 'phantom', 'phantom', 'RTB reference');
datasets(end+1) = ds('P4_FI_121444_45mm_focus.uff', 'P4-1', 'phantom', 'phantom', 'focused phased array');
datasets(end+1) = ds('PICMUS_simulation_resolution_distortion.uff', 'L7-4', 'simulation', 'simulated', 'resolution');
datasets(end+1) = ds('PICMUS_simulation_contrast_speckle.uff', 'L7-4', 'simulation', 'simulated', 'contrast');
datasets(end+1) = ds('PICMUS_numerical_calib_v2.uff', 'L7-4', 'simulation', 'simulated', 'calibration');
datasets(end+1) = ds('FieldII_CPWC_simulation_v2.uff', 'L7-4', 'simulation', 'simulated', 'CPWC');
datasets(end+1) = ds('FieldII_CPWC_point_scatterers_res_v2.uff', 'L7-4', 'simulation', 'simulated', 'point scatterers');
datasets(end+1) = ds('FieldII_STAI_dynamic_range.uff', 'L7-4', 'simulation', 'simulated', 'dynamic range');
datasets(end+1) = ds('FieldII_STAI_simulated_dynamic_range.uff', 'L7-4', 'simulation', 'simulated', 'dynamic range');
datasets(end+1) = ds('FieldII_STAI_uniform_fov.uff', 'L7-4', 'simulation', 'simulated', 'uniform FOV');
datasets(end+1) = ds('FieldII_P4_point_scatterers.uff', 'P4-1', 'simulation', 'simulated', 'point scatterers');
datasets(end+1) = ds('FI_P4_point_scatterers.uff', 'P4-1', 'simulation', 'simulated', 'point scatterers');
datasets(end+1) = ds('FI_P4_cysts_center.uff', 'P4-1', 'simulation', 'simulated', 'cyst');
datasets(end+1) = ds('FieldII_speckle_simulation.uff', 'L7-4', 'simulation', 'simulated', 'speckle');
datasets(end+1) = ds('FieldII_speckle_DMASsimulation300000pts.uff', 'L7-4', 'simulation', 'simulated', 'DMAS speckle');
datasets(end+1) = ds('speckle_sim_FI_P4_probe_apod_1_speckle_long_many_angles.uff', 'P4-1', 'simulation', 'simulated', 'blocked array (full)');
datasets(end+1) = ds('speckle_sim_FI_P4_probe_apod_2_speckle_long_many_angles.uff', 'P4-1', 'simulation', 'simulated', 'blocked array (1/3)');
datasets(end+1) = ds('speckle_sim_FI_P4_probe_apod_3_speckle_long_many_angles.uff', 'P4-1', 'simulation', 'simulated', 'blocked array (1/2)');
datasets(end+1) = ds('L7_CPWC_TheGB.uff', 'L7-4', 'phantom', 'phantom', 'CPWC');
datasets(end+1) = ds('L7_FI_TheGB.uff', 'L7-4', 'phantom', 'phantom', 'focused imaging');
datasets(end+1) = ds('L7_DW_TheGB.uff', 'L7-4', 'phantom', 'phantom', 'diverging wave');
datasets(end+1) = ds('L7_STA_TheGB.uff', 'L7-4', 'phantom', 'phantom', 'STA');
datasets(end+1) = ds('invitro_20.uff', 'L7-4', 'phantom', 'tissue phantom', 'in-vitro');
datasets(end+1) = ds('insilico_20.uff', 'L7-4', 'simulation', 'simulated', 'in-silico');
datasets(end+1) = ds('insilico_side_100_M45.uff', 'L7-4', 'simulation', 'simulated', 'in-silico side');

end


function s = ds(filename, probe, tier, anatomy, view)
s.filename = filename;
s.probe = probe;
s.tier = tier;
s.anatomy = anatomy;
s.view = view;
end
