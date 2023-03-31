clear all; close all;

%% Read Channel data
% data location
url='http://ustb.no/datasets/';      % if not found downloaded from here

filename = ['experimental_STAI_dynamic_range.uff'];

% checks if the data is in your data path, and downloads it otherwise.
% The defaults data path is under USTB's folder, but you can change this
% by setting an environment variable with setenv(DATA_PATH,'the_path_you_want_to_use');
tools.download(filename, url, data_path);   

channel_data = uff.channel_data();
channel_data.read([data_path filesep filename],'/channel_data');

%% Demodulation
demod = preprocess.demodulation();
demod.input = channel_data;
demod.modulation_frequency = channel_data.pulse.center_frequency;
channel_data_demod = demod.go();

%% Estimate power spectrums
[fx, F] = tools.power_spectrum(channel_data.data,channel_data.sampling_frequency);
[fx_demod, F_demod] = tools.power_spectrum(channel_data_demod.data,channel_data_demod.sampling_frequency);


%% Simple demodulation
data_demod_simple = channel_data.data.*exp(1i*2*pi*-channel_data.pulse.center_frequency*channel_data.time);
t_in = (0:size(channel_data.data,1)-1)'./channel_data.sampling_frequency;
demodVec = exp(1i.*2.*pi.*-channel_data.pulse.center_frequency.*t_in);
data_demod_simple = channel_data.data.*demodVec;
[fx_demod_simple, F_demod_simple] = tools.power_spectrum(data_demod_simple,channel_data.sampling_frequency);


%% Display the different power spectrums
figure(1);
subplot(311)
plot(fx*10^-6,db(F),'LineWidth',2);
xlim([-10 10]);ylim([-100 0])
xlabel('Frequency [MHz]');ylabel('Amplitude [dB]');
title('Power spectrum from full RF-data');
set(gca,'FontSize',14)
subplot(312)
plot(fx_demod_simple*10^-6,db(F_demod_simple),'LineWidth',2);
xlim([-10 10]);ylim([-100 0])
xlabel('Frequency [MHz]');ylabel('Amplitude [dB]');
title('Power spectrum from downmixed RF-data');
set(gca,'FontSize',14)
subplot(313)
plot(fx_demod*10^-6,db(F_demod),'LineWidth',2);
xlim([-10 10]);ylim([-100 0])
xlabel('Frequency [MHz]');ylabel('Amplitude [dB]');
title('Power spectrum from demodulated IQ-data');
set(gca,'FontSize',14)
%% Define the scan
sca=uff.linear_scan('x_axis',linspace(channel_data.probe.x(1),channel_data.probe.x(end),512).','z_axis',linspace(2.5e-3,55e-3,512).');

%% Do DAS beamforming
mid = midprocess.das();
mid.scan = sca;
mid.channel_data = channel_data_demod;
mid.dimension = dimension.both();
mid.receive_apodization.window=uff.window.boxcar;
mid.receive_apodization.f_number=1.75;
mid.transmit_apodization.window=uff.window.none;
mid.transmit_apodization.f_number=1.75;
b_data_no_tx = mid.go(); % From demod data

%%
b_data_apod = uff.beamformed_data(b_data)
b_data_apod.data = mid.transmit_apodization.data;
b_data_apod.plot([],['Transmit Wave Apodization STAI'],[],'none')
colormap default

%%
b_data_apod.save_as_gif('examples/UiO_course_IN4015_Ultrasound_Imaging/module_3_US_processing_chain/Figures/apod_expanding_linear.gif');
%% Display both images
figure(2)
b_data_no_tx.plot(subplot(1,2,1),'Recon. from full RF-data')

%%
compare = uff.beamformed_data(b_data_no_tx)
compare.data(:,2) = b_data.data(:);
compare.plot([],['1 = no tx apod, 2 = tx apod'])

%%
compare.save_as_gif('examples/UiO_course_IN4015_Ultrasound_Imaging/module_3_US_processing_chain/Figures/STAI_tx_apod.gif');
%%

signal = channel_data.data(:,end/2);
signal_hilbert = conv(signal,1./(pi*channel_data.time));
signal_hilbert = signal_hilbert(1:length(signal));

figure(111);clf;hold all;
plot(signal./max(signal));
plot(signal_hilbert./max(signal_hilbert),'r-');
plot(abs(signal./max(signal)+signal_hilbert./max(signal_hilbert)))
