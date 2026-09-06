function export_openhrf_previews(only_stem, only_group)
%EXPORT_OPENHRF_PREVIEWS  Render submission reference PNGs with the canonical
%   USTB DAS beamforming used for the public dataset catalog (website).
%
%   For every <stem>.hdf5 in each OpenH-RF submission group folder, this reads
%   the original <stem>.uff from data_dir, beamforms it with
%   examples/dataset_catalog_previews/dataset_preview_beamform.m (the exact
%   per-dataset reconstruction used on https://unioslo.github.io/USTB/datasets.html),
%   and writes <stem>_bmode.png with the title "USTB: <dataset>".
%
%   Usage (headless):
%     matlab -batch "export_openhrf_previews()"                           % all
%     matlab -batch "export_openhrf_previews('L7_FI_carotid_cross_1')"    % one dataset
%     matlab -batch "export_openhrf_previews('', 'C_verasonics_phantom')" % one group

if nargin < 1
    only_stem = '';
end
if nargin < 2
    only_group = '';
end

this = fileparts(mfilename('fullpath'));        % sandbox/OpenHRF
repo = fileparts(fileparts(this));              % repo root
addpath(repo);
addpath(fullfile(repo, 'examples', 'dataset_catalog_previews'));
addpath(fullfile(repo, 'examples', 'dataset_smoke_tests'));

data_dir = 'C:\Data\USTB_data';
sub_root = fullfile(data_dir, 'openh_rf_submission');

groups = dir(sub_root);
groups = groups([groups.isdir] & ~startsWith({groups.name}, '.'));

n_ok = 0; n_fail = 0;
for gi = 1:numel(groups)
    if ~isempty(only_group) && ~strcmp(groups(gi).name, only_group)
        continue
    end
    gdir = fullfile(sub_root, groups(gi).name);
    hd = dir(fullfile(gdir, '*.hdf5'));
    for hi = 1:numel(hd)
        stem = erase(hd(hi).name, '.hdf5');
        if ~isempty(only_stem) && ~strcmp(stem, only_stem)
            continue
        end
        uff_file = fullfile(data_dir, [stem '.uff']);
        png_path = fullfile(gdir, [stem '_bmode.png']);
        if ~isfile(uff_file)
            fprintf('[MISS] %s (no .uff)\n', stem);
            n_fail = n_fail + 1;
            continue
        end
        try
            b_data = dataset_preview_beamform(uff_file);
            export_bmode_png_headless(b_data, png_path, 60, stem);
            fprintf('[ OK ] %s/%s_bmode.png\n', groups(gi).name, stem);
            n_ok = n_ok + 1;
        catch ME
            fprintf('[FAIL] %s: %s\n', stem, ME.message);
            n_fail = n_fail + 1;
        end
        close all force;
        clear b_data;
    end
end
fprintf('Done: %d ok, %d failed.\n', n_ok, n_fail);
end


function export_bmode_png_headless(b_data, filepath, dynamic_range_db, title_stem)
%EXPORT_BMODE_PNG_HEADLESS  Like export_png_like_b_data_plot but strips UI
%   components (frame slider) so exportgraphics works in `matlab -batch`, and
%   sets the title to "USTB: <dataset>".
if nargin < 4
    title_stem = '';
end
[p, ~] = fileparts(filepath);
if ~isfolder(p); mkdir(p); end

fig = figure('Visible', 'off', 'Color', 'w', 'MenuBar', 'none', 'ToolBar', 'none');
% First frame, log display, 60 dB — same call as the website export.
b_data.plot(fig, '', dynamic_range_db, 'log', [], 1);

delete(findobj(fig, 'Type', 'colorbar'));
% Remove any UI widgets (multi-frame slider, panels) that block exportgraphics.
delete(findall(fig, 'Type', 'uicontrol'));
delete(findall(fig, 'Type', 'uipanel'));
delete(findall(fig, 'Type', 'uibuttongroup'));

ax = gca(fig);
axis(ax, 'tight');
% Label the reconstruction as the canonical USTB DAS reconstruction.
title(ax, ['USTB: ' title_stem], 'Interpreter', 'none');
set(fig, 'Position', [100, 100, 600, 500]);
set(ax, 'Units', 'normalized', 'Position', [0.13, 0.11, 0.78, 0.8]);
drawnow;

exportgraphics(ax, filepath, 'Resolution', 120, 'BackgroundColor', 'white');
close(fig);
end
