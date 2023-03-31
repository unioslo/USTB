%% Demonstrating process objects in UFF
% This example demonstrates how to use some of the different process
% objects in the USTB. The main goal is to illustrate how to use the
% process objects as building blocks that can be quite flexible.
%
% Lastly we illustrate how we can group multiple processing objects
% into a processing pipeline.
%
% Author: Ole Marius Hoel Rindal <olemarius@olemarius.net>
% Date: 14.06.2021

% Download and read dataset
url='http://ustb.no/datasets/';                  
local_path = [ustb_path(),'/data/']; 
filename='Verasonics_P2-4_parasternal_long_small.uff';
tools.download(filename, url, local_path);

%% Read UFF channel data object
channel_data = uff.read_object([local_path, filename],'/channel_data');

%% Define the UFF scan
depth_axis=linspace(0e-3,110e-3,1024).';                
azimuth_axis=linspace(channel_data.sequence(1).source.azimuth,...
    channel_data.sequence(end).source.azimuth,channel_data.N_waves)';
scan=uff.sector_scan('azimuth_axis',azimuth_axis,'depth_axis',depth_axis);

%% Preprocess : Demodulation
demod = preprocess.fast_demodulation()
demod.modulation_frequency = channel_data.pulse.center_frequency;
demod.input = channel_data;
channel_data_demod = demod.go()

%% Midprocess : DAS
mid=midprocess.das();                                
mid.channel_data=channel_data_demod;
mid.dimension = dimension.transmit();
mid.scan=scan;
mid.transmit_apodization.window=uff.window.scanline;
mid.receive_apodization.window=uff.window.none;
b_data = mid.go();                      

%% Postprocess #1 : Coherence Factor
cf = postprocess.coherence_factor();
cf.input = b_data;
b_data_cf = cf.go()

%% Postprocess #2 : Median image filtering
me = postprocess.median();
me.m = 5; me.n = 5;
me.input = b_data_cf;
b_data_me = me.go()

b_data_me.plot([],['Human Heart'],[80],[],[],[],[],'dark');      % Display

%% There must be a more efficient way?! 
% Yes there is, it's called a processing pipeline. With the pipeline we can
% group the call to the processing objects together and the pipeline
% handles the forwarding of data between and soem paramteres between the
% processing objects.

pipe=pipeline();
pipe.channel_data=channel_data;
pipe.scan=scan;
pipe.transmit_apodization.window=uff.window.scanline;
pipe.receive_apodization.window=uff.window.none;

% Define midprocess DAS outside pipeline to set dimension
das = midprocess.das()
das.dimension = dimension.transmit()

% Run pipeline
b_data_cf_pipe = pipe.go({demod das postprocess.coherence_factor() me});

b_data_cf_pipe.plot([],['Human Heart'],[80],[],[],[],[],'dark'); % Display
