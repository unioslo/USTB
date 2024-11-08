%% REFOCUS on PW data
%   authors:  Anders E. Vrålstad <anders.e.vralstad@ntnu.no>
%
%   $Last updated: 2024/09/16$

%% Getting the data
%
% We define the local path and the url where the data is stored

% data location
url='http://ustb.no/datasets/';      % if not found data will be downloaded from here
filename='PICMUS_experiment_contrast_speckle.uff';

% checks if the data is in your data path, and downloads it otherwise.
% The defaults data path is under USTB's folder, but you can change this
% by setting an environment variable with setenv(DATA_PATH,'the_path_you_want_to_use');
tools.download(filename, url, data_path);   

scan = uff.linear_scan();
scan.x_axis = linspace(-30/1000,30/1000,1024)';
scan.z_axis = linspace(3/1000,60/1000,1024)';
%% Beamforming
%
% We define a beamformer, and the corresponding transmit and apodization
% windows, and launch it.

pipe=pipeline();
pipe.channel_data=channel_data;
pipe.scan=scan;
    
% receive apodization
pipe.receive_apodization.window=uff.window.tukey50;
pipe.receive_apodization.f_number=1.7;

% transmit apodization
pipe.transmit_apodization.window=uff.window.tukey50;
pipe.transmit_apodization.f_number=1.7;

% launch beamforming
b_data=pipe.go({midprocess.das postprocess.coherent_compounding});

%% Run REFOCUS preprocess

tic
refocus = preprocess.refocus();
refocus.input = channel_data;
refocus.use_filter = 0;
refocus.regularization = @Hinv_tikhonov;
refocus.decode_parameter = 1e-1;
refocus.post_pad_samples = 0;
channel_data_REFOCUS = refocus.go();
toc()

%%
demod = preprocess.fast_demodulation();
demod.plot_on = true;
demod.input = channel_data_REFOCUS;
channel_data_REFOCUS_demod = demod.go();

%% Do beamforming of REFoCUS
mid_REFOCUS = midprocess.das();
mid_REFOCUS.channel_data=channel_data_REFOCUS_demod;
mid_REFOCUS.dimension = dimension.both();
mid_REFOCUS.scan=scan;
mid_REFOCUS.code = code.mex;
mid_REFOCUS.transmit_apodization.window=uff.window.boxcar;
mid_REFOCUS.transmit_apodization.f_number=1.7;
mid_REFOCUS.receive_apodization.window=uff.window.boxcar;
mid_REFOCUS.receive_apodization.f_number=1.7;
b_data_REFOCUS = mid_REFOCUS.go();

%% Comparing results
%
% We plot both images side by side.

figure;
b_data.plot(subplot(1,2,1),'RTB');
b_data_REFOCUS.plot(subplot(1,2,2),'REFoCUS');
set(gcf,'Position',[100   100   750   450])

b_data_compare = uff.beamformed_data(b_data)
b_data_compare.data(:,:,1,1) = b_data.data./max(b_data.data(:));
b_data_compare.data(:,:,1,2) = b_data_REFOCUS.data./max(b_data_REFOCUS.data(:));
b_data_compare.plot()


