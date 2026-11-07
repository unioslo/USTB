function channel_data = openhrf_to_uff(filename, varargin)
%OPENHRF_TO_UFF Convert an OpenH-RF (zea HDF5) plane-wave acquisition to UFF
%
%   channel_data = OPENHRF_TO_UFF(filename) reads the zea-format HDF5 file
%   and returns a uff.channel_data object with probe, plane-wave sequence
%   and channel data ([time x channel x wave x frame]).
%
%   channel_data = OPENHRF_TO_UFF(filename, 'frames', idx) reads only the
%   (1-based, contiguous) frames idx, e.g. 1:400. Default: all frames.
%
%   OPENHRF_TO_UFF(..., 'uff_file', out_file) also writes the result to a
%   UFF file (as /channel_data).
%
%   ULMShare files (detected from the openhrf_source or description
%   attribute, L22-14v stored with 80 um pitch) are corrected to the 100 um
%   probe pitch and a +2.56 us (20 lambda) receive time offset, see the
%   ULMShare correction below. OPENHRF_TO_UFF(..., 'ulmshare_correction',
%   false) returns the geometry as stored.
%
%   This is the inverse of convert_ustb_to_openh_rf.py in this folder. Only
%   plane-wave acquisitions (focus_distances = Inf or 0, zero transmit
%   origins) are supported for now, e.g. the ULMShare dataset:
%   https://huggingface.co/datasets/nvidia/OpenH-RF/tree/main/ulmshare
%
%   The OpenH-RF raw data is Blosc-compressed, which MATLAB cannot read
%   without an HDF5 filter plugin, and the ULMShare files are 60-370 GB. Use
%   openhrf_download_subset.py to stream a frame range from the Hugging Face
%   Hub into a small, gzip-compressed local file with the same layout.
%
%   Time convention
%   ---------------
%   zea stores per-element transmit delays t0_delays (min 0) and a per
%   transmit initial_times, so a sample at index n corresponds to the time
%   initial_times + n/fs after the first element fired. USTB references the
%   plane-wave transmit delay to the instant the wavefront crosses the
%   origin, x*sin(a) + z*cos(a) [m], and samples at
%       rx + tx - wave.delay - channel_data.initial_time.
%   With t_origin the time at which the zea wavefront crosses the origin,
%       wave.delay = initial_times - t_origin,  channel_data.initial_time = 0,
%   which matches the convention of the USTB Verasonics importers
%   (@verasonics/create_cpw_channeldata.m).
%
%   See also UFF.CHANNEL_DATA, UFF.WAVE, OPENHRF_DOWNLOAD_SUBSET.PY

p = inputParser;
addRequired(p, 'filename', @(x) ischar(x) || isstring(x));
addParameter(p, 'frames', [], @(x) isempty(x) || (isnumeric(x) && isvector(x)));
addParameter(p, 'uff_file', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'ulmshare_correction', true, @(x) islogical(x) || isnumeric(x));
parse(p, filename, varargin{:});
filename = char(filename);
frames = p.Results.frames;

%% Locate the track (zea >= 0.1.4 nests data/scan under /tracks/track_0)
info = h5info(filename);
group_names = {info.Groups.Name};
if any(strcmp(group_names, '/tracks'))
    track = '/tracks/track_0';
else
    track = '';
end
read = @(path) h5read(filename, path);
has = @(path) h5exists(filename, path);

%% Scan / acquisition parameters
scan_path = [track '/scan/'];
fs = double(read([scan_path 'sampling_frequency']));
c0 = double(read([scan_path 'sound_speed']));
fc = double(read([scan_path 'center_frequency']));
fdemod = fc;
if has([scan_path 'demodulation_frequency'])
    fdemod = double(read([scan_path 'demodulation_frequency']));
end
% h5read returns arrays with reversed dimension order: (n_el, n_tx) etc.
t0_delays = double(read([scan_path 't0_delays'])).';          % [n_tx x n_el]
polar_angles = double(read([scan_path 'polar_angles']));       % [n_tx x 1]
n_tx = numel(polar_angles);
azimuth_angles = zeros(n_tx, 1);
if has([scan_path 'azimuth_angles'])
    azimuth_angles = double(read([scan_path 'azimuth_angles']));
