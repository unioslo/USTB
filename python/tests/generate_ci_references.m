% generate_ci_references.m
% Small MATLAB references for the Python-vs-MATLAB comparison that runs in
% CI (test_ci_matlab_reference.py). Only scan coordinates and beamformed IQ
% data are stored, in single precision with compression, so the files can be
% committed. Settings match generate_all_references.m.
% Run from the repository root:
%   matlab -batch "addpath('.'); run('python/tests/generate_ci_references.m');"

addpath(ustb_path());
url = tools.zenodo_dataset_files_base();
local_path = [ustb_path(), '/data/'];
outdir = fullfile(fileparts(mfilename('fullpath')), 'ci_reference');
if ~isfolder(outdir), mkdir(outdir); end

%% CPWC linear (Verasonics L7): plane waves, no apodization windows
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
mid.receive_apodization.window = uff.window.none;
save_compact(fullfile(outdir, 'cpwc_linear.h5'), mid.go(), scan);

%% PICMUS experiment resolution: plane waves, tukey50 transmit and receive
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
save_compact(fullfile(outdir, 'picmus_experiment_resolution.h5'), mid.go(), scan);

function save_compact(outfile, b_data, scan)
    if isfile(outfile), delete(outfile); end
    bf = b_data.data;
    write(outfile, '/bf_real', real(bf));
    write(outfile, '/bf_imag', imag(bf));
    write(outfile, '/scan_x', scan.x);
    write(outfile, '/scan_z', scan.z);
    fprintf('Saved %s\n', outfile);
end

function write(outfile, name, value)
    value = single(value);
    h5create(outfile, name, size(value), 'Datatype', 'single', ...
        'ChunkSize', min(size(value), [4096, ones(1, ndims(value) - 1)]), 'Deflate', 9);
    h5write(outfile, name, value);
end
