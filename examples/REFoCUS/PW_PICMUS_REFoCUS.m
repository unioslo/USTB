%% REFOCUS on PW data
% The very fasinating REFoCUS algorithm published in
% 
% Bottenus, N. (2018). Recovery of the Complete Data Set from Focused Transmit 
%   Beams. IEEE Transactions on Ultrasonics, Ferroelectrics, and Frequency Control, 
%   65(1), 30–38. https://doi.org/10.1109/TUFFC.2017.2773495
% 
% further develop in 
% 
% Ali, R., Herickhoff, C. D., Hyun, D., Dahl, J. J., & Bottenus, N. (2020). 
%  Extending Retrospective Encoding for Robust Recovery of the Multistatic 
%  Data Set. IEEE Transactions on Ultrasonics, Ferroelectrics, and Frequency Control,
%  67(5), 943–956. https://doi.org/10.1109/TUFFC.2019.2961875
% 
% Is quite fasinating! Here we explore the concept by comparing
% conventional PW beamforming using the generalized beamformer in the USTB,
% and use REFoCUS to refocus the PW channel data into a STAI channel data.
%
%   authors:  Anders E. Vrålstad <anders.e.vralstad@ntnu.no>
%             Ole Marius Hoel Rindal <omrindal@ifi.uio.no>
%   $Last updated: 2024/11/09$

clear all;
close all;

%% Load the channel data
% data location
url='http://ustb.no/datasets/';      % if not found data will be downloaded from here
filename='PICMUS_experiment_contrast_speckle.uff'
tools.download(filename, url, data_path);  
% checks if the data is in your data path, and downloads it otherwise.
% The defaults data path is under USTB's folder, but you can change this
% by setting an environment variable with setenv(DATA_PATH,'the_path_you_want_to_use');
local_path = [ustb_path(),'/data/']; 
channel_data = uff.read_object([local_path, filename],'/channel_data');

% Create a quite large scan (outside the conventional PW area) to help the
% visualziation on the differece between conventional PW and REFoCUS.
scan = uff.linear_scan();
scan.x_axis = linspace(-30/1000,30/1000,512)';
scan.z_axis = linspace(3/1000,60/1000,512)';

%% Conventional Beamforming using the generalized beamformer
das = midprocess.das();
das.channel_data=channel_data;
das.scan=scan;
das.dimension = dimension.both()
das.receive_apodization.window=uff.window.boxcar;
das.receive_apodization.f_number=1.7;
das.transmit_apodization.window=uff.window.boxcar;
das.transmit_apodization.f_number=1.7;
b_data=das.go();

%% Run REFOCUS preprocess to create multistatic/STAI channel data
refocus = preprocess.refocus();
refocus.input = channel_data;
refocus.use_filter = 0;
refocus.regularization = @Hinv_tikhonov;
refocus.decode_parameter = 1e-1;
refocus.post_pad_samples = 0;
channel_data_REFOCUS = refocus.go();

%% Do beamforming with REFoCUSed channel data
das.channel_data = channel_data_REFOCUS;
b_data_REFOCUS = das.go();

%% Comparing results
figure;
b_data.plot(subplot(1,2,1),'RTB');
b_data_REFOCUS.plot(subplot(1,2,2),'REFoCUS');
set(gcf,'Position',[100   100   750   450])

b_data_compare = uff.beamformed_data(b_data)
b_data_compare.data(:,:,1,1) = b_data.data./max(b_data.data(:));
b_data_compare.data(:,:,1,2) = b_data_REFOCUS.data./max(b_data_REFOCUS.data(:));
b_data_compare.plot()

%% Comparing conventional PW and REFOCUS on a single PW transmit
transmit_index = 37 %Choose from 1 to 75
channel_data_single_tx = uff.channel_data(channel_data);
channel_data_single_tx.sequence = channel_data.sequence(transmit_index);
channel_data_single_tx.data = channel_data.data(:,:,transmit_index);

das.channel_data = channel_data_single_tx;
b_data_conv_single_tx = das.go();
b_data_conv_single_tx.plot([],'Conventional PW beamforming')

refocus.input = channel_data_single_tx;
channel_data_REFOCUS_single_tx = refocus.go();

%% Refocus
das.channel_data = channel_data_REFOCUS_single_tx;
b_data_REFOCUS_single_tx = das.go();
b_data_REFOCUS_single_tx.plot([],'REFoCUS beamforming')

%% Compare the results
b_data_compare = uff.beamformed_data(b_data)
b_data_compare.data(:,:,1,1) = b_data_conv_single_tx.data./max(b_data_conv_single_tx.data(:));
b_data_compare.data(:,:,1,2) = b_data_REFOCUS_single_tx.data./max(b_data_REFOCUS_single_tx.data(:));
b_data_compare.plot()

%% A nice way to further understand what REFoCUS does is to visualize each
% transmit event separately. Then conventional PW will be each PW transmit
% image, while from the REFoCUS channel data each element is now the
% transmitter. Quite fasinating!
das.channel_data=channel_data;
das.scan=scan;
das.transmit_apodization.window = uff.window.none;
das.dimension = dimension.receive();
b_data_conv_tx = das.go();
b_data_conv_tx.frame_rate = 10;
b_data_conv_tx.plot([],'Conventional PW beamforming')

das.channel_data = channel_data_REFOCUS;
b_data_refocus_tx = das.go();
b_data_refocus_tx.frame_rate = 10;
b_data_refocus_tx.plot([],'REFoCUS beamforming')

