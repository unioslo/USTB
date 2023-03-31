% Sonar imaging : Exercise for Module 4
%
%   See the sonar_exercise.pdf in the current folder for the exercise text.
%
% Author: Ole Marius Hoel Rindal <21.09.2021> adapted from code and data
%         from Roy Edgar Hansen and Fabrice Prieur

clear all;
close all;

%% Read the data channel data
channel_data = uff.channel_data();
channel_data.read('./sonar_ping.uff','/channel_data');
channel_data.plot()

%% Read a beamformed image of the raw uncompressed signal
% This is an example of how the image beamformed fomr the raw uncompressed
% signal might look like in part c) of the exercise
b_data_raw= uff.beamformed_data();
b_data_raw.read('./sonar_ping.uff','/b_data_raw');
b_data_raw.plot([],['SONAR uncompressed'],[],[],[],[],'m','dark')
colormap default
caxis([-65 -10])

%% Parameters for the transmit signal a Linear Frequency Modulated (LFM) upchirp pulse
bw = 30000;     % Bandwidth in Hertz
t_p = 0.0080;   % Pulse Length in seconds


%% Define the theoretical transmit pulse, a Linear Frequency Modulated (LFM) pulse


%% Create a copy of the channel data object to hold the pulse compressed data
channel_data_compressed = uff.channel_data(channel_data);
% Change the initial time to half of the pulse length to "center" the compressed data
channel_data_compressed.initial_time = t_p/2;

%% Do Pulse Compression
% Create an empty buffer to hold the resulting data 
% notice that we make it twice as long as the original signal? Why and how
% should you handle this??
match_filtered_data = zeros(2*channel_data.N_samples-1,channel_data.N_elements);

% replace the copied data in the uff.channel_data object with the
% pulse compressed data
% NB! Look at the hints in the exercise text regarding which part of the
% data you should write back to the channel_data_compressed.data... ;)
channel_data_compressed.data = match_filtered_data;

%% Plot and compare channel data compressed and not compressed
% You need to write this code to make plots simiar to the ones shown in the
% exercise text.

%% Define a sector scan based on the theoretical angular resolution calculated in a)

%% Set up the DAS beamformer in USTB
% Look back at previous examples and the previous exercise on how to set up
% beamforming with the USTB. Make sure that you for this setups use "no"
% apodization for the transmit wave apodization and the receive
% apodization. Thus, you should use the "uff.window.none" for both.
%
% Also make sure that you create the image for both the raw uncompressed
% channel data and the channel data where you have ran pulse compression

%% To have a nice interactive way of comparing the images you can use the
% following code given that your resulting beamformed data objects are
% called b_data and b_data_compressed. This code also shows how it can be
% suitable do display the images with a default colormap and suitable caxis
b_data_compare = uff.beamformed_data(b_data);
b_data_compare.data(:,1) = b_data.data./mean(b_data.data(:));
b_data_compare.data(:,2) = b_data_compressed.data./mean(b_data_compressed.data(:));
b_data_compare.plot([],['SONAR 1 = raw, 2 = compressed'],[],[],[],[],'m','dark')
caxis([-65 -10])
colormap default