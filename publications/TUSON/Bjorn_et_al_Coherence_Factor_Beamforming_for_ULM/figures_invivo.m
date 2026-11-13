%% Figures and numbers for the OPULM in vivo rat-brain data
%
% Reads the result files written by process_invivo.m and produces, in
% cfg.figure_path/invivo/parameters,
%
%   compare_generic.png             DAS | CF overview with the regions of interest
%   compare_generic1.png ... 3.png  regions (b), (c), (d): DAS | CF | difference
%   metrics_comparison.png          heuristic image indices of the two images
%   invivo_metrics.txt              the numbers of the metrics table
%
% The file names are the ones used by the manuscript. The numbered arrows
% and boxes of the manuscript figures were drawn by hand and are not
% reproduced.

addpath(fileparts(mfilename('fullpath')));
cfg = ulm_paper_config();
set(groot, 'defaultAxesToolbarVisible', 'off'); % keep the toolbar out of exported figures
out_path = fullfile(cfg.figure_path, 'invivo', 'parameters');
if ~exist(out_path, 'dir'), mkdir(out_path); end

names  = ["das", "cf"];
titles = struct('das', 'DAS', 'cf', 'CF');

%% Load the processed chunks
files = dir(fullfile(cfg.results_path, 'invivo_chunk_*.mat'));
assert(~isempty(files), 'No results found in %s. Run process_invivo first.', cfg.results_path);
fprintf('Found %d processed chunks (%d frames).\n', numel(files), 800*numel(files));

for i = 1:numel(files)
    r = load(fullfile(files(i).folder, files(i).name));
    if i == 1
        scan = uff.linear_scan('x_axis', r.scan_x_axis, 'z_axis', r.scan_z_axis);
        for name = names, im.(name) = 0; counts.(name) = 0; end
    end
    for name = names
        % density image from the interpolated tracks
        [img, x_axis, z_axis] = ulm_density_image(r.(name).tracks_interp, scan, cfg.ulm.resolution);
        im.(name) = im.(name) + img;
        % number of localizations along the accepted tracks, per ULM pixel
        counts.(name) = counts.(name) + localization_counts(r.(name).tracks, x_axis, z_axis);
    end
end
x_mm = x_axis*1e3; z_mm = z_axis*1e3;
roi_names = ["b", "c", "d"];
show = @(img) (img/max(img(:))).^cfg.display.gamma; % power compression for display

%% Overview of the two reconstructions
fig = figure('Color', 'w', 'Position', [50 50 1500 600]);
tl = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
for name = names
    nexttile(tl);
    imagesc(x_mm, z_mm, show(im.(name)), [0 1]); axis image off; colormap(hot); hold on
    title(titles.(name), 'FontSize', 16);
    for k = 1:numel(roi_names)
        roi_box = cfg.invivo.roi.(roi_names(k));
        rectangle('Position', [roi_box(1) roi_box(3) roi_box(2)-roi_box(1) roi_box(4)-roi_box(3)], 'EdgeColor', 'w', 'LineWidth', 1.5);
        text(mean(roi_box(1:2)), mean(roi_box(3:4)), "(" + roi_names(k) + ")", 'Color', 'w', ...
            'FontWeight', 'bold', 'FontSize', 13, 'HorizontalAlignment', 'center');
    end
    scale_bar(x_mm(1) + 0.6, z_mm(end) - 0.9, 2, '2 mm');
    text(x_mm(end) - 0.6, z_mm(end) - 0.6, count_label(sum(counts.(name)(:))), 'Color', 'w', ...
        'FontWeight', 'bold', 'FontSize', 13, 'HorizontalAlignment', 'right');
end
exportgraphics(fig, fullfile(out_path, 'compare_generic.png'), 'Resolution', 200);

%% Regions of interest with a difference image
% The power-compressed images, as displayed, are normalized and the CF image
% is histogram matched to the DAS image. Positive (orange) is stronger in
% CF, negative (blue) in DAS.
matched.das = match_histogram(show(im.das), show(im.das), cfg.metrics.bins);
matched.cf  = match_histogram(show(im.cf),  show(im.das), cfg.metrics.bins);
difference  = matched.cf - matched.das;

