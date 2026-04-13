%% Focused Imaging (FI) using REFoCUS
%
% This example illustrates and compares REFoCUS to contentional scanline
% imaging and retrospetive transmit beamforming (RTB) for a phased array
% focused transmission.
%
% Refocus was first publised in
%
% Bottenus, N. (2018). Recovery of the Complete Data Set from Focused Transmit 
%   Beams. IEEE Transactions on Ultrasonics, Ferroelectrics, and Frequency Control, 
%   65(1), 30–38. https://doi.org/10.1109/TUFFC.2017.2773495
% 
% and further develop in 
% 
% Ali, R., Herickhoff, C. D., Hyun, D., Dahl, J. J., & Bottenus, N. (2020). 
%  Extending Retrospective Encoding for Robust Recovery of the Multistatic 
%  Data Set. IEEE Transactions on Ultrasonics, Ferroelectrics, and Frequency Control,
%  67(5), 943–956. https://doi.org/10.1109/TUFFC.2019.2961875
% 
% This example reproduces most of the results from:
% Rindal, O. M. H., Vralstad, A., Bjastad, T. G., Austeng, A., & Masoy, S. E. (2022). 
% Coherence from REFoCUS compared to Retrospective Transmit Beamforming. IEEE International Ultrasonics 
% Symposium, IUS, 2022-Octob. https://doi.org/10.1109/IUS54386.2022.9957261
%
%   authors:  Ole Marius Hoel Rindal <omrindal@ifi.uio.no>
%   $Last updated: 2024/11/09$

% Clear up
clear all;close all;
    
% Read the data, poentitally download it
url = tools.zenodo_dataset_files_base();
local_path = [ustb_path(),'/data/']; % location of example data
addpath(local_path);

% Choose dataset
filename='P4_FI_121444_45mm_focus.uff';
% check if the file is available in the'
% local path or downloads otherwise
tools.download(filename, url, local_path);
channel_data = uff.read_object([local_path, filename],'/channel_data');
channel_data.N_frames = 1;

%This is an older dataset, so we need to set the origin.
for seq = 1:channel_data.N_waves
    channel_data.sequence(seq).origin.xyz = [0,0,0];
end

% Define Scan
depth_axis=linspace(0e-3,60e-3,512).';
azimuth_axis=zeros(channel_data.N_waves,1);
for n=1:channel_data.N_waves
    azimuth_axis(n) = channel_data.sequence(n).source.azimuth;
end

MLA = 1;
scan_MLA=uff.sector_scan('azimuth_axis',...
    linspace(channel_data.sequence(1).source.azimuth,channel_data.sequence(end).source.azimuth,...
    length(channel_data.sequence)*MLA)','depth_axis',depth_axis);

%% Conventional scan line beamforming (single line per transmit) 
mid_scan_line = midprocess.das();
mid_scan_line.channel_data = channel_data;
mid_scan_line.dimension = dimension.transmit();
mid_scan_line.scan = scan_MLA;
mid_scan_line.receive_apodization.window=uff.window.none;
mid_scan_line.receive_apodization.f_number = 1.7;
mid_scan_line.transmit_apodization.window = uff.window.scanline;
b_data_delayed_scan_line = mid_scan_line.go()

cc = postprocess.coherent_compounding()
cc.input = b_data_delayed_scan_line;
b_data_scan_line = cc.go();

%% Conventional RTB beamforming using the generalized beamformer
mid_RTB = midprocess.das();
mid_RTB.channel_data = channel_data;
mid_RTB.dimension = dimension.transmit();
mid_RTB.receive_apodization.window=uff.window.none;
mid_RTB.receive_apodization.f_number = 1.7;
%mid_RTB.spherical_transmit_delay_model = spherical_transmit_delay_model.hybrid;
mid_RTB.spherical_transmit_delay_model = spherical_transmit_delay_model.unified;
mid_RTB.transmit_apodization.MLA = MLA;
mid_RTB.transmit_apodization.MLA_overlap = 2;
mid_RTB.transmit_apodization.window = uff.window.tukey25; 
mid_RTB.transmit_apodization.f_number = 4;
mid_RTB.transmit_apodization.minimum_aperture = [3e-3 3e-3];
mid_RTB.scan = scan_MLA;
b_data_delayed_RTB = mid_RTB.go();

%% Compensate for RTB beamforming to get uniform image
cc = postprocess.coherent_compounding()
cc.input = b_data_delayed_RTB;
b_data_RTB_uncompensated = cc.go();

b_data_RTB_uncompensated.plot(4,['DAS with MLAs']);
tx_apod = mid_RTB.transmit_apodization.data;
weighting = 1./sum(tx_apod,2);
b_data_RTB = uff.beamformed_data(b_data_RTB_uncompensated);
b_data_RTB.data = b_data_RTB_uncompensated.data.*weighting;

%% Refocus the channel data using REFOCUS
% This will convert the FI channel data to multistatic (STAI) channel data 
refocus = preprocess.refocus()
refocus.input = channel_data;
channel_data_STAI = refocus.go()

%% Beamforming using 
mid_REFOCUS = midprocess.das()
mid_REFOCUS.channel_data=channel_data_STAI;
mid_REFOCUS.dimension = dimension.transmit();
mid_REFOCUS.scan=scan_MLA;
mid_REFOCUS.transmit_apodization.window=uff.window.none;
mid_REFOCUS.transmit_apodization.MLA = MLA;
mid_REFOCUS.receive_apodization.window=uff.window.none;
mid_REFOCUS.receive_apodization.f_number = 1.7;
b_data_delayed_REFOCUS = mid_REFOCUS.go()

%%
cc = postprocess.coherent_compounding()
cc.input = b_data_delayed_REFOCUS;
b_data_REFOCUS = cc.go();
b_data_REFOCUS.plot()


%% Compare the images
% Notice that the REFoCUS image has the most uniform ampltiude a
b_data_compare = uff.beamformed_data(b_data_REFOCUS);
b_data_compare.data(:,1) = b_data_scan_line.data./max(b_data_scan_line.data(:)); 
b_data_compare.data(:,2) = b_data_RTB_uncompensated.data./max(b_data_RTB_uncompensated.data);
b_data_compare.data(:,3) = b_data_RTB.data./max(b_data_RTB.data);
b_data_compare.data(:,4) = b_data_REFOCUS.data./max(b_data_REFOCUS.data);
b_data_compare.plot([],['1 = FI, 2 = REFOCUS'],60)


%% Investigate Coherence
%
% First we can estimate the VZC van Cittert–Zernike curves, SLSL curves ,or coherence
% curves, whatever you want to call them :)

