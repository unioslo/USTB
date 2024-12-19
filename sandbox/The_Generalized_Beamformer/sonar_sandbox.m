% An example to beamform a sonar ping in the USTB.
% Also doing match filtering (copmression) on the data.
%
% Author: Ole Marius Hoel Rindal <21.09.2021>

clear all;
close all;

filename = 'sonar_ping.uff'
channel_data = uff.channel_data()
local_path = [ustb_path(),'/data/']; 
channel_data = uff.read_object([local_path, filename],'/channel_data');


% Create a copy of the channel data object to hold the compressed data
channel_data_compressed = uff.channel_data(channel_data);

%% Define theoretical transmit pulse
bw = 30000;
t_p = 0.0080;
t_transmit = (-t_p/2:1/channel_data.sampling_frequency:t_p/2);
alpha = bw/t_p;
transmit_pulse = exp(1i*2*pi*alpha*t_transmit.^2/2);

%% Do matched filtering
match_filtered_data = zeros(2*channel_data.N_samples-1,channel_data.N_elements);
for e = 1:channel_data.N_elements
    match_filtered_data(:,e) = xcorr(channel_data.data(:,e),transmit_pulse);
end
match_filtered_data = match_filtered_data(channel_data.N_samples:end,:);

channel_data_compressed.data = match_filtered_data;

%% Plot and compare channel data  compressed and not compressed
time_axis = channel_data.time;
figure;
subplot(2,2,1)
plot(channel_data.time,abs(channel_data.data(:,16)))
subplot(2,2,3)
plot(channel_data_compressed.time,abs(channel_data_compressed.data(:,16)))
subplot(2,2,2)
plot(time_axis,abs(channel_data.data(:,16)))
xlim([time_axis(4000) time_axis(4400)]);
subplot(2,2,4)
plot(time_axis,abs(channel_data_compressed.data(:,16)))
xlim([time_axis(4000) time_axis(4400)]);

%% Define a linear scan, but this gives you grating lobes...
azimuth_axis=linspace(-30,30,128)';
depth_axis=[0:0.10:170].';
scan=uff.linear_scan('x_axis',azimuth_axis,'z_axis',depth_axis);

%% Define a sector scan
azimuth_axis = linspace(deg2rad(-22.8/2),deg2rad(22.8/2),128)';
depth_axis = [0:0.20:170].';
scan=uff.sector_scan('azimuth_axis',azimuth_axis,'depth_axis',depth_axis);

mid = midprocess.das;
mid.channel_data=channel_data;
mid.scan=scan;
mid.transmit_apodization.window=uff.window.none;
mid.receive_apodization.window=uff.window.none;
b_data = mid.go();
b_data.plot([],['SONAR uncompressed'],[],[],[],[],'m','dark')
colormap default
caxis([-65 -10])

mid.channel_data = channel_data_compressed;
b_data_compressed = mid.go();
f = figure()
b_data_compressed.plot([f],['SONAR single Tx ping'],[],[],[],[],'m','dark')
colormap default
caxis([-65 -10])
set(gcf,'Position',[680 337 437 541]);
saveas(f,'Figures/sonar_ping.eps','eps2c')
%%
b_data_compare = uff.beamformed_data(b_data);
b_data_compare.data(:,1) = b_data.data./max(b_data.data);
b_data_compare.data(:,2) = b_data_compressed.data./max(b_data_compressed.data);
b_data_compare.plot([],['SONAR 1 = uncompressed, 2 = compressed'],[],[],[],[],'m','dark')
caxis([-65 -10])
colormap default
%%
b_data_compare.save_as_gif('sonar_img.gif');