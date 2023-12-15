clear all; 
close all;

load('sonar_ping.mat');

%% Define the probe
probe = uff.linear_array
probe.N = 32;
probe.pitch = d;

%% Define the wave
seq = uff.wave;
s = uff.point();
s.xyz = [0 0 0];
seq.source = s;
seq.delay = 0;

%% Define the pulse
pulse = uff.pulse;
pulse.center_frequency = fc;

%% Define the channel_data
channel_data = uff.channel_data;
channel_data.sound_speed = c;
channel_data.sampling_frequency = fs;
channel_data.modulation_frequency = fc;
channel_data.probe = probe;
channel_data.data = rawdata;
channel_data.initial_time = 0;
channel_data.pulse = pulse;
channel_data.sequence = seq;
channel_data.plot

channel_data.write('./sonar_ping.uff','/channel_data');