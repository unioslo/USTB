function [tracks, tracks_interp, u] = run_ulm(b_data, scan, lambda, framerate, common, prm)
%RUN_ULM  Localize and track microbubbles in beamformed data with the USTB
%   ULM module, using the PALA radial symmetry localizer and the Hungarian
%   tracker.
%
%   [tracks, tracks_interp, u] = run_ulm(b_data, scan, lambda, framerate, common, prm)
%
%   common   cfg.ulm (settings shared by all runs)
%   prm      struct with fwhm, NLocalMax, max_linking_distance, numberOfParticles
%
%   tracks         cell of [z x frame], raw localizations along accepted
%                  tracks, positions in metres. Used for the statistics.
%   tracks_interp  cell of [z x mean_velocity], the same tracks smoothed and
%                  interpolated. Used to accumulate the ULM image.
%   u              the configured ulm.ULM object (for pairing/create_image)

u = ulm.ULM();
u.verbose   = false;
u.workbars  = false;
u.algorithm = common.algorithm;
u.tracking  = ulm.tracking.pala; % returns raw and interpolated tracks at once
u.framerate            = framerate;
u.resolution           = common.resolution;
u.min_length           = common.min_length;
u.max_gap_closing      = common.max_gap_closing;
u.fwhm                 = prm.fwhm;
u.NLocalMax            = prm.NLocalMax;
u.max_linking_distance = prm.max_linking_distance; % in wavelengths
u.numberOfParticles    = prm.numberOfParticles;
u.lambda = lambda;
u.scan   = scan;
u.input  = b_data;

[tracks, tracks_interp] = u.go();

% tracking2D returns a single all-zero row when no track was found
found = @(c) c(cellfun(@(x) any(x(:)), c));
tracks        = found(tracks);
tracks_interp = found(tracks_interp);
end