calculate_VZC_curves(b_data_delayed_scan_line,b_data_delayed_RTB,b_data_delayed_REFOCUS,scan_MLA)

%% Coherence Factor
% Second, let us calculate the coherence factor of the different beamformed data
CF = postprocess.coherence_factor()
CF.input = b_data_delayed_scan_line;
b_data_CF = CF.go()
CF_scan_line = uff.beamformed_data(CF.CF);

CF.input = b_data_delayed_RTB;
b_data_CF = CF.go()
CF_RTB = uff.beamformed_data(CF.CF);

CF.input = b_data_delayed_REFOCUS;
b_data_CF = CF.go()
CF_REFOCUS = uff.beamformed_data(CF.CF);

CF_compare = uff.beamformed_data(CF_REFOCUS)
CF_compare.data(:,1) = CF_scan_line.data;
CF_compare.data(:,2) = CF_RTB.data;
CF_compare.data(:,3) = CF_REFOCUS.data;
CF_compare.plot([],['1 = Scan Line, 2 = RTB, 3 = REFoCUS'],[],['none'])
colormap default
caxis([0 1])

%% Investigate a single transmit 
% To further understand the refocus algorithm, we can compare a
% reconstruction from a single transmit. Notice how well defined the single
% transmit becomes from REFoCUS compared to conventional RTB beamforming.
% To illustrate the point, here we have not applied the RTB weighting of the 
% image that would remove most of the noise "outside" of the transmit.

channel_data_single_tx = uff.read_object([local_path, filename],'/channel_data');
channel_data_single_tx.N_frames = 1;
channel_data_single_tx.sequence = channel_data.sequence(58);
channel_data_single_tx.data = channel_data.data(:,:,58);

% Covenventional RTB beamforming
mid_RTB.channel_data = channel_data_single_tx;
mid_RTB.transmit_apodization.window = uff.window.none;
mid_RTB.dimension = dimension.both();
b_data_RTB_single_tx = mid_RTB.go()
b_data_RTB_single_tx.plot()

% Refocus the channel data from a single tx
refocus = preprocess.refocus()
refocus.input = channel_data_single_tx;
channel_data_STAI_single_tx = refocus.go()

% Beamform with refocused channeldata
mid_REFOCUS.channel_data = channel_data_STAI_single_tx;
mid_REFOCUS.dimension = dimension.both();
b_data_REFOCUS_single_tx = mid_REFOCUS.go()
b_data_REFOCUS_single_tx.plot()

%% Compare RTB and REFoCUS on single tx
single_tx_compare = uff.beamformed_data(b_data_REFOCUS_single_tx)
single_tx_compare.data(:,:,1,1) = b_data_REFOCUS_single_tx.data./max(b_data_REFOCUS_single_tx.data(:));
single_tx_compare.data(:,:,1,2) = b_data_RTB_single_tx.data./max(b_data_RTB_single_tx.data(:));
single_tx_compare.plot([],['1 = RTB, 2 = REFoCUS'])