end
initial_times = zeros(n_tx, 1);
if has([scan_path 'initial_times'])
    initial_times = double(read([scan_path 'initial_times']));
end
focus_distances = inf(n_tx, 1);
if has([scan_path 'focus_distances'])
    focus_distances = double(read([scan_path 'focus_distances']));
end
transmit_origins = zeros(n_tx, 3);
if has([scan_path 'transmit_origins'])
    transmit_origins = double(read([scan_path 'transmit_origins'])).';
end
tx_apodizations = ones(size(t0_delays));
if has([scan_path 'tx_apodizations'])
    tx_apodizations = double(read([scan_path 'tx_apodizations'])).';
end

is_plane_wave = (isinf(focus_distances) | focus_distances == 0) & all(transmit_origins == 0, 2);
assert(all(is_plane_wave), ['openhrf_to_uff: only plane-wave acquisitions are supported ' ...
    '(found focused/diverging transmits or non-zero transmit_origins).']);

%% Probe
probe_geometry = double(read('/probe/probe_geometry')).';      % [n_el x 3]
n_el = size(probe_geometry, 1);
pitch = median(vecnorm(diff(probe_geometry, 1, 1), 2, 2));
element_width = pitch;    % not always stored by zea; pitch is the best estimate

%% ULMShare correction
% The ULMShare files store the L22-14v (128 elements) with 80 um pitch, the
% element width (ULMShare's getProbe.m), and t0_delays computed for it. The
% probe pitch is 100 um: scale the element positions and the firing delays
% (proportional to the element position for a plane wave) by 100/80. The
% recording starts 2.56 us (20 lambda) after the transmit: the Verasonics
% Receive.startDepth (startDepth_wavelengths: 20 in the original ULMShare
% sequence.json files), not stored in OpenH-RF (initial_times = 0). See
% https://github.com/open-h/Open-H-RF/issues/59. Turn off with
% 'ulmshare_correction', false.
ulmshare_corrected = false;
if p.Results.ulmshare_correction && is_ulmshare(filename, info) ...
        && n_el == 128 && abs(pitch - 80e-6) < 1e-7
    scale = 100e-6/pitch;
    probe_geometry(:, 1) = probe_geometry(:, 1)*scale;
    t0_delays = t0_delays*scale;
    initial_times = initial_times + 2.56e-6;
    pitch = 100e-6;
    ulmshare_corrected = true;
end

prb = uff.probe();
geometry = zeros(n_el, 7);
geometry(:, 1:3) = probe_geometry;
if has('/probe/element_width')
    element_width = double(read('/probe/element_width'));
end
geometry(:, 6) = element_width;
if has('/probe/element_height')
    geometry(:, 7) = double(read('/probe/element_height'));
end
prb.geometry = geometry;
if has('/probe/name')
    prb.name = read_string(filename, '/probe/name');
end

%% Plane-wave sequence
c = c0;
for n = 1:n_tx
    seq(n) = uff.wave(); %#ok<AGROW>
    seq(n).probe = prb;
    seq(n).sound_speed = c;
    seq(n).source.distance = Inf;
    seq(n).source.azimuth = polar_angles(n);
    seq(n).source.elevation = azimuth_angles(n);
    seq(n).apodization.apodization_vector = tx_apodizations(n, :).';

    % Time at which the zea wavefront crosses the origin: every element fires
    % at t0 = t_origin + (r_e . v)/c, v = (sin p cos a, sin p sin a, cos p).
    v = [sin(polar_angles(n))*cos(azimuth_angles(n)), ...
         sin(polar_angles(n))*sin(azimuth_angles(n)), ...
         cos(polar_angles(n))];
    active = tx_apodizations(n, :) > 0;
    t_origin = mean(t0_delays(n, active) - (probe_geometry(active, :)*v.').'/c);
    seq(n).delay = initial_times(n) - t_origin;
end

%% Channel data
raw_path = [track '/data/raw_data'];
raw_info = h5info(filename, raw_path);
raw_size = raw_info.Dataspace.Size;        % MATLAB order: [n_ch n_el n_ax n_tx n_frames]
if numel(raw_size) < 5
    raw_size(end+1:5) = 1;
end
n_frames_file = raw_size(5);
if isempty(frames)
    frames = 1:n_frames_file;
end
assert(all(diff(frames) == 1), 'openhrf_to_uff: frames must be contiguous.');
assert(frames(1) >= 1 && frames(end) <= n_frames_file, ...
    'openhrf_to_uff: frames out of range [1, %d].', n_frames_file);
start = [1 1 1 1 frames(1)];
count = [raw_size(1:4) numel(frames)];
raw = h5read(filename, raw_path, start, count);    % [n_ch n_el n_ax n_tx n_frames]
assert(raw_size(2) == n_el && raw_size(4) == n_tx, ...
    'openhrf_to_uff: raw_data does not match probe/scan dimensions.');

channel_data = uff.channel_data();
channel_data.sampling_frequency = fs;
channel_data.sound_speed = c0;
channel_data.initial_time = 0;
channel_data.probe = prb;
channel_data.sequence = seq;
channel_data.pulse = uff.pulse();
channel_data.pulse.center_frequency = fc;
if raw_size(1) == 2
    % IQ: [I, Q] -> I + jQ, then to [time x channel x wave x frame]
    data = complex(single(raw(1, :, :, :, :)), single(raw(2, :, :, :, :)));
    channel_data.modulation_frequency = fdemod;
else
    data = single(raw(1, :, :, :, :));
    channel_data.modulation_frequency = 0;
end
channel_data.data = permute(reshape(data, raw_size(2), raw_size(3), n_tx, numel(frames)), [2 1 3 4]);

%% Metadata
channel_data.name = {'OpenH-RF dataset converted with openhrf_to_uff.m'};
attributes = {info.Attributes.Name};
if any(strcmp(attributes, 'description'))
    channel_data.name{end+1} = h5readatt(filename, '/', 'description');
end
if any(strcmp(attributes, 'openhrf_source'))
    channel_data.name{end+1} = sprintf('Source: %s, frames %d-%d of the source file (1-based)', ...
        h5readatt(filename, '/', 'openhrf_source'), ...
        double(h5readatt(filename, '/', 'openhrf_first_frame')) + frames(1), ...
        double(h5readatt(filename, '/', 'openhrf_first_frame')) + frames(end));
end
if ulmshare_corrected
    channel_data.name{end+1} = ['ULMShare correction applied: 100 um pitch (stored 80 um is the ' ...
        'element width), transmit delays scaled to it, +2.56 us (20 lambda) receive time offset'];
end
if has('/metadata/credit')
    channel_data.reference = {read_string(filename, '/metadata/credit')};
end
if has('/custom/frame_rate_hz')
    channel_data.PRF = str2double(read_string(filename, '/custom/frame_rate_hz'));
end
if any(strcmp(attributes, 'us_machine'))
    channel_data.info = {['Ultrasound system: ' h5readatt(filename, '/', 'us_machine')]};
end

if ~isempty(p.Results.uff_file)
    channel_data.write(char(p.Results.uff_file), 'channel_data');
end
end

function tf = h5exists(filename, path)
try
    h5info(filename, path);
    tf = true;
catch
    tf = false;
end
end

function str = read_string(filename, path)
str = h5read(filename, path);
if iscell(str)
    str = str{1};
end
str = char(str);
end

function tf = is_ulmshare(filename, info)
% ULMShare data from OpenH-RF: the source path (openhrf_download_subset.py)
% or the description names ULMShare
tf = false;
attributes = {info.Attributes.Name};
for name = {'openhrf_source', 'description'}
    if any(strcmp(attributes, name{1}))
        tf = tf || contains(lower(char(h5readatt(filename, '/', name{1}))), 'ulmshare');
    end
end
end
