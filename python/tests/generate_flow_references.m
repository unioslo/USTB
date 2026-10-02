% generate_flow_references.m
% MATLAB references for the Python SVD filters and autocorrelation Doppler
% estimators (test_flow_vs_matlab.py), on synthetic data written here too:
% static "tissue" + a phase-shifting "blood" component + noise, 12 frames.
% Run from the repository root:
%   matlab -batch "addpath('.'); run('python/tests/generate_flow_references.m');"

addpath(ustb_path());
out = fullfile(fileparts(mfilename('fullpath')), 'ci_reference', 'flow.h5');
if isfile(out), delete(out); end
rng(5);

N_z = 40; N_x = 20; N_frames = 12;
scan = uff.linear_scan('x_axis', linspace(-3e-3, 3e-3, N_x).', ...
    'z_axis', 10e-3 + 50e-6*(0:N_z-1).');
[Z, X] = ndgrid(scan.z_axis, scan.x_axis);
t = reshape(0:N_frames-1, 1, 1, []);
tissue = 20 * (randn(N_z, N_x) + 1i*randn(N_z, N_x));
blood = (randn(N_z, N_x) + 1i*randn(N_z, N_x)) .* exp(1i*2*pi*(0.08 + 0.1*X/3e-3).*t) ...
    .* exp(1i*2*pi*5e6*2*Z/1540);
noise = 0.3 * (randn(N_z, N_x, N_frames) + 1i*randn(N_z, N_x, N_frames));
images = tissue + blood + noise;

b_data = uff.beamformed_data();
b_data.scan = scan;
b_data.data = reshape(images, [N_z*N_x, 1, 1, N_frames]);

channel_data = uff.channel_data();
channel_data.sound_speed = 1540;
channel_data.pulse = uff.pulse(); channel_data.pulse.center_frequency = 5e6;

write(out, '/x_axis', scan.x_axis); write(out, '/z_axis', scan.z_axis);
write_complex(out, '/input', b_data.data);

ac = postprocess.autocorrelation_displacement_estimation();
ac.input = b_data; ac.channel_data = channel_data;
ac.z_gate = 4; ac.x_gate = 2; ac.packet_size = 6;
o = ac.go();
write(out, '/autocorrelation', o.data);

mac = postprocess.modified_autocorrelation_displacement_estimation();
mac.input = b_data; mac.channel_data = channel_data;
mac.z_gate = 4; mac.x_gate = 2; mac.packet_size = 6;
o = mac.go();
write(out, '/modified_autocorrelation', o.data);
write(out, '/modified_center_frequency', mac.estimated_center_frequency);

for cutoff = {3, [2 6], [3 5 8]}
    s = postprocess.svd_filter(); s.input = b_data; s.cutoff = cutoff{1};
    o = s.go();
    write_complex(out, ['/svd_beamformed_' char(strjoin(string(cutoff{1}), '_'))], o.data);
end

% Channel data (time x channel x wave x frame) for preprocess.svd_filter
ch = uff.channel_data();
ch.sound_speed = 1540; ch.sampling_frequency = 20e6; ch.initial_time = 0;
ch.data = repmat(randn(64, 8, 2), 1, 1, 1, N_frames) + ...
    0.2*randn(64, 8, 2, N_frames) .* cos(2*pi*0.1*reshape(0:N_frames-1, 1, 1, 1, []));
write(out, '/channel_input', ch.data);
s = preprocess.svd_filter(); s.input = ch; s.cutoff = 2;
o = s.go();
write(out, '/svd_channel_2', o.data);

fprintf('Saved %s\n', out);

function write(outfile, name, value)
    value = double(value);
    h5create(outfile, name, size(value), 'Datatype', 'double');
    h5write(outfile, name, value);
end

function write_complex(outfile, name, value)
    write(outfile, [name '_real'], real(value));
    write(outfile, [name '_imag'], imag(value));
end
