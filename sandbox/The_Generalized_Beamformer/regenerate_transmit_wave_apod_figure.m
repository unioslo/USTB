%% Regenerate Fig. "transmit_wave_apod" for the Generalized Beamformer paper
%
% Panels (a), (b) and (c) show the transmit wave apodization weight maps
% for scanline, multiple-line (MLA) and RTB beamforming. They share the
% SAME colorbar range so they are directly comparable. This script
% regenerates all six panels with a common colour scale ([0 1] for the
% weight maps, a common dynamic range for the images).
%
% The original generating script was not checked in, so this is a clean
% reimplementation based on FI_coherence_factor.m and the IUS2018 apodization
% plotting pattern. Verify that the MLA/RTB parameters below match the values
% reported in the manuscript before using the output.
%
% Output PNGs are written with the exact filenames referenced by
% main_elsevier.tex so no LaTeX changes are required.

clear all; %#ok<CLALL>
close all;

%% Dataset -----------------------------------------------------------------
url        = tools.zenodo_dataset_files_base();
local_path = [ustb_path(), '/data/'];
filename   = 'P4_FI_121444_45mm_focus.uff';
end_depth  = 70e-3;
tools.download(filename, url, local_path);

channel_data = uff.read_object([local_path, filename], '/channel_data');
channel_data.N_frames = 1;

% Fix origin bug (as in FI_coherence_factor.m)
for tx = 1:channel_data.N_waves
    channel_data.sequence(tx).origin.x = 0;
end

%% Scan parameters ---------------------------------------------------------
% Each method builds its own scan inside the loop, because the scanline MLA
% panel needs MLA(1)x more azimuth lines than transmits, while scanline and
% RTB use one line per transmit. A single shared scan cannot satisfy all the
% scanline-apodization asserts at once.
depth_axis  = linspace(5e-3, end_depth, 1024).';
azimuth_min = channel_data.sequence(1).source.azimuth;
azimuth_max = channel_data.sequence(end).source.azimuth;

% Transmit event to illustrate: a beam ~1/3 from one side (off-centre so the
% steering of the wedge/lines is visible). Use round(2*N/3) for the other side.
selected_tx = round(channel_data.N_waves / 3);

% Common display ranges for all panels.
apod_clim      = [0 1];   % shared colour range for the weight maps (a)-(c)
dynamic_range  = 60;      % dB, shared range for the single-tx images (d)-(f)

out_dir  = 'figures/transmit_wave_apodization';
if ~exist(out_dir, 'dir'); mkdir(out_dir); end

%% Configure the three apodization strategies ------------------------------
% mla_az = number of azimuth lines reconstructed per transmit (scan density).
methods = struct('name', {}, 'configure', {}, 'mla_az', {});

methods(1).name = 'scanline';
methods(1).configure = @set_scanline;
methods(1).mla_az = 1;

methods(2).name = 'MLA';
methods(2).configure = @set_mla;
methods(2).mla_az = 3;   % must match set_mla's MLA(1)

methods(3).name = 'RTB';
methods(3).configure = @set_rtb;
methods(3).mla_az = 3;

