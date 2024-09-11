clear all; close all;

%% Read Channel data
% data location
url='http://ustb.no/datasets/';      % if not found downloaded from here
filename = 'FieldII_STAI_uniform_fov.uff';

% checks if the data is in your data path, and downloads it otherwise.
% The defaults data path is under USTB's folder, but you can change this
% by setting an environment variable with setenv(DATA_PATH,'the_path_you_want_to_use');
tools.download(filename, url, data_path);   

channel_data = uff.channel_data();
channel_data.read([data_path filesep filename],'/channel_data_speckle');

%% Demodulation
demod = preprocess.fast_demodulation();
demod.plot_on = true;
demod.input = channel_data;
channel_data_demod = demod.go();

%% Estimate power spectrums
[fx, F] = tools.power_spectrum(channel_data.data,channel_data.sampling_frequency);
[fx_demod, F_demod] = tools.power_spectrum(channel_data_demod.data,channel_data_demod.sampling_frequency);

%% Display the different power spectrums
figure(1);
subplot(211)
plot(fx*10^-6,db(F));
xlim([-10 10]);ylim([-100 0])
xlabel('Frequency [MHz]');ylabel('Amplitude [dB]');
title('Power spectrum from full RF-data');
subplot(212)
plot(fx_demod*10^-6,db(F_demod));
xlim([-10 10]);ylim([-100 0])
xlabel('Frequency [MHz]');ylabel('Amplitude [dB]');
title('Power spectrum from demodulated IQ-data');

%% Define the scan
sca=uff.linear_scan('x_axis',linspace(channel_data.probe.x(1),channel_data.probe.x(end),512).','z_axis',linspace(2.5e-3,55e-3,512).');

%% Do DAS beamforming
mid = midprocess.das();
mid.scan = sca;
mid.channel_data = channel_data_demod;
mid.dimension = dimension.both();
mid.receive_apodization.window=uff.window.boxcar;
mid.receive_apodization.f_number=1.75;
mid.transmit_apodization.window=uff.window.boxcar;
mid.transmit_apodization.f_number=1.75;
b_data_demod = mid.go(); % From demod data
mid.channel_data = channel_data;
b_data = mid.go(); % From RF data

%% Display both images
figure(2)
b_data_demod.plot(subplot(1,2,1),'Recon. from full RF-data')
b_data.plot(subplot(1,2,2),'Recon. from demodulated IQ-data')

