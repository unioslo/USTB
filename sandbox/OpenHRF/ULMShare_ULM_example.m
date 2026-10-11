%% ULM of OpenH-RF ULMShare data with USTB
%
% Builds an ultrasound localization microscopy (ULM) density map of a mouse
% brain from the ULMShare dataset (transcranial, Verasonics + L22-14v, 11
% plane waves, 1000 Hz), converted from OpenH-RF with openhrf_to_uff.m.
%
% Per 400-frame buffer, following the ULMShare reference processing
% (code/example_script.m in https://github.com/provostultrasoundlab/ulmshare):
%   1. USTB DAS on the ULMShare grid (25 um, F#1.4), all plane waves compounded
%   2. SVD clutter filter (5% of the components rejected)
%   3. lag-1 autocorrelation signal enhancement (7-frame Hanning window)
%   4. local noise normalization (as ULMShare's optional TGC, sigma = 9 px)
%   5. USTB ulm.ULM: radial-symmetry localization + tracking, keeping only
%      localizations above an SNR threshold
% The tracks of every buffer are saved, so an interrupted run resumes, and are
% finally rendered into a density map and a directional (up/down flow) map.
%
% Default acquisition: mouse 16, acquisition 1 -- Grade A, and the Grade A
% example of Fig. 5 in the ULMShare paper. Buffers 50-149 (frames
% 20000-59999) are used; the first buffers precede the microbubble bolus.
% Download them first (~465 MB each, one file per buffer, ~46 GB in total):
%
%   python openhrf_download_subset.py ^
%     --source hf://nvidia/OpenH-RF/ulmshare/data/mouse_16_acquisition_1_zea.hdf5 ^
%     --output "D:/data/OpenH-RF/ulmshare/mouse_16_acquisition_1/buffer_{buffer:03d}.hdf5" ^
%     --first-frame 20000 --n-frames 400 --n-files 100
%
% (several processes with different --first-frame/--n-files ranges download
% in parallel; existing buffers are skipped).
%
% Data: Rauby et al. (2026), ULMShare, doi:10.20383/103.01550 (CC BY 4.0),
% arXiv:2606.07851. ULM code: Heiles et al. (2022), Nat. Biomed. Eng.,
% doi:10.1038/s41551-021-00824-8 (see +ulm/README.md).

clear all; close all;

data_folder = 'D:/data/OpenH-RF/ulmshare/mouse_16_acquisition_1';
track_folder = fullfile(data_folder, 'tracks');
buffers = 50:149;

%% Processing parameters
% Beamforming grid of the ULMShare reference processing
x_axis = (-5e-3:25e-6:5e-3-25e-6).';
z_axis = (0.5e-3:25e-6:8.5e-3-25e-6).';
f_number = 1.4;
clutter_filter_cut = 5/100;     % fraction of SVD components rejected
lag1_window = 7;                % frames
normalization_sigma = 9;        % [pixels] Gaussian width of the local noise estimate
% ULM (positions are tracked in wavelengths)
ulm_resolution = 10;            % density map pixel = lambda/10
fwhm = [5 5];                   % localization kernel [pixels]
n_local_max = 7;                % max regional maxima in a kernel (grid is ~lambda/4)
number_of_particles = 300;      % max localizations per frame
snr_threshold = 1.5;            % min normalized intensity of a localization
max_linking_distance = 1.5;     % [lambda] per frame (~150 mm/s at 1 kHz)
min_length = 15;                % [frames] (ULMShare uses 20 with its own tracker)

if ~exist(track_folder, 'dir'), mkdir(track_folder); end

scan = uff.linear_scan();
scan.x_axis = x_axis;
scan.z_axis = z_axis;

%% Localize and track, one buffer at a time
for n_buffer = buffers
    track_file = fullfile(track_folder, sprintf('tracks_buffer_%03d.mat', n_buffer));
    if exist(track_file, 'file'), continue; end
    buffer_file = fullfile(data_folder, sprintf('buffer_%03d.hdf5', n_buffer));
    if ~exist(buffer_file, 'file')
        warning('Missing %s, skipping.', buffer_file);
        continue;
    end
    t_buffer = tic;

    % 1. Convert and beamform
    channel_data = openhrf_to_uff(buffer_file);
    das = midprocess.das();
    das.channel_data = channel_data;
    das.scan = scan;
    das.dimension = dimension.both;
    das.code = code.mex_gpu;
    das.receive_apodization.window = uff.window.hanning;
    das.receive_apodization.f_number = f_number;
    b_data = das.go();
    iq = reshape(double(b_data.data), scan.N_z_axis, scan.N_x_axis, []);

    % 2. SVD clutter filter (as svdClutterFilter in the ULMShare code)
    iq = svd_clutter_filter(iq, clutter_filter_cut);

    % 3. Lag-1 autocorrelation signal enhancement
    window = hanning(lag1_window);
    window = reshape(window./sum(window), 1, 1, []);
    enhanced = sqrt(abs(convn(iq(:, :, 1:end-1).*conj(iq(:, :, 2:end)), window, 'same')));

    % 4. Local noise normalization. The noise floor varies with depth (TGC)
    % and residual skull clutter is strong near the top; without this the
    % numberOfParticles brightest maxima per frame fill up with deep noise and
    % skull clutter. ULMShare applies the same mask before re-running the SVD;
    % applying it after lag-1 is cheaper and gave the same effect here.
    enhanced = enhanced./imgaussfilt(sqrt(mean(enhanced.^2, 3)), normalization_sigma);

    % 5. ULM localization + tracking
    b_ulm = uff.beamformed_data();
    b_ulm.scan = scan;
    b_ulm.data = reshape(single(enhanced), scan.N_pixels, 1, 1, []);
    u = ulm.ULM();
    u.verbose = false;
    u.workbars = false;
    u.framerate = channel_data.PRF;
    u.lambda = channel_data.lambda;
    u.fwhm = fwhm;
    u.NLocalMax = n_local_max;
    u.numberOfParticles = number_of_particles;
    u.intensity_threshold = snr_threshold;
    u.max_linking_distance = max_linking_distance;
    u.min_length = min_length;
    u.resolution = ulm_resolution;
    u.algorithm = ulm.algorithm.radial;
    u.tracking = ulm.tracking.velocity_interpolation;
    u.input = b_ulm;
    u.scan = scan;
    tracks = u.go(); %#ok<NASGU>   % {[z x vz vx t]} in m, m/s, s

    lambda = channel_data.lambda;
    save(track_file, 'tracks', 'lambda');
    fprintf('Buffer %d: %d tracks in %.0f s\n', n_buffer, numel(tracks), toc(t_buffer));
end

%% Render the density map from all saved tracks
lambda = 1540/15.625e6;
sr_pixel = lambda/ulm_resolution;
sr_z = z_axis(1):sr_pixel:z_axis(end);
sr_x = x_axis(1):sr_pixel:x_axis(end);
all_tracks = {};
n_loaded = 0;
for n_buffer = buffers
    track_file = fullfile(track_folder, sprintf('tracks_buffer_%03d.mat', n_buffer));
    if exist(track_file, 'file')
        loaded = load(track_file, 'tracks', 'lambda');
        lambda = loaded.lambda;
        all_tracks = [all_tracks; loaded.tracks(:)]; %#ok<AGROW>
        n_loaded = n_loaded + 1;
    end
end
% positions [m] -> super-resolved pixel indices, keeping [vz vx] for the velocity map
to_pixels = @(t) [(t(:, 1) - sr_z(1))/sr_pixel + 1, (t(:, 2) - sr_x(1))/sr_pixel + 1, t(:, 3:4)];
sr_tracks = cellfun(to_pixels, all_tracks, 'UniformOutput', false);
sr_size = [numel(sr_z) numel(sr_x)];
density = ulm.Track2MatOut(sr_tracks, sr_size, 'mode', '2D_tracks');
% split by mean axial velocity: z grows with depth, so vz < 0 is flow towards the probe
upwards = cellfun(@(t) mean(t(:, 3)) < 0, sr_tracks);
density_up = ulm.Track2MatOut(sr_tracks(upwards), sr_size, 'mode', '2D_tracks');
density_down = ulm.Track2MatOut(sr_tracks(~upwards), sr_size, 'mode', '2D_tracks');

fprintf('%d tracks from %d buffers\n', numel(all_tracks), n_loaded);

figure('Color', 'k');
imagesc(sr_x*1e3, sr_z*1e3, density.^(1/3));
axis image; colormap(gca, hot); caxis([0 prctile(density(density > 0).^(1/3), 99.5)]);
xlabel('x [mm]'); ylabel('z [mm]');
title(sprintf('ULMShare mouse 16 - ULM density, %d buffers', n_loaded), 'Color', 'w');
set(gca, 'XColor', 'w', 'YColor', 'w');

% Directional map: red = flow towards the probe, blue = away from it
figure('Color', 'k');
scale = prctile(density(density > 0).^(1/3), 99.5);
up = min(density_up.^(1/3)/scale, 1);
down = min(density_down.^(1/3)/scale, 1);
rgb = cat(3, up, 0.4*min(up, down), down);
image(sr_x*1e3, sr_z*1e3, rgb); axis image;
xlabel('x [mm]'); ylabel('z [mm]');
title('ULMShare mouse 16 - ULM flow direction (red: up, blue: down)', 'Color', 'w');
set(gca, 'XColor', 'w', 'YColor', 'w');

%% Local functions
function iq_out = svd_clutter_filter(iq_in, cut)
% Reject the first round(N*cut)-1 temporal singular components, using the
% N x N Gram matrix as the ULMShare reference implementation does.
dims = size(iq_in);
casorati = reshape(iq_in, [], dims(end));
[eig_vect, ~] = svd(casorati'*casorati);
n_cut = round(dims(end)*cut);
eig_vect = eig_vect(:, n_cut:end);
iq_out = reshape((casorati*eig_vect)*eig_vect', dims);
end
