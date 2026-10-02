% generate_process_references.m
% MATLAB references for the Python postprocesses (test_processes_vs_matlab.py).
% The per-channel beamformed input is stored too, so Python runs each process
% on exactly the same data as MATLAB. Small enough to commit (single
% precision, compressed): 16 x 300 pixels, 64 channels, one frame.
% Run from the repository root:
%   matlab -batch "addpath('.'); run('python/tests/generate_process_references.m');"

addpath(ustb_path());
url = tools.zenodo_dataset_files_base();
local_path = [ustb_path(), '/data/'];
out = fullfile(fileparts(mfilename('fullpath')), 'ci_reference', 'processes.h5');
if isfile(out), delete(out); end

fn = 'L7_CPWC_193328.uff';
tools.download(fn, url, local_path);
channel_data = uff.read_object([local_path fn], '/channel_data');
channel_data.data = channel_data.data(:, 33:96, :, 1);   % 64 central channels, first frame
channel_data.probe.geometry = channel_data.probe.geometry(33:96, :);

% Axial sampling fine enough for the DMAS filter around 2*f0
scan = uff.linear_scan();
scan.x_axis = linspace(-2e-3, 2e-3, 16).';
scan.z_axis = linspace(12e-3, 12e-3 + 299*15e-6, 300).';

mid = midprocess.das();
mid.dimension = dimension.transmit;           % sum the waves, keep the channels
mid.code = code.matlab;
mid.channel_data = channel_data;
mid.scan = scan;
mid.transmit_apodization.window = uff.window.none;
mid.receive_apodization.window = uff.window.none;
b_data = mid.go();

write(out, '/input_real', real(b_data.data));
write(out, '/input_imag', imag(b_data.data));
write(out, '/x_axis', scan.x_axis);
write(out, '/z_axis', scan.z_axis);
write(out, '/sound_speed', channel_data.sound_speed);
write(out, '/center_frequency', channel_data.pulse.center_frequency);

cf = postprocess.coherence_factor();
cf.input = b_data; cf.dimension = dimension.receive;
o = cf.go();
write(out, '/cf/output_real', real(o.data)); write(out, '/cf/output_imag', imag(o.data));
write(out, '/cf/factor', cf.CF.data);

gcf = postprocess.generalized_coherence_factor();
gcf.input = b_data; gcf.dimension = dimension.receive; gcf.M0 = 4;
o = gcf.go();
write(out, '/gcf/output_real', real(o.data)); write(out, '/gcf/output_imag', imag(o.data));
write(out, '/gcf/factor', gcf.GCF.data);

pcf = postprocess.phase_coherence_factor();
pcf.input = b_data; pcf.dimension = dimension.receive;
o = pcf.go();
write(out, '/pcf/output_real', real(o.data)); write(out, '/pcf/output_imag', imag(o.data));
write(out, '/pcf/FCC', pcf.FCC.data); write(out, '/pcf/FCA', pcf.FCA.data);

mv = postprocess.capon_minimum_variance();
mv.input = b_data; mv.dimension = dimension.receive;
mv.scan = scan; mv.channel_data = channel_data;
mv.L_elements = 16; mv.K_in_lambda = 1; mv.regCoef = 1/100;
o = mv.go();
write(out, '/capon/output_real', real(o.data)); write(out, '/capon/output_imag', imag(o.data));
mv.doForwardBackward = 1;
o = mv.go();
write(out, '/capon_fb/output_real', real(o.data)); write(out, '/capon_fb/output_imag', imag(o.data));

dmas = postprocess.delay_multiply_and_sum();
dmas.input = b_data; dmas.dimension = dimension.receive;
dmas.channel_data = channel_data;
o = dmas.go();
write(out, '/dmas/output_real', real(o.data)); write(out, '/dmas/output_imag', imag(o.data));

fprintf('Saved %s\n', out);

function write(outfile, name, value)
    value = single(value);
    chunk = size(value); chunk(1) = min(chunk(1), 4096);
    h5create(outfile, name, size(value), 'Datatype', 'single', 'ChunkSize', chunk, 'Deflate', 9);
    h5write(outfile, name, value);
end