for k = 1:numel(roi_names)
    roi_box = cfg.invivo.roi.(roi_names(k));
    ix = x_mm >= roi_box(1) & x_mm <= roi_box(2); iz = z_mm >= roi_box(3) & z_mm <= roi_box(4);
    fig = figure('Color', 'w', 'Position', [50 50 1700 430]);
    tl = tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    for name = names
        ax = nexttile(tl);
        imagesc(x_mm(ix), z_mm(iz), show(im.(name)(iz, ix)), [0 1]); axis image off; colormap(ax, hot); hold on
        title(titles.(name), 'FontSize', 16);
        text(roi_box(2) - 0.08, roi_box(4) - 0.08, count_label(sum(counts.(name)(iz, ix), 'all')), 'Color', 'w', ...
            'FontWeight', 'bold', 'FontSize', 13, 'HorizontalAlignment', 'right');
        if name == "das", scale_bar(roi_box(1) + 0.08, roi_box(4) - 0.1, 0.2, '200 \mum'); end
    end
    ax = nexttile(tl);
    imagesc(x_mm(ix), z_mm(iz), difference(iz, ix), [-1 1]); axis image off
    colormap(ax, blue_white_orange()); title('Difference', 'FontSize', 16);
    cb = colorbar; cb.Ticks = -1:0.5:1; cb.FontSize = 12;
    cb.Label.String = 'DAS   <   >   CF';
    exportgraphics(fig, fullfile(out_path, "compare_generic" + k + ".png"), 'Resolution', 200);
end

%% Heuristic image indices
% Computed on the same normalized and histogram-matched images as the
% difference image.
values = zeros(numel(names), 3);
for i = 1:numel(names)
    [values(i, 1), values(i, 2), values(i, 3)] = ulm_image_metrics(matched.(names(i)), cfg.metrics.window, cfg.metrics.bins);
end

metric_titles = {'Local contrast (MLS)', 'Gradient energy L_D', 'Entropy H [nats]'};
bar_colors = [0.65 0.65 0.65; 0.29 0.55 0.76];
fig = figure('Color', 'w', 'Position', [50 50 1100 380]);
tl = tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
for m = 1:3
    nexttile(tl);
    hb = bar(values(:, m), 0.6, 'FaceColor', 'flat'); hb.CData = bar_colors;
    set(gca, 'XTickLabel', {'DAS', 'CF'}, 'FontSize', 12, 'YGrid', 'on');
    title(metric_titles{m});
end
exportgraphics(fig, fullfile(out_path, 'metrics_comparison.png'), 'Resolution', 200);

fid = fopen(fullfile(out_path, 'invivo_metrics.txt'), 'w');
report(fid, 'OPULM in vivo rat brain, %d chunks (%d frames)\n\n', numel(files), 800*numel(files));
report(fid, '%-10s %10s %10s %10s %16s\n', 'Beamformer', 'MLS', 'L_D', 'H [nats]', 'Localizations');
for i = 1:numel(names)
    report(fid, '%-10s %10.4f %10.5f %10.3f %16d\n', titles.(names(i)), values(i, :), sum(counts.(names(i))(:)));
end
fclose(fid);

%% Local functions
function report(fid, varargin)
% Print to the command window and to the text file.
fprintf(varargin{:});
fprintf(fid, varargin{:});
end

function counts = localization_counts(tracks, x_axis, z_axis)
% Number of raw localizations [z x frame] falling in each ULM pixel.
counts = zeros(numel(z_axis), numel(x_axis));
if isempty(tracks), return, end
points = cell2mat(tracks(:));
iz = round((points(:, 1) - z_axis(1))/(z_axis(2) - z_axis(1))) + 1;
ix = round((points(:, 2) - x_axis(1))/(x_axis(2) - x_axis(1))) + 1;
ok = iz >= 1 & iz <= numel(z_axis) & ix >= 1 & ix <= numel(x_axis);
counts = accumarray([iz(ok) ix(ok)], 1, size(counts));
end

function label = count_label(n)
if n >= 1e6, label = sprintf('%.1f M', n/1e6); else, label = sprintf('%.1f K', n/1e3); end
end

function scale_bar(x, z, length_mm, label)
plot([x x + length_mm], [z z], 'w', 'LineWidth', 5);
text(x + length_mm/2, z + 0.02*length_mm, label, 'Color', 'w', 'FontWeight', 'bold', ...
    'FontSize', 12, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');
end

function map = blue_white_orange()
n = 128;
blue = [0.02 0.19 0.38]; orange = [0.50 0.15 0.02]; white = [1 1 1];
lower = blue + (white - blue).*linspace(0, 1, n).'.^0.6;
upper = white + (orange - white).*linspace(0, 1, n).'.^1.6;
map = [lower; upper];
end
