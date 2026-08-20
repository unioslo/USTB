%% In silico correction of blocked array using RTB and REFoCUS
%
% Creating the simulated results in the paper:
%
% A.E. Vrålstad, S.-E. Måsøy, T.G. Bjåstad, A.R. Sørnes and O.M.H. Rindal,
% "Retrospective transmit correction of blocked arrays applied to cardiac
% ultrasound imaging" in XX. doi:YY.ZZZZ/XX.QQQQQQQQ.
%
% This script creates Fig.3-4 in the paper. 
%
% This code uses the UltraSound ToolBox (USTB) and you'll need to download 
% it first to successfully rund this code. To know more about the USTB 
% visit http://www.ustb.no/
%
% by Anders E. Vrålstad and Ole Marius Hoel Rindal
%% Clear environment
clear all; close all;
%% Dataset source
% Read the data, potentially download it
url = tools.zenodo_dataset_files_base();
% if not found downloaded from here
local_path = [ustb_path(),'/data/']; % location of example data
addpath(local_path);

%% Speckle chamber ROI — all simulated blockage levels (published HTML uses snapnow)
% Red rectangle matches gCNR `center_rectangle` = [-0.006, 0.07, 0.007, 0.04] m on the
% Cartesian scan-converted grid (shown here in mm): [-6, 70, 7, 40].
% Lightweight RTB-only pass per dataset so publish stays tractable.

speckle_chamber_mm = [-6, 70, 7, 40];
dataset_roi = {
    'speckle_sim_FI_P4_probe_apod_1_speckle_long_many_angles.uff', 'Full aperture (no element blockage)'
    'speckle_sim_FI_P4_probe_apod_2_speckle_long_many_angles.uff', 'One-third of aperture blocked'
    'speckle_sim_FI_P4_probe_apod_3_speckle_long_many_angles.uff', 'Half of aperture blocked'
    };

for r = 1:size(dataset_roi, 1)
    fn_roi = dataset_roi{r, 1};
    roi_title = dataset_roi{r, 2};
    tools.download(fn_roi, url, data_path());
    cd_roi = uff.read_object([data_path(), filesep, fn_roi], '/channel_data');
    cd_roi.data = cd_roi.data ./ max(cd_roi.data(:));

    % Reset wave origins — phased array aperture center is always at [0,0,0]
    for n_w = 1:cd_roi.N_waves
        cd_roi.sequence(n_w).origin = uff.point();
    end

    depth_roi = linspace(0e-3, 110e-3, 512).';
    az_roi = zeros(cd_roi.N_waves, 1);
    for n = 1:cd_roi.N_waves
        az_roi(n) = cd_roi.sequence(n).source.azimuth;
    end
    scan_roi = uff.sector_scan('azimuth_axis', az_roi, 'depth_axis', depth_roi);
    Fnr = cd_roi.sequence(1).source.distance / (max(cd_roi.probe.x) * 2);

    mid_roi = midprocess.das();
    mid_roi.channel_data = cd_roi;
    mid_roi.dimension = dimension.both();
    mid_roi.scan = scan_roi;
    if isempty(which('das_c'))
        mid_roi.code = code.matlab;
    else
        mid_roi.code = code.mex;
    end
    mid_roi.receive_apodization.window = uff.window.boxcar;
    mid_roi.receive_apodization.f_number = 1.7;
    mid_roi.transmit_apodization.window = uff.window.hamming;
    mid_roi.transmit_apodization.f_number = Fnr;
    mid_roi.transmit_apodization.minimum_aperture = 3e-3;
    b_roi = mid_roi.go();

    [RTB_sc_roi, Xr, Zr] = tools.scan_convert(b_roi.get_image(), b_roi.scan.azimuth_axis, b_roi.scan.depth_axis, 1024, 1024);

    figure('Visible', 'off');
    imagesc(Xr * 1e3, Zr * 1e3, RTB_sc_roi, [-60 0]);
    colormap gray;
    colorbar;
    axis image;
    xlabel('x [mm]');
    ylabel('z [mm]');
    title(roi_title, 'Interpreter', 'none');
    xlim([-20 20]);
    ylim([60 110]);
    hold on;
    rectangle(gca, 'Position', speckle_chamber_mm, 'EdgeColor', 'r', 'LineWidth', 2);
    hold off;
    set(findall(gcf, '-property', 'FontSize'), 'FontSize', 14);
    drawnow;
    snapnow;
    close(gcf);
end

%% Primary case — full pipeline (paper figures, gCNR, differences): half aperture blocked
filename = 'speckle_sim_FI_P4_probe_apod_3_speckle_long_many_angles.uff';
tag = 'half';
tools.download(filename, url, data_path());

