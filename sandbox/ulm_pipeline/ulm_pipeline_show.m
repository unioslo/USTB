function ulm_pipeline_show(track_folder, scan, p, name)
% ULM_PIPELINE_SHOW Load the tracks of every buffer and show one density map per beamformer
%
% Usage: ulm_pipeline_show(track_folder, scan, p, name)
%
%   track_folder    folder with the tracks_###.mat files saved from ulm_process_buffer
%   scan            uff.linear_scan the tracks were localized on
%   p               parameters, see ulm_pipeline_parameters
%   name            dataset name for the figure titles
%
% The maps of all beamformers share one color scale, so DAS and CF can be
% compared directly.
%
% See also ULM_PROCESS_BUFFER, ULM_RENDER_DENSITY

files = dir(fullfile(track_folder, 'tracks_*.mat'));
assert(~isempty(files), 'No tracks in %s', track_folder);

tracks = struct();
for n = 1:numel(files)
    loaded = load(fullfile(files(n).folder, files(n).name), 'tracks', 'lambda');
    lambda = loaded.lambda;
    for name_bf = p.beamformers
        if ~isfield(tracks, name_bf{1}), tracks.(name_bf{1}) = {}; end
        tracks.(name_bf{1}) = [tracks.(name_bf{1}); loaded.tracks.(name_bf{1})];
    end
end

density = struct();
for name_bf = p.beamformers
    [density.(name_bf{1}), sr_x, sr_z] = ulm_render_density(tracks.(name_bf{1}), scan, lambda, p.resolution);
end

% common color scale, cube root as in ULMShare
all_values = cellfun(@(f) density.(f)(:), p.beamformers, 'UniformOutput', false);
all_values = vertcat(all_values{:});
c_max = prctile(all_values(all_values > 0).^(1/3), 99.5);

for name_bf = p.beamformers
    figure('Color', 'k');
    imagesc(sr_x*1e3, sr_z*1e3, density.(name_bf{1}).^(1/3));
    axis image; colormap(gca, hot); clim([0 c_max]);
    xlabel('x [mm]'); ylabel('z [mm]');
    title(sprintf('%s - ULM %s, %d tracks from %d buffers', name, name_bf{1}, ...
        numel(tracks.(name_bf{1})), numel(files)), 'Color', 'w');
    set(gca, 'XColor', 'w', 'YColor', 'w');
end
end
