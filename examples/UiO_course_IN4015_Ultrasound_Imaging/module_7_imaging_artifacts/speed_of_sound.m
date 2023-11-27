%% Reconstruct a single PW transmission in a phantom using different sound speeds
% This exercise is to explore the effects of using the wrong sound speed
% in the reconstruction. As we learned in the lecture, the sound speed in
% the body varies quite a lot, from e.g. 1460 in fat to 1600 in muscles. In this
% exercise we will experiment with the sound speed in the reconstruction of
% a single PW image and see how this affects the reconstructed image. 
clear all;
close all;

%% Download and read channel_data
url='http://ustb.no/datasets/'; 
filename='L7_CPWC_TheGB.uff'; selected_tx(1) = 20; tag{1} = 'FI'; tag_title{1} = 'Focused';
tools.download(filename, url, data_path);
channel_data=uff.read_object([data_path filesep filename],'/channel_data');
channel_data.N_frames = 1; %Only reconstruct one frame
% Only keeping channel data at angle = 0
channel_data.sequence =  channel_data.sequence(6);
channel_data.data = channel_data.data(:,:,6);

%% Part I 
% Try to beamform the image with at least three different sound speeds
% including 1460 m/s (fat), 1540 m/s (typical mean) and 1600 m/s (muscle). 
% How does this affect the final image? How does it affect the resolution of the
% point scatter? How does it affect the size of the cyst? Notice that the point scatter
% "moves" with different sound speeds so you have to change what line to plot in the figure 
% further down in the code.
channel_data.sound_speed = 1460;  %<------------- Update this value in Part I
for seq = 1:channel_data.N_waves
    channel_data.sequence(seq).sound_speed = channel_data.sound_speed;
end

% Part II: 
% As you have probably experienced now, when you reconstruct an image with
% different sound speed, the objects in the image move and change sizes. To
% evaluate the lowest point scatter you had to manually change what depth
% index to investigate. However, to be able to use for example machine
% learning to evaluate sound speed we need the reconstructed objects to be
% at the same pixel in images with different reconstructed sound speeds so 
% that one can compare two images with different sound speeds "pixel by
% pixel". How can you set the z_axis of the reconstructed scan so that it
% scales with the sound speed? 
% Hint: Perhaps you can use the wavelength as a unit? It is found at
% channel_data.lambda or you can calculate it on your own.
% Explain why this works.

scan=uff.linear_scan();
scan.x_axis = linspace(channel_data.probe.x(1),channel_data.probe.x(end),512).';
scan.z_axis = linspace(3e-3,50e-3,512).'; %<------------- Update this in Part II

mid=midprocess.das();
mid.dimension = dimension.both;
mid.channel_data=channel_data;
mid.scan=scan;
mid.transmit_apodization.window=uff.window.none;
mid.receive_apodization.window=uff.window.tukey50;
b_data_das=mid.go();

img = b_data_das.get_image();

% Create plot to analyse results for part I and II
figure();
imagesc(img)
title('Use this image to find the correct depth index to investigate the lowest point scatter');

depth_idx_of_point_scatter = 359; % 359 is correct for sound_speed = 1460 in Part I
figure;hold all;
plot(scan.x_axis*1000,img(depth_idx_of_point_scatter,:)-max(img(depth_idx_of_point_scatter,:)))
plot([-15.5 -15.5],[-50 0],'r')
plot([-6.5 -6.5],[-50 0],'r')
plot(scan.x_axis*1000,ones(1,scan.N_x_axis)*-6,'r--','LineWidth',2,'DisplayName','- 6dB (FWHM)')
xlabel('x [mm]');ylabel('Amplitude [dB]');

% Create beamformed image with cyst indicated for exercise 1 and 2
b_data_das.plot([],['PW beamformed with sound speed = ',num2str(channel_data.sound_speed)])
viscircles(gca,[-11,scan.z_axis(depth_idx_of_point_scatter)*1000],4,'EdgeColor','b')

%% Exercise 3: 
% Based on the two previous exercises - which sound speed was correct when
% reconstruction this dataset? Perhaps you can suggest a criteria 
% to evaluate the sound speed in the reconstruction?