channel_data = uff.read_object([data_path(), filesep, filename], '/channel_data');
channel_data.data = channel_data.data ./ max(channel_data.data(:));

% Reset wave origins to [0,0,0] — fix_origin_from_source incorrectly sets
% origin.x = source.x for phased arrays where the aperture center is always
% at the probe center regardless of steering angle.
for n = 1:channel_data.N_waves
    channel_data.sequence(n).origin = uff.point();
end

storefolder = ['./Figures/simulated_gCNR_',tag, '/'];
mkdir(storefolder);
%% Run REFoCUS preprocess
tic
REFoCUS = preprocess.refocus();
REFoCUS.input = channel_data;
REFoCUS.use_filter = 0;
REFoCUS.filter_N = 10;
REFoCUS.filter_Wn = [0.05,0.4];
REFoCUS.regularization = @Hinv_tikhonov;
REFoCUS.decode_parameter = 0.01;
REFoCUS.post_pad_samples = 0;
channel_data_REFoCUS = REFoCUS.go();
toc()

%% Create Sector scan
depth_axis=linspace(0e-3,110e-3,512).';
azimuth_axis=zeros(channel_data.N_waves,1);
for n=1:channel_data.N_waves
    azimuth_axis(n) = channel_data.sequence(n).source.azimuth;
end
scan=uff.sector_scan('azimuth_axis',azimuth_axis,'depth_axis',depth_axis);
%% RTB Beamforming
% Calculate F-number
Fnumber = channel_data.sequence(1).source.distance/(max(channel_data.probe.x)*2);

mid=midprocess.das();
mid.channel_data=channel_data;
mid.dimension = dimension.both();
mid.scan=scan;
mid.code = code.mex;
mid.receive_apodization.window=uff.window.boxcar;
mid.receive_apodization.f_number=1.7;
mid.transmit_apodization.window=uff.window.hamming;
mid.transmit_apodization.f_number=Fnumber;
mid.transmit_apodization.minimum_aperture = 3e-3;
b_data_RTB = mid.go();
b_data_RTB.frame_rate = 20;
b_data_RTB.plot([], 'RTB');
%% Store the Original RTB weights for plotting later
b_data_tx_apod = uff.beamformed_data(b_data_RTB);
b_data_tx_apod.data = mid.transmit_apodization.data;
b_data_tx_apod.plot([],['Tx Weights no shift'],[],'none');
colormap default;
%% Change beam geometry for RTB processing
switch tag
    case 'full'
        origin_x = 0;
    case 'third'
        origin_x = max(channel_data.probe.x)*(2*2/3-1);
        Fnumber = Fnumber*3/2;
    case 'half'
        origin_x = max(channel_data.probe.x)*0.5;
        Fnumber = Fnumber*2;
end
channel_data_shifted = uff.channel_data(channel_data);
for seq = 1:channel_data_shifted.N_waves
    channel_data_shifted.sequence(seq).origin.x = origin_x;
end
mid.channel_data = channel_data_shifted;
mid.transmit_apodization.f_number=Fnumber;
b_data_RTB_comp = mid.go();
b_data_RTB_comp.frame_rate = 20;
b_data_RTB_comp.plot([],'Proposed RTB');
%% Store the Compensated RTB weights for plotting later
b_data_tx_apod = uff.beamformed_data(b_data_RTB_comp);
b_data_tx_apod.data = mid.transmit_apodization.data;
b_data_tx_apod.plot([],['Tx Weights with shift'],[],'none');
colormap default;
%% Demodulate REFoCUS RF-data before DAS
demod = preprocess.fast_demodulation();
demod.modulation_frequency = 2.5*10^6;
demod.input = channel_data_REFoCUS;
channel_data_STAI_demod = demod.go();
%% REFoCUS Beamforming
mid_REFoCUS = midprocess.das();
mid_REFoCUS.channel_data=channel_data_STAI_demod;
mid_REFoCUS.dimension = dimension.receive();
mid_REFoCUS.scan=scan;
mid_REFoCUS.code = code.mex;
mid_REFoCUS.transmit_apodization.window=uff.window.boxcar;
mid_REFoCUS.receive_apodization.f_number=1.7;
mid_REFoCUS.receive_apodization.window=uff.window.boxcar;
mid_REFoCUS.transmit_apodization.f_number=1;
b_data_delayed_REFoCUS = mid_REFoCUS.go();
cc = postprocess.coherent_compounding;
cc.input = b_data_delayed_REFoCUS;
b_data_REFoCUS = cc.go();
tools.publish_beamformed_snap(b_data_REFoCUS, 'REFoCUS');

