%% Illustrate synthetic transmit focusing for Alpinion data
%
% _by Ole Marius Hoel Rindal <olemarius@olemarius.net>_
%
% Last updated 15.05.2018

%% Setting up file path
clear all; close all;

% data location
url = tools.zenodo_dataset_files_base();
local_path = [ustb_path(),'/data/']; % location of example data

% Choose dataset
filename='Alpinion_L3-8_FI_hypoechoic.uff';

% check if the file is available in the local path or downloads otherwise
tools.download(filename, url, local_path);

%% Reading channel data from UFF file
channel_data=uff.read_object([local_path filename],'/channel_data');
channel_data.N_frames = 1;
%%
%Print info about the dataset
channel_data.print_authorship

%% Define Scan

z_axis=linspace(0e-3,60e-3,750).';
x_axis=zeros(channel_data.N_waves,1);
for n=1:channel_data.N_waves
    x_axis(n) = channel_data.sequence(n).source.x;
end

scan=uff.linear_scan('x_axis',x_axis,'z_axis',z_axis);

%% Delay the data with DAS
das = midprocess.das();
das.channel_data=channel_data;
das.dimension = dimension.transmit(); 
das.scan=scan;
das.transmit_apodization.window=uff.window.tukey25;
das.transmit_apodization.f_number=4;
das.receive_apodization.window=uff.window.tukey25;
das.receive_apodization.f_number=3;
b_data_RTB = das.go();

%% Estimate coherence on RTB data
cf = postprocess.coherence_factor()
cf.dimension = dimension.receive;
cf.input = b_data_RTB;
cf_RTB = cf.go();
cf_RTB = cf.CF;

%% Rerun the DAS with scanline transmit apodization
das.transmit_apodization.window=uff.window.scanline;
b_data_scanline = das.go();

% Estimate coherence on scanline delayed data
cf.input = b_data_scanline;
cf_scanline = cf.go();
cf_scanline = cf.CF;

%%
cf_RTB.plot(subplot(121),'CF',[],['none']);
colormap default;
cf_scanline.plot(subplot(122),'CF',[],['none']);
colormap default;

%% b data compare
cf_compare = uff.beamformed_data(cf_RTB);
cf_compare.data(:,1,1,1) = cf_scanline.data;
cf_compare.data(:,1,1,2) = cf_RTB.data;
cf_compare.plot([],'CF',[],['none']);colormap default;
