%% Figures and numbers for the OPULM in silico flow simulation
%
% Reads the result files written by process_insilico.m and produces
%
%   opulm_flow/fig1_Target.pdf                    ground truth with the regions of interest
%   opulm_flow/2_per_lambda/fig2_horseshoe.pdf    DAS | CF, horseshoe
%   opulm_flow/2_per_lambda/fig2_flow.pdf         DAS | CF, dense flow region
%   opulm_flow/2_per_lambda/fig2_cross.pdf        DAS | CF, sparse crossing
%   opulm_flow/fig6_gap.pdf                       axial vessel separation
%   opulm_flow/fig7_horizontal_gap.pdf            lateral vessel separation
%   opulm_flow/2_per_lambda/fig3_TP_FP_FN.pdf     TP, FN and FP counts
%   opulm_flow/2_per_lambda/fig5_Jacc.pdf         precision, sensitivity, Jaccard index
%   opulm_flow/insilico_statistics.txt            the numbers quoted in the text
%
% in cfg.figure_path. The file names and sub-folders are the ones used by
% the manuscript, so the folder can be copied onto the manuscript's
% figures/ folder.

addpath(fileparts(mfilename('fullpath')));
cfg = ulm_paper_config();
set(groot, 'defaultAxesToolbarVisible', 'off'); % keep the toolbar out of exported figures
out_path  = fullfile(cfg.figure_path, 'opulm_flow');
out_path2 = fullfile(out_path, '2_per_lambda');
if ~exist(out_path2, 'dir'), mkdir(out_path2); end

names  = ["das", "cf"];
labels = struct('das', 'Delay-and-sum', 'cf', 'Coherence Factor');
colors = struct('das', [0.65 0.65 0.65], 'cf', [0.29 0.55 0.76], 'target', [0.93 0.69 0.13]);

%% Load the processed chunks
files = dir(fullfile(cfg.results_path, 'insilico_chunk_*.mat'));
assert(~isempty(files), 'No results found in %s. Run process_insilico first.', cfg.results_path);
n_chunks = numel(files);
fprintf('Found %d processed chunks.\n', n_chunks);

chunk_ids = zeros(1, n_chunks);
for i = 1:n_chunks
    r = load(fullfile(files(i).folder, files(i).name));
    chunk_ids(i) = r.chunk;
    if i == 1
        lambda = r.lambda;
        scan = uff.linear_scan('x_axis', r.scan_x_axis, 'z_axis', r.scan_z_axis);
        for name = names
            im.(name) = 0;
            stats.(name) = zeros(n_chunks, 5);
        end
    end
    for name = names
        [img, x_axis, z_axis] = ulm_density_image(r.(name).tracks_interp, scan, cfg.ulm.resolution);
        im.(name) = im.(name) + img;
        stats.(name)(i, :) = sum(r.(name).stats, 1); % [N_true N_loc TP FN FP]
    end
end
pixel = z_axis(2) - z_axis(1); % ULM pixel size [m]

%% Ground-truth image on the same grid
% The true trajectories are rendered with the same accumulator as the
% reconstructions. Only the frames of the processed chunks are used.
T = load(fullfile(cfg.insilico.pala_path, 'PALA_InSilicoFlow_v3_pos_Tracks_dt.mat'), 'Tracks_dt');
frames_per_chunk = 1000;
target_tracks = {};
for i = 1:numel(T.Tracks_dt)
    t = T.Tracks_dt{i}; % [x y z frame], positions in wavelengths
    t = t(ismember(ceil(t(:,4)/frames_per_chunk), chunk_ids), :);
    if size(t, 1) < 2, continue, end
    % interpolate so that consecutive points are less than half a ULM pixel apart
    step = max(vecnorm(diff(t(:, [3 1])), 2, 2))*lambda/pixel;
    k = 1:1/ceil(2*step + 1):size(t, 1);
    target_tracks{end+1, 1} = interp1(1:size(t, 1), t(:, [3 1])*lambda, k); %#ok<SAGROW>
end
im.target = ulm_density_image(target_tracks, scan, cfg.ulm.resolution);

show = @(img) img.^cfg.display.gamma; % power compression for display
x_mm = x_axis*1e3; z_mm = z_axis*1e3;

%% Fig. 1: ground truth and regions of interest
roi = cfg.insilico.roi;
roi_names  = ["horseshoe", "flow", "cross", "vertical_gap", "horizontal_gap"];
roi_labels = ["(a) Horseshoe", "(b) Flow paths", "(c) Crossing", "(d) Vertical gap", "(e) Horizontal gap"];