%% Save PNGs
f = figure('Visible', tools.headless_publish_figure_visible());
b_data_RTB.plot(f, 'RTB');
delete(findall(f, 'Type', 'uicontrol'));
clim([-60 0]); xlim([-20 20]);
saveas(f,[storefolder,'RTB_', tag,'.png']);
drawnow; snapnow; close(f);

f = figure('Visible', tools.headless_publish_figure_visible());
b_data_RTB_comp.plot(f, 'RTB Compensated');
delete(findall(f, 'Type', 'uicontrol'));
clim([-60 0]); xlim([-20 20]);
saveas(f,[storefolder,'RTB_compensated_', tag,'.png']);
drawnow; snapnow; close(f);

f = figure('Visible', tools.headless_publish_figure_visible());
b_data_REFoCUS.plot(f, 'REFoCUS');
delete(findall(f, 'Type', 'uicontrol'));
clim([-60 0]); xlim([-20 20]);
saveas(f,[storefolder,'REFoCUS_', tag,'.png']);
drawnow; snapnow; close(f);

%% Comparison (multi-frame: RTB, RTB Compensated, REFoCUS)
b_data_compare = uff.beamformed_data(b_data_RTB);
b_data_compare.data(:,1,1,1) = b_data_RTB.data./max(b_data_RTB.data(:));
b_data_compare.data(:,1,1,2) = b_data_RTB_comp.data./max(b_data_RTB_comp.data(:));
b_data_compare.data(:,1,1,3) = b_data_REFoCUS.data./max(b_data_REFoCUS.data(:))/3;

all_images = squeeze(b_data_compare.get_image());
b_data_compare.data(:,1,1,2) = b_data_compare.data(:,1,1,2) .* median(all_images(:,:,1)./all_images(:,:,2),'all','omitnan');
b_data_compare.data(:,1,1,3) = b_data_compare.data(:,1,1,3) .* median(all_images(:,:,1)./all_images(:,:,3),'all','omitnan');
b_data_compare.frame_rate = 1;
tools.publish_beamformed_snap(b_data_compare);

if usejava('desktop')
    b_data_compare.save_as_gif(['Figures/Comparison_',tag,'.gif']);
end


%% Measure contrast (gCNR)
% Scan-convert images for contrast analysis
[RTB_sc, Xs, Zs] = tools.scan_convert(b_data_RTB.get_image(), b_data_compare.scan.azimuth_axis, b_data_compare.scan.depth_axis, 1024, 1024);
[RTB_comp_sc, ~, ~] = tools.scan_convert(b_data_RTB_comp.get_image(), b_data_compare.scan.azimuth_axis, b_data_compare.scan.depth_axis, 1024, 1024);
[REFoCUS_sc, ~, ~] = tools.scan_convert(b_data_REFoCUS.get_image()-12, b_data_compare.scan.azimuth_axis, b_data_compare.scan.depth_axis, 1024, 1024);
img_cell = {RTB_sc, RTB_comp_sc, REFoCUS_sc};
name_cell = {'RTB', 'RTB Compensated', 'REFoCUS'};

% Define ROI rectangles [x, z, width, height] in metres (same as paper)
center_rectangle = [-0.006, 0.07, 0.007, 0.04];
v1_rect = center_rectangle - [0.008, 0, 0, 0];
v2_rect = center_rectangle + [0.008, 0, 0, 0];
c_rect  = center_rectangle;

% Create binary masks from rectangle positions (no drawrectangle / IPT needed)
v1_binary = rect_to_mask(v1_rect, Xs, Zs);
v2_binary = rect_to_mask(v2_rect, Xs, Zs);
c_binary  = rect_to_mask(c_rect, Xs, Zs);

% Plot ROI image with rectangles overlaid
f_roi = figure('Visible', tools.headless_publish_figure_visible());
imagesc(Xs*1e3, Zs*1e3, img_cell{3}, [-60 0]);
colormap gray; colorbar; axis image;
xlabel('x [mm]'); ylabel('z [mm]');
hold on;
rectangle('Position', v1_rect.*[1e3 1e3 1e3 1e3], 'EdgeColor', 'g', 'LineWidth', 2);
rectangle('Position', v2_rect.*[1e3 1e3 1e3 1e3], 'EdgeColor', 'g', 'LineWidth', 2);
rectangle('Position', c_rect.*[1e3 1e3 1e3 1e3], 'EdgeColor', 'r', 'LineWidth', 2);
hold off;
set(findall(gcf, '-property', 'FontSize'), 'FontSize', 14);
title('ROI regions for gCNR');
drawnow;
tools.publish_snap_now_figure(f_roi);
close(f_roi);

