% generate_all_references.m
% Generates MATLAB reference images for all Python examples.
% Saves beamformed envelopes as HDF5 for Python comparison.

addpath(ustb_path());
url = 'http://ustb.no/datasets/';
local_path = [ustb_path(), '/data/'];
outdir = fullfile(fileparts(mfilename('fullpath')));

%% 1. CPWC Linear (Verasonics L7)
fprintf('\n=== CPWC Linear ===\n');
fn = 'L7_CPWC_193328.uff';
tools.download(fn, url, local_path);
channel_data = uff.read_object([local_path fn], '/channel_data');

scan = uff.linear_scan();
scan.x_axis = linspace(channel_data.probe.x(1), channel_data.probe.x(end), 256).';
scan.z_axis = linspace(0, 50e-3, 256).';

mid = midprocess.das();
mid.dimension = dimension.both;
mid.code = code.matlab;
mid.channel_data = channel_data;
mid.scan = scan;
mid.transmit_apodization.window = uff.window.none;
mid.transmit_apodization.f_number = 1.7;
mid.receive_apodization.window = uff.window.none;
mid.receive_apodization.f_number = 1.7;
b_data = mid.go();

save_reference(fullfile(outdir, 'ref_cpwc_linear.h5'), b_data, scan, mid);

%% 2. PICMUS experiment resolution distortion
fprintf('\n=== PICMUS Experiment Resolution ===\n');
fn = 'PICMUS_experiment_resolution_distortion.uff';
tools.download(fn, url, local_path);
channel_data = uff.read_object([local_path fn], '/channel_data');
scan = uff.read_object([local_path fn], '/scan');

mid = midprocess.das();
mid.dimension = dimension.both;
mid.code = code.matlab;
mid.channel_data = channel_data;
mid.scan = scan;
mid.receive_apodization.window = uff.window.tukey50;
mid.receive_apodization.f_number = 1.7;
mid.transmit_apodization.window = uff.window.tukey50;
mid.transmit_apodization.f_number = 1.7;
b_data = mid.go();

save_reference(fullfile(outdir, 'ref_picmus_exp_resolution.h5'), b_data, scan, mid);

%% 3. PICMUS simulation resolution distortion
fprintf('\n=== PICMUS Simulation Resolution ===\n');
fn = 'PICMUS_simulation_resolution_distortion.uff';
tools.download(fn, url, local_path);
channel_data = uff.read_object([local_path fn], '/channel_data');
scan = uff.read_object([local_path fn], '/scan');

mid = midprocess.das();
mid.dimension = dimension.both;
mid.code = code.matlab;
mid.channel_data = channel_data;
mid.scan = scan;
mid.receive_apodization.window = uff.window.tukey50;
mid.receive_apodization.f_number = 1.7;
mid.transmit_apodization.window = uff.window.tukey50;
mid.transmit_apodization.f_number = 1.7;
b_data = mid.go();

save_reference(fullfile(outdir, 'ref_picmus_sim_resolution.h5'), b_data, scan, mid);

%% 4. PICMUS experiment contrast speckle
fprintf('\n=== PICMUS Experiment Contrast ===\n');
fn = 'PICMUS_experiment_contrast_speckle.uff';
tools.download(fn, url, local_path);
channel_data = uff.read_object([local_path fn], '/channel_data');
scan = uff.read_object([local_path fn], '/scan');

mid = midprocess.das();
mid.dimension = dimension.both;
mid.code = code.matlab;
mid.channel_data = channel_data;
mid.scan = scan;
mid.receive_apodization.window = uff.window.tukey50;
mid.receive_apodization.f_number = 1.7;
mid.transmit_apodization.window = uff.window.tukey50;
mid.transmit_apodization.f_number = 1.7;
b_data = mid.go();

save_reference(fullfile(outdir, 'ref_picmus_exp_contrast.h5'), b_data, scan, mid);

%% 5. PICMUS simulation contrast speckle
fprintf('\n=== PICMUS Simulation Contrast ===\n');
fn = 'PICMUS_simulation_contrast_speckle.uff';
tools.download(fn, url, local_path);
channel_data = uff.read_object([local_path fn], '/channel_data');
scan = uff.read_object([local_path fn], '/scan');

mid = midprocess.das();
mid.dimension = dimension.both;
mid.code = code.matlab;
mid.channel_data = channel_data;
mid.scan = scan;
mid.receive_apodization.window = uff.window.tukey50;
mid.receive_apodization.f_number = 1.7;
mid.transmit_apodization.window = uff.window.tukey50;
mid.transmit_apodization.f_number = 1.7;
b_data = mid.go();

save_reference(fullfile(outdir, 'ref_picmus_sim_contrast.h5'), b_data, scan, mid);

fprintf('\n=== All references generated ===\n');

function save_reference(outfile, b_data, scan, mid)
    if isfile(outfile); delete(outfile); end
    bf = b_data.data;
    h5create(outfile, '/bf_real', size(real(bf)));
    h5write(outfile, '/bf_real', real(bf));
    h5create(outfile, '/bf_imag', size(imag(bf)));
    h5write(outfile, '/bf_imag', imag(bf));
    h5create(outfile, '/scan_x', size(scan.x));
    h5write(outfile, '/scan_x', scan.x);
    h5create(outfile, '/scan_z', size(scan.z));
    h5write(outfile, '/scan_z', scan.z);
    h5create(outfile, '/tx_delay', size(mid.transmit_delay));
    h5write(outfile, '/tx_delay', mid.transmit_delay);
    h5create(outfile, '/rx_delay', size(mid.receive_delay));
    h5write(outfile, '/rx_delay', mid.receive_delay);
    if isa(scan, 'uff.linear_scan')
        h5create(outfile, '/scan_type', 1, 'Datatype', 'int32');
        h5write(outfile, '/scan_type', int32(0));
        h5create(outfile, '/x_axis', size(scan.x_axis));
        h5write(outfile, '/x_axis', scan.x_axis);
        h5create(outfile, '/z_axis', size(scan.z_axis));
        h5write(outfile, '/z_axis', scan.z_axis);
    else
        h5create(outfile, '/scan_type', 1, 'Datatype', 'int32');
        h5write(outfile, '/scan_type', int32(1));
    end
    fprintf('  Saved: %s (bf size: %s)\n', outfile, mat2str(size(bf)));
end