%% Loop over methods -------------------------------------------------------
for m = 1:numel(methods)
    % Per-method scan: azimuth density equals this method's MLA azimuth factor.
    azimuth_axis = linspace(azimuth_min, azimuth_max, ...
                            channel_data.N_waves * methods(m).mla_az)';
    scan = uff.sector_scan('azimuth_axis', azimuth_axis, 'depth_axis', depth_axis);

    x_matrix = reshape(scan.x, [scan.N_depth_axis scan.N_azimuth_axis]);
    z_matrix = reshape(scan.z, [scan.N_depth_axis scan.N_azimuth_axis]);

    mid = midprocess.das();
    mid.channel_data = channel_data;
    mid.scan         = scan;
    mid.dimension    = dimension.receive();  % keep per-transmit images
    mid.pw_margin    = 5e-3;
    mid.receive_apodization.window   = uff.window.hamming;
    mid.receive_apodization.f_number = 0.5;

    methods(m).configure(mid);

    b_data = mid.go();

    % --- Transmit wave apodization weight map for the selected transmit ---
    tx_apod = mid.transmit_apodization.data;                 % [Npix x Nwaves]
    w_map   = reshape(tx_apod(:, selected_tx), ...
                      scan.N_depth_axis, scan.N_azimuth_axis);

    fig_a = figure('Color', 'w');
    ax_a  = axes(fig_a);
    pcolor(ax_a, x_matrix*1e3, z_matrix*1e3, w_map);
    shading(ax_a, 'flat');
    set(ax_a, 'YDir', 'reverse');
    axis(ax_a, 'tight', 'equal');
    caxis(ax_a, apod_clim);                                  % <-- shared range
    colormap(ax_a, 'parula');
    colorbar(ax_a);                                          % no text label
    xlabel(ax_a, 'x [mm]'); ylabel(ax_a, 'z [mm]');
    set(ax_a, 'FontSize', 22);
    save_png(fig_a, sprintf('%s/%s_apod_redone.png', out_dir, methods(m).name));

    % --- Single-transmit image (illustration) ----------------------------
    % Multiply the single-transmit image by its transmit wave apodization so
    % the panel shows which region that transmit actually contributes.
    env      = abs(b_data.data(:, 1, selected_tx)) .* tx_apod(:, selected_tx);
    env_dB   = 20*log10(env ./ max(env(:)) + eps);
    img_map  = reshape(env_dB, scan.N_depth_axis, scan.N_azimuth_axis);

    fig_b = figure('Color', 'w');
    ax_b  = axes(fig_b);
    pcolor(ax_b, x_matrix*1e3, z_matrix*1e3, img_map);
    shading(ax_b, 'flat');
    set(ax_b, 'YDir', 'reverse');
    axis(ax_b, 'tight', 'equal');
    caxis(ax_b, [-dynamic_range 0]);                         % shared image range
    colormap(ax_b, 'gray');
    colorbar(ax_b);                                          % no text label
    xlabel(ax_b, 'x [mm]'); ylabel(ax_b, 'z [mm]');
    set(ax_b, 'FontSize', 22);
    save_png(fig_b, sprintf('%s/%s_image_redone.png', out_dir, methods(m).name));
end

%% ---- Helper functions ---------------------------------------------------
% NB: the scanline window indexes MLA(2), so MLA must be a 2-element
% [azimuth elevation] vector, not a scalar.
function set_scanline(mid)
    mid.transmit_apodization.window      = uff.window.scanline;
    mid.transmit_apodization.MLA         = [1 1];
    mid.transmit_apodization.MLA_overlap = 0;
end

function set_mla(mid)
    mid.transmit_apodization.window      = uff.window.scanline;
    mid.transmit_apodization.MLA         = [3 1];
    mid.transmit_apodization.MLA_overlap = 8;
end

function set_rtb(mid)
    % Retrospective transmit beamforming: wide Hamming transmit apodization.
    mid.transmit_apodization.window           = uff.window.hamming;
    mid.transmit_apodization.f_number         = 3;    % f#_Tx (verify)
    mid.transmit_apodization.minimum_aperture = 2e-3;
end

function save_png(fig, filepath)
    set(fig, 'InvertHardcopy', 'off');
    set(fig, 'PaperPositionMode', 'auto');
    ax = findobj(fig, 'Type', 'axes');
    set(ax, 'LooseInset', get(ax, 'TightInset'));  % trim axis whitespace
    if exist('exportgraphics', 'file')
        % exportgraphics crops tightly to the content (axes + colorbar),
        % removing the surrounding figure margins.
        exportgraphics(fig, filepath, 'Resolution', 300);
    else
        saveas(fig, filepath);
    end
    fprintf('Saved %s\n', filepath);
end