% Compute gCNR for each beamforming method
GCNR = cell(1, numel(img_cell));
f_hist = figure('Visible', tools.headless_publish_figure_visible());
bins = linspace(-120, 0, 256);
for ii = 1:numel(img_cell)
    [p_noise, ~] = hist(img_cell{ii}(c_binary), bins);
    [p_signal, ~] = hist(img_cell{ii}(v1_binary | v2_binary), bins);
    subplot(numel(img_cell), 1, ii);
    plot(bins, p_noise./sum(p_noise), 'Color', '#D95319', 'LineWidth', 2); hold on;
    plot(bins, p_signal./sum(p_signal), 'Color', '#0072BD', 'LineWidth', 2); hold off;
    xlim([-80, 0]);
    legend('Speckle', 'Background', 'Location', 'eastoutside');
    title(sprintf('%s', name_cell{ii}));
    OVL = min(p_noise./sum(p_noise), p_signal./sum(p_signal));
    GCNR{ii} = 1 - sum(OVL);
    ylabel(sprintf('gCNR = %.3f', GCNR{ii}));
end
set(findall(gcf, '-property', 'FontSize'), 'FontSize', 12);
drawnow;
tools.publish_snap_now_figure(f_hist);
close(f_hist);
fprintf('gCNR: RTB=%.3f, RTB Comp=%.3f, REFoCUS=%.3f\n', GCNR{1}, GCNR{2}, GCNR{3});

%% Make Difference Images: of RTBs
all_images = b_data_compare.get_image();
diff = all_images(:,:,2)-all_images(:,:,1)-1.6;
[diff_sc, Xs,Zs] = tools.scan_convert(diff, scan.azimuth_axis, scan.depth_axis,1024,1024);
f = figure('Visible', tools.headless_publish_figure_visible());
imagesc(Xs*1e3,Zs*1e3,diff_sc,[-30,30]);colormap(bluewhitered);colorbar
xlabel('x[mm]'); ylabel('z[mm]'); axis image;
xlim([-20,20]); ylim([60,110]);
title('RTB - RTB Compensated');
set(findall(gcf,'-property','FontSize'),'FontSize',15)
savefig(f,[storefolder,'RTBminusRTBcomp_',tag,'.fig']);
saveas(f,[storefolder,'RTBminusRTBcomp_',tag,'.png']);
drawnow; tools.publish_snap_now_figure(f); close(f);

%% Make Difference Images: RTB comp and REFoCUS 
all_images = b_data_compare.get_image();
diff = all_images(:,:,3)-all_images(:,:,2)-7;
[diff_sc, Xs,Zs] = tools.scan_convert(diff, scan.azimuth_axis, scan.depth_axis,1024,1024);
f = figure('Visible', tools.headless_publish_figure_visible());
imagesc(Xs*1e3,Zs*1e3,diff_sc,[-30,30]);colormap(bluewhitered);colorbar
xlabel('x[mm]'); ylabel('z[mm]'); axis image;
xlim([-20,20]); ylim([60,110]);
title('REFoCUS - RTB Compensated');
set(findall(gcf,'-property','FontSize'),'FontSize',15)
savefig(f,[storefolder,'REFoCUSminusRTBcomp_',tag,'.fig']);
saveas(f,[storefolder,'REFoCUSminusRTBcomp_',tag,'.png']);
drawnow; tools.publish_snap_now_figure(f); close(f);

%% Make Difference Images: RTB and REFoCUS 
all_images = b_data_compare.get_image();
diff = all_images(:,:,3)-all_images(:,:,1)-7;
[diff_sc, Xs,Zs] = tools.scan_convert(diff, scan.azimuth_axis, scan.depth_axis,1024,1024);
f = figure('Visible', tools.headless_publish_figure_visible());
imagesc(Xs*1e3,Zs*1e3,diff_sc,[-30,30]);colormap(bluewhitered);colorbar
xlabel('x[mm]'); ylabel('z[mm]'); axis image;
xlim([-20,20]); ylim([60,110]);
title('REFoCUS - RTB');
set(findall(gcf,'-property','FontSize'),'FontSize',15)
savefig(f,[storefolder,'REFoCUSminusRTB_',tag,'.fig']);
saveas(f,[storefolder,'REFoCUSminusRTB_',tag,'.png']);
drawnow; tools.publish_snap_now_figure(f); close(f);