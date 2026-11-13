%% Figures and numbers for the OPULM in vivo rat-brain data
%
% Reads the result files written by process_invivo.m and produces, in
% cfg.figure_path/invivo/parameters,
%
%   compare_generic.png             DAS | CF overview, generic parameters
%   compare_generic1.png ... 3.png  regions (b), (c), (d): DAS | CF | difference
%   compare_tuned*.png              the same for the simulation-tuned parameters
%   compare_generic_tuned*.png      DAS generic against CF tuned
%   metrics_comparison.png          heuristic image indices of the four images
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

conditions = ["das_generic", "cf_generic", "das_tuned", "cf_tuned"];
titles = struct('das_generic', 'DAS (generic)', 'cf_generic', 'CF (generic)', ...
                'das_tuned', 'DAS (tuned)', 'cf_tuned', 'CF (tuned)');

%% Load the processed chunks
files = dir(fullfile(cfg.results_path, 'invivo_chunk_*.mat'));
assert(~isempty(files), 'No results found in %s. Run process_invivo first.', cfg.results_path);
fprintf('Found %d processed chunks (%d frames).\n', numel(files), 800*numel(files));

for i = 1:numel(files)
    r = load(fullfile(files(i).folder, files(i).name));
    if i == 1
        scan = uff.linear_scan('x_axis', r.scan_x_axis, 'z_axis', r.scan_z_axis);
        for c = conditions, im.(c) = 0; counts.(c) = 0; end
    end
    for c = conditions
        % density image from the interpolated tracks
        [img, x_axis, z_axis] = ulm_density_image(r.(c).tracks_interp, scan, cfg.ulm.resolution);
        im.(c) = im.(c) + img;
        % number of localizations along the accepted tracks, per ULM pixel
        counts.(c) = counts.(c) + localization_counts(r.(c).tracks, x_axis, z_axis);
    end
end
x_mm = x_axis*1e3; z_mm = z_axis*1e3;

%% Comparison figures: overview and three regions with a difference image
pairs = {"das_generic", "cf_generic", "compare_generic"
         "das_tuned",   "cf_tuned",   "compare_tuned"
         "das_generic", "cf_tuned",   "compare_generic_tuned"};
roi_names = ["b", "c", "d"];
show = @(img) (img/max(img(:))).^cfg.display.gamma; % power compression for display

