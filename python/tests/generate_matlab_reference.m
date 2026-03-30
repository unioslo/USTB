% generate_matlab_reference.m
% Generates reference data from the MATLAB USTB for integration testing.
% Saves delays, apodization, and beamformed data to an HDF5 file that
% Python tests can load and compare against.

addpath(ustb_path());

% Load dataset (must already be downloaded)
local_path = [ustb_path(), '/data/'];
filename = 'Verasonics_P2-4_parasternal_long_small.uff';
channel_data = uff.read_object([local_path, filename], '/channel_data');

% Use a small scan for fast comparison
depth_axis = linspace(0e-3, 110e-3, 128).';
azimuth_axis = linspace(channel_data.sequence(1).source.azimuth, ...
    channel_data.sequence(end).source.azimuth, channel_data.N_waves)';
scan = uff.sector_scan('azimuth_axis', azimuth_axis, 'depth_axis', depth_axis);

% Beamform with MATLAB backend (not MEX, for reproducibility)
mid = midprocess.das();
mid.channel_data = channel_data;
mid.dimension = dimension.both;
mid.code = code.matlab;
mid.scan = scan;
mid.transmit_apodization.window = uff.window.scanline;
mid.receive_apodization.window = uff.window.none;
b_data = mid.go();

% Save reference data
outfile = fullfile(fileparts(mfilename('fullpath')), 'matlab_reference.h5');
if isfile(outfile), delete(outfile); end

% Scan coordinates
h5create(outfile, '/scan/x', size(scan.x));
h5write(outfile, '/scan/x', scan.x);
h5create(outfile, '/scan/y', size(scan.y));
h5write(outfile, '/scan/y', scan.y);
h5create(outfile, '/scan/z', size(scan.z));
h5write(outfile, '/scan/z', scan.z);

% Delays
h5create(outfile, '/transmit_delay', size(mid.transmit_delay));
h5write(outfile, '/transmit_delay', mid.transmit_delay);
h5create(outfile, '/receive_delay', size(mid.receive_delay));
h5write(outfile, '/receive_delay', mid.receive_delay);

% Beamformed data (complex: split into real/imag)
bf = b_data.data;
h5create(outfile, '/beamformed_data_real', size(bf));
h5write(outfile, '/beamformed_data_real', real(bf));
h5create(outfile, '/beamformed_data_imag', size(bf));
h5write(outfile, '/beamformed_data_imag', imag(bf));

% Metadata
h5create(outfile, '/N_pixels', 1);
h5write(outfile, '/N_pixels', int32(scan.N_pixels));
h5create(outfile, '/N_waves', 1);
h5write(outfile, '/N_waves', int32(channel_data.N_waves));
h5create(outfile, '/N_channels', 1);
h5write(outfile, '/N_channels', int32(channel_data.N_channels));

fprintf('Reference data saved to %s\n', outfile);
