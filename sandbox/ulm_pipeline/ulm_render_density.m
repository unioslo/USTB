function [density, sr_x, sr_z, density_up, density_down] = ulm_render_density(tracks, scan, lambda, resolution)
% ULM_RENDER_DENSITY Render ULM tracks into a super-resolved density map
%
% Usage: [density, sr_x, sr_z, density_up, density_down] = ...
%            ulm_render_density(tracks, scan, lambda, resolution)
%
%   tracks          cell array of tracks from ulm_process_buffer, [z x ...] in m
%   scan            uff.linear_scan the tracks were localized on
%   lambda          wavelength [m]
%   resolution      density map pixel = lambda/resolution (default 10)
%
%   density         number of tracks passing through each pixel
%   sr_x, sr_z      axes of the density map [m]
%   density_up      as density, tracks moving towards the probe (mean vz < 0)
%   density_down    as density, tracks moving away from the probe
%
% The direction maps need velocity in column 3, i.e. tracks from
% ulm.tracking.velocity_interpolation.
%
% See also ULM_PROCESS_BUFFER

if nargin < 4 || isempty(resolution)
    resolution = 10;
end

sr_pixel = lambda/resolution;
sr_z = scan.z_axis(1):sr_pixel:scan.z_axis(end);
sr_x = scan.x_axis(1):sr_pixel:scan.x_axis(end);
sr_size = [numel(sr_z) numel(sr_x)];

% positions [m] -> super-resolved pixel indices, keeping the other columns
to_pixels = @(t) [(t(:, 1) - sr_z(1))/sr_pixel + 1, (t(:, 2) - sr_x(1))/sr_pixel + 1, t(:, 3:end)];
sr_tracks = cellfun(to_pixels, tracks(:), 'UniformOutput', false);
density = ulm.Track2MatOut(sr_tracks, sr_size, 'mode', '2D_tracks');

if nargout > 3
    upwards = cellfun(@(t) mean(t(:, 3)) < 0, sr_tracks);
    density_up = ulm.Track2MatOut(sr_tracks(upwards), sr_size, 'mode', '2D_tracks');
    density_down = ulm.Track2MatOut(sr_tracks(~upwards), sr_size, 'mode', '2D_tracks');
end
end