for p = 1:size(pairs, 1)
    a = pairs{p, 1}; b = pairs{p, 2};

    % Overview
    fig = figure('Color', 'w', 'Position', [50 50 1500 600]);
    tl = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    for c = [a b]
        nexttile(tl);
        imagesc(x_mm, z_mm, show(im.(c)), [0 1]); axis image off; colormap(hot); hold on
        title(titles.(c), 'FontSize', 16);
        for k = 1:numel(roi_names)
            roi_box = cfg.invivo.roi.(roi_names(k));
            rectangle('Position', [roi_box(1) roi_box(3) roi_box(2)-roi_box(1) roi_box(4)-roi_box(3)], 'EdgeColor', 'w', 'LineWidth', 1.5);
            text(mean(roi_box(1:2)), mean(roi_box(3:4)), "(" + roi_names(k) + ")", 'Color', 'w', ...
                'FontWeight', 'bold', 'FontSize', 13, 'HorizontalAlignment', 'center');
        end
        scale_bar(x_mm(1) + 0.6, z_mm(end) - 0.9, 2, '2 mm');
        text(x_mm(end) - 0.6, z_mm(end) - 0.6, count_label(sum(counts.(c)(:))), 'Color', 'w', ...
            'FontWeight', 'bold', 'FontSize', 13, 'HorizontalAlignment', 'right');
    end
    exportgraphics(fig, fullfile(out_path, pairs{p, 3} + ".png"), 'Resolution', 200);

    % Difference image: both images normalized, the second one histogram
    % matched to the first. Positive (orange) is stronger in the second image.
    reference  = match_histogram(im.(a), im.(a), cfg.metrics.bins);
    matched    = match_histogram(im.(b), im.(a), cfg.metrics.bins);
    difference = matched - reference;

    for k = 1:numel(roi_names)
        roi_box = cfg.invivo.roi.(roi_names(k));
        ix = x_mm >= roi_box(1) & x_mm <= roi_box(2); iz = z_mm >= roi_box(3) & z_mm <= roi_box(4);
        fig = figure('Color', 'w', 'Position', [50 50 1700 430]);
        tl = tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
        for c = [a b]
            ax = nexttile(tl);
            imagesc(x_mm(ix), z_mm(iz), show(im.(c)(iz, ix)), [0 1]); axis image off; colormap(ax, hot); hold on
            title(titles.(c), 'FontSize', 16);
            text(roi_box(2) - 0.08, roi_box(4) - 0.08, count_label(sum(counts.(c)(iz, ix), 'all')), 'Color', 'w', ...
                'FontWeight', 'bold', 'FontSize', 13, 'HorizontalAlignment', 'right');
            if c == a, scale_bar(roi_box(1) + 0.08, roi_box(4) - 0.1, 0.2, '200 \mum'); end
        end
        ax = nexttile(tl);
        imagesc(x_mm(ix), z_mm(iz), difference(iz, ix), [-1 1]); axis image off
        colormap(ax, blue_white_orange()); title('Difference', 'FontSize', 16);
        cb = colorbar; cb.Ticks = -1:0.5:1; cb.FontSize = 12;
        cb.Label.String = sprintf('%s   <   >   %s', extractBefore(titles.(a), ' '), extractBefore(titles.(b), ' '));
        exportgraphics(fig, fullfile(out_path, pairs{p, 3} + k + ".png"), 'Resolution', 200);
    end
end

%% Heuristic image indices
% All four images are normalized and histogram matched to the same
% reference (DAS, generic parameters) before the indices are computed.
order = ["cf_generic", "das_generic", "cf_tuned", "das_tuned"];
values = zeros(numel(order), 3);
for i = 1:numel(order)
    matched = match_histogram(im.(order(i)), im.das_generic, cfg.metrics.bins);
    [values(i, 1), values(i, 2), values(i, 3)] = ulm_image_metrics(matched, cfg.metrics.window, cfg.metrics.bins);
end

metric_titles = {'Local contrast (MLS)', 'Gradient energy L_D', 'Entropy H [nats]'};
bar_colors = [0.20 0.55 0.75; 0.93 0.69 0.13; 0.20 0.70 0.55; 0.83 0.57 0.72];
fig = figure('Color', 'w', 'Position', [50 50 1400 420]);
tl = tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
for m = 1:3
    nexttile(tl);
    hb = bar(values(:, m), 'FaceColor', 'flat'); hb.CData = bar_colors;
    set(gca, 'XTickLabel', {'CF generic', 'DAS generic', 'CF tuned', 'DAS tuned'}, 'FontSize', 12, 'YGrid', 'on');
    ylim([min(values(:, m)) - 0.5*(max(values(:, m)) - min(values(:, m))), max(values(:, m)) + 0.2*(max(values(:, m)) - min(values(:, m)))]);
    title(metric_titles{m});
end
exportgraphics(fig, fullfile(out_path, 'metrics_comparison.png'), 'Resolution', 200);

fid = fopen(fullfile(out_path, 'invivo_metrics.txt'), 'w');
report(fid, 'OPULM in vivo rat brain, %d chunks (%d frames)\n\n', numel(files), 800*numel(files));
report(fid, '%-14s %10s %10s %10s %16s\n', 'Condition', 'MLS', 'L_D', 'H [nats]', 'Localizations');
for i = 1:numel(order)
    report(fid, '%-14s %10.4f %10.5f %10.3f %16d\n', titles.(order(i)), values(i, :), sum(counts.(order(i))(:)));
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