fig = figure('Color', 'k', 'Position', [50 50 1400 820]);
imagesc(x_mm, z_mm, show(im.target)); axis image off; colormap(hot);
hold on
for i = 1:numel(roi_names)
    b = roi.(roi_names(i));
    rectangle('Position', [b(1) b(3) b(2)-b(1) b(4)-b(3)], 'EdgeColor', 'w', 'LineWidth', 1);
    if roi_names(i) == "horizontal_gap"
        text(b(1) - 0.08, b(4), roi_labels(i), 'Color', 'w', 'FontWeight', 'bold', 'FontSize', 11, ...
            'Rotation', 90, 'VerticalAlignment', 'bottom');
    else
        text(b(2), b(3) - 0.03, roi_labels(i), 'Color', 'w', 'FontWeight', 'bold', 'FontSize', 11, ...
            'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom');
    end
end
scale_bar(x_mm(1) + 0.5, z_mm(end) - 0.6, 1, '1 mm');
exportgraphics(fig, fullfile(out_path, 'fig1_Target.pdf'), 'BackgroundColor', 'k');

%% Fig. 5: structural regions of interest, DAS (left) and CF (right)
for roi_name = ["horseshoe", "flow", "cross"]
    b = roi.(roi_name);
    ix = x_mm >= b(1) & x_mm <= b(2); iz = z_mm >= b(3) & z_mm <= b(4);
    fig = figure('Color', 'w', 'Position', [50 50 1200 560]);
    tl = tiledlayout(1, 2, 'TileSpacing', 'tight', 'Padding', 'tight');
    % common color scale for the two beamformers
    c_max = max([max(im.das(iz, ix), [], 'all'), max(im.cf(iz, ix), [], 'all')]);
    for name = names
        nexttile(tl);
        imagesc(x_mm(ix), z_mm(iz), show(im.(name)(iz, ix)), [0 show(c_max)]);
        axis image off; colormap(hot);
        text(0.02, 0.96, labels.(name), 'Units', 'normalized', 'Color', 'w', 'FontSize', 14);
    end
    exportgraphics(fig, fullfile(out_path2, "fig2_" + roi_name + ".pdf"));
end

