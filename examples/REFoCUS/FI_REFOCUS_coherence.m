% Focused Imaging (FI) using REFoCUS
%
% This example illustrates and compares REFoCUS to contentional scanline
% imaging and retrospetive transmit beamforming (RTB) for a phased array
% focused transmission
%
% Author: Ole Marius Hoel Rindal
%


% Clear up
clear all;close all;
    
% Read the data, poentitally download it
url='http://ustb.no/datasets/';      % if not found downloaded from here
local_path = [ustb_path(),'/data/']; % location of example data
addpath(local_path);

% Choose dataset
%filename='Verasonics_P2-4_parasternal_long_small.uff';
filename='FI_P4_point_scatterers.uff';
% check if the file is available in the'
% local path or downloads otherwise
tools.download(filename, url, local_path);
channel_data = uff.read_object([local_path, filename],'/channel_data');
channel_data.N_frames = 1;

%This is an older dataset, so we need to set the origin.
for seq = 1:channel_data.N_waves
    channel_data.sequence(seq).origin.xyz = [0,0,0];
end

%% Do beamforming
depth_axis=linspace(0e-3,60e-3,512).';
azimuth_axis=zeros(channel_data.N_waves,1);
for n=1:channel_data.N_waves
    azimuth_axis(n) = channel_data.sequence(n).source.azimuth;
end

%% Beamform the image with 4 MLA's per scan line with two overlapping
MLA = 1;
scan_MLA=uff.sector_scan('azimuth_axis',...
    linspace(channel_data.sequence(1).source.azimuth,channel_data.sequence(end).source.azimuth,...
    length(channel_data.sequence)*MLA)','depth_axis',depth_axis);

%%
mid_scan_line = midprocess.das();
mid_scan_line.channel_data = channel_data;
mid_scan_line.dimension = dimension.transmit();
mid_scan_line.scan = scan_MLA;
mid_scan_line.receive_apodization.window=uff.window.none;
mid_scan_line.receive_apodization.f_number = 1.7;
mid_scan_line.transmit_apodization.window = uff.window.scanline;
b_data_delayed_scan_line = mid_scan_line.go()


%%

mid_RTB = midprocess.das();
mid_RTB.channel_data = channel_data;
mid_RTB.dimension = dimension.transmit();
mid_RTB.receive_apodization.window=uff.window.tukey25;
mid_RTB.receive_apodization.f_number = 1.7;
mid_RTB.spherical_transmit_delay_model = spherical_transmit_delay_model.unified;
mid_RTB.transmit_apodization.MLA = MLA;
mid_RTB.transmit_apodization.MLA_overlap = 2;
mid_RTB.transmit_apodization.window = uff.window.tukey25; 
mid_RTB.transmit_apodization.f_number = 4;
mid_RTB.transmit_apodization.minimum_aperture = [3e-3 3e-3];
mid_RTB.scan = scan_MLA;
b_data_delayed_RTB = mid_RTB.go();



%%
cc = postprocess.coherent_compounding()
cc.input = b_data_delayed_RTB;
b_data_RTB_uncompensated = cc.go();
%% Plot the image 
b_data_RTB_uncompensated.plot(4,['DAS with MLAs']);


tx_apod = mid_RTB.transmit_apodization.data;
weighting = 1./sum(tx_apod,2);
b_data_RTB = uff.beamformed_data(b_data_RTB_uncompensated);
b_data_RTB.data = b_data_RTB_uncompensated.data.*weighting;
%%
%channel_data.probe.N = 64;
%channel_data.probe

% channel_data_RF.probe = channel_data.probe;

% %%
refocus = preprocess.refocus()
refocus.input = channel_data;
channel_data_STAI = refocus.go()
%%
mid_STAI = midprocess.das()
mid_STAI.channel_data=channel_data_STAI;
mid_STAI.dimension = dimension.transmit();
mid_STAI.scan=scan_MLA;
mid_STAI.transmit_apodization.window=uff.window.none;
mid_STAI.transmit_apodization.MLA = MLA;
mid_STAI.receive_apodization.window=uff.window.boxcar;
mid_STAI.receive_apodization.f_number = 1.7;
b_data_delayed_REFOCUS = mid_STAI.go()


%%

calculate_VZC_curves(b_data_delayed_scan_line,b_data_delayed_RTB,b_data_delayed_REFOCUS,scan_MLA)
%%
cc = postprocess.coherent_compounding()
cc.input = b_data_delayed_REFOCUS;
b_data_REFOCUS = cc.go();
b_data_REFOCUS.plot()


%%
b_data_compare = uff.beamformed_data(b_data_REFOCUS);
b_data_compare.data(:,1) = b_data_RTB_uncompensated.data./max(b_data_RTB_uncompensated.data);
b_data_compare.data(:,2) = b_data_RTB.data./max(b_data_RTB.data);
b_data_compare.data(:,3) = b_data_REFOCUS.data./max(b_data_REFOCUS.data);
b_data_compare.plot([],['1 = FI, 2 = REFOCUS'],60)
%%
CF = postprocess.coherence_factor()
CF.input = b_data_delayed_REFOCUS;
b_data_CF = CF.go()
b_data_CF.plot()
CF_REFOCUS = uff.beamformed_data(CF.CF);

CF.input = b_data_delayed_RTB;
b_data_CF = CF.go()
CF_RTB = uff.beamformed_data(CF.CF);

CF_compare = uff.beamformed_data(CF_REFOCUS)
CF_compare.data(:,1) = CF_RTB.data;
CF_compare.data(:,2) = CF_REFOCUS.data;
CF_compare.plot([],[],[],['none'])
colormap default
caxis([0 1])



%%
channel_data_single_tx = uff.read_object([local_path, filename],'/channel_data');
channel_data_single_tx.N_frames = 1;
%%
channel_data_single_tx.sequence = [];
channel_data_single_tx.data = [];

channel_data_single_tx.sequence = channel_data.sequence(58);
channel_data_single_tx.data = channel_data.data(:,:,58);

%%

refocus = preprocess.refocus()
refocus.input = channel_data_single_tx;
channel_data_STAI_single_tx = refocus.go()

mid_STAI.channel_data = channel_data_STAI_single_tx;
mid_STAI.dimension = dimension.both();
b_data_REFOCUS_single_tx = mid_STAI.go()
b_data_REFOCUS_single_tx.plot()

%%
mid_RTB.channel_data = channel_data_single_tx;
mid_RTB.transmit_apodization.window = uff.window.none;
mid_RTB.dimension = dimension.both();
b_data_RTB_single_tx = mid_RTB.go()
b_data_RTB_single_tx.plot()

%% Compare RTB and REFoCUS on single tx
single_tx_compare = uff.beamformed_data(b_data_REFOCUS_single_tx)
single_tx_compare.data(:,:,1,1) = b_data_REFOCUS_single_tx.data./max(b_data_REFOCUS_single_tx.data(:));
single_tx_compare.data(:,:,1,2) = b_data_RTB_single_tx.data./max(b_data_RTB_single_tx.data(:));
single_tx_compare.plot()
