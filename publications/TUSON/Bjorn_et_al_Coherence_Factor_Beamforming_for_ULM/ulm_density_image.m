function [img, x_axis, z_axis] = ulm_density_image(tracks, scan, resolution)
%ULM_DENSITY_IMAGE  Accumulate tracks into a ULM density image.
%
%   [img, x_axis, z_axis] = ulm_density_image(tracks, scan, resolution)
%
%   tracks      cell of [z x ...] with positions in metres
%   scan        uff.linear_scan the tracks were localized on
%   resolution  number of ULM pixels per B-mode pixel
%
%   Each pixel counts the tracks crossing it (ulm.Track2MatOut, '2D_tracks').
%   This is the same mapping as ulm.ULM.create_image, written out so that
%   ground-truth tracks and tracks loaded from disk can be rendered on the
%   same grid, and so that the pixel positions are returned. Points outside
%   the scan are dropped.

dz = scan.z_axis(2) - scan.z_axis(1);
dx = scan.x_axis(2) - scan.x_axis(1);
sr_size = round([scan.N_z_axis scan.N_x_axis]*resolution);

% ULM pixel k is centred on axis(1) + (k/resolution - 1)*d
z_axis = scan.z_axis(1) + ((1:sr_size(1)).'/resolution - 1)*dz;
x_axis = scan.x_axis(1) + ((1:sr_size(2)).'/resolution - 1)*dx;

to_pixels = @(t) [((t(:,1) - scan.z_axis(1))/dz + 1)*resolution, ...
                  ((t(:,2) - scan.x_axis(1))/dx + 1)*resolution];
tracks_px = cellfun(to_pixels, tracks(:), 'UniformOutput', false);
inside = @(p) p(all(isfinite(p), 2) & round(p(:,1)) >= 1 & round(p(:,1)) <= sr_size(1) ...
                & round(p(:,2)) >= 1 & round(p(:,2)) <= sr_size(2), :);
tracks_px = cellfun(inside, tracks_px, 'UniformOutput', false);
tracks_px = tracks_px(~cellfun('isempty', tracks_px));

if isempty(tracks_px)
    img = zeros(sr_size);
else
    [~, img] = evalc('ulm.Track2MatOut(tracks_px, sr_size, ''mode'', ''2D_tracks'')');
end
end