%% Figs. 6 and 7: axial and lateral vessel separation
% Two canals slowly separate. For every position along the canals the
% profile across them is thresholded at 5 % of the maximum of the ground
% truth image, and the gap is the widest run of pixels below the threshold
% between the canals. The simulated distance on the x-axis is a straight
% line fitted to the gap measured on the ground truth image, since the
% canals separate linearly.
threshold = cfg.insilico.gap_threshold*max(im.target(:));
gap_rois  = ["vertical_gap", "horizontal_gap"];
gap_files = ["fig6_gap.pdf", "fig7_horizontal_gap.pdf"];
for g = 1:2
    b = roi.(gap_rois(g));
    ix = x_mm >= b(1) & x_mm <= b(2); iz = z_mm >= b(3) & z_mm <= b(4);
    for name = [names "target"]
        crop.(name) = im.(name)(iz, ix);
        % make the canals run along the second dimension
        if gap_rois(g) == "horizontal_gap", crop.(name) = crop.(name).'; end
        gap.(name) = canal_gap(crop.(name) >= threshold)*pixel/lambda; % [wavelengths]
    end
    position = 1:numel(gap.target);
    valid = gap.target > 0;
    p = polyfit(position(valid), gap.target(valid), 1);
    simulated = polyval(p, position);
    keep = simulated >= 0;
    [simulated, order] = sort(simulated(keep));

    fig = figure('Color', 'w', 'Position', [50 50 1200 640]);
    tl = tiledlayout(3, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    nexttile(tl, [2 3]); hold on; grid on; box on
    marker = struct('target', '^', 'das', 'o', 'cf', 's');
    legend_text = struct('target', 'Target', 'das', labels.das, 'cf', labels.cf);
    for name = ["target", names]
        y = gap.(name)(keep); y = y(order);
        plot(simulated, y, ['-' marker.(name)], 'Color', colors.(name), 'LineWidth', 1.5, ...
            'MarkerFaceColor', colors.(name), 'MarkerIndices', 1:round(numel(y)/16):numel(y), ...
            'DisplayName', legend_text.(name));
    end
    xlim([0 simulated(end)]);
    xlabel('Simulated canal to canal distance [\lambda]');
    ylabel('Measured canal to canal distance [\lambda]');
    title(sprintf('Measured gap (threshold %.0f %% of the target maximum)', 100*cfg.insilico.gap_threshold));
    legend('Location', 'northwest'); set(gca, 'FontSize', 12);
    for name = ["target", names]
        nexttile(tl);
        imagesc(show(crop.(name)), [0 show(max(crop.target(:)))]);
        axis off; colormap(hot); title(legend_text.(name));
    end
    exportgraphics(fig, fullfile(out_path, gap_files(g)));
end

%% Fig. 8: TP, FN and FP counts over all processed frames
total = structfun(@(s) sum(s, 1), stats, 'UniformOutput', false);
fig = figure('Color', 'w', 'Position', [50 50 1200 300]); hold on
shade = [0.75 0.5 0]; % FP lightest, then FN, then TP
for i = 1:2
    name = names(i); c = colors.(name);
    tp = total.(name)(3); fn = total.(name)(4); fp = total.(name)(5);
    edges = [-(fn + fp), -fn, 0, tp];
    for k = 1:3
        patch(edges([k k+1 k+1 k]), i + [-0.4 -0.4 0.4 0.4], c + (1 - c)*shade(k), 'EdgeColor', 'k');
        text(mean(edges(k:k+1)), i, sprintf('%.0fk', (edges(k+1) - edges(k))/1e3), ...
            'HorizontalAlignment', 'center', 'FontSize', 12);
    end
end
n_true = total.das(1);
xline(n_true, '--', 'Max', 'Color', [0.5 0.5 0.5], 'LabelOrientation', 'horizontal');
xline(0, 'k');
set(gca, 'YTick', 1:2, 'YTickLabel', {'DAS', 'CF'}, 'FontSize', 12, 'XGrid', 'on');
xt = xticks; xticklabels(compose('%gk', xt/1e3));
xlabel('False (FP, FN)   |   True (TP)');
xlim([-0.5 1.05]*n_true); ylim([0.4 2.6]);
exportgraphics(fig, fullfile(out_path2, 'fig3_TP_FP_FN.pdf'));

%% Fig. 9: precision, sensitivity and Jaccard index, mean and std over chunks
metric_names = {'Precision', 'Sensitivity', 'Jaccard Index'};
for name = names
    s = stats.(name); tp = s(:,3); fn = s(:,4); fp = s(:,5);
    metrics.(name) = 100*[tp./(tp + fp), tp./(tp + fn), tp./(tp + fn + fp)];
end
fig = figure('Color', 'w', 'Position', [50 50 1400 300]);
tl = tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
for m = 1:3
    nexttile(tl); hold on
    for i = 1:2
        name = names(i);
        mu = mean(metrics.(name)(:, m)); sigma = std(metrics.(name)(:, m));
        barh(i, mu, 0.9, 'FaceColor', colors.(name));
        errorbar(mu, i, sigma, 'horizontal', 'k', 'LineWidth', 1, 'CapSize', 8);
        text(mu - 8, i, sprintf('%.1f', mu), 'HorizontalAlignment', 'right', 'FontSize', 11);
        if m == 1, text(3, i, labels.(name), 'FontSize', 12); end
    end
    title(metric_names{m}, 'HorizontalAlignment', 'left', 'Position', [0 2.55]);
    set(gca, 'YTick', [], 'XTick', 0:25:100, 'XGrid', 'on', 'FontSize', 11);
    xlim([0 100]); ylim([0.5 2.5]);
end
exportgraphics(fig, fullfile(out_path2, 'fig5_Jacc.pdf'));

%% Numbers quoted in the text
fid = fopen(fullfile(out_path, 'insilico_statistics.txt'), 'w');
report(fid, 'OPULM in silico flow, lambda/2 sampling, %d chunks (%d frames)\n\n', n_chunks, n_chunks*frames_per_chunk);
report(fid, '%-18s %10s %10s %10s %10s\n', '', 'N true', 'TP', 'FN', 'FP');
for name = names
    report(fid, '%-18s %10d %10d %10d %10d\n', labels.(name), total.(name)([1 3 4 5]));
end
report(fid, '\nMean +/- standard deviation over the chunks [%%]\n');
report(fid, '%-18s %16s %16s %16s\n', '', metric_names{:});
for name = names
    v = [mean(metrics.(name)); std(metrics.(name))];
    report(fid, '%-18s %9.1f +/- %-4.1f %8.1f +/- %-4.1f %8.1f +/- %-4.1f\n', labels.(name), v(:));
end
fclose(fid);

%% Local functions
function report(fid, varargin)
% Print to the command window and to the text file.
fprintf(varargin{:});
fprintf(fid, varargin{:});
end

function gap = canal_gap(mask)
% Width, in pixels, of the widest below-threshold run between the outermost
% above-threshold pixels of every column of the mask.
gap = zeros(1, size(mask, 2));
for i = 1:size(mask, 2)
    first = find(mask(:, i), 1, 'first');
    last  = find(mask(:, i), 1, 'last');
    if isempty(first), gap(i) = NaN; continue, end
    below = ~mask(first:last, i).';
    edges = diff([0 below 0]);
    runs  = find(edges == -1) - find(edges == 1);
    if ~isempty(runs), gap(i) = max(runs); end
end
end

function scale_bar(x, z, length_mm, label)
plot([x x + length_mm], [z z], 'w', 'LineWidth', 5);
text(x + length_mm/2, z - 0.08, label, 'Color', 'w', 'FontSize', 12, ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
end
