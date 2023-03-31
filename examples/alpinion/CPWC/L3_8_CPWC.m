%% Read CPWC dataset from the Alpinion Research scanner
%
%   This examples shows how to load CPWC data recorded on the Alpinion
%   Research scanner into with L3-8_OMHR_CPWC.py example sequence the into a 
%   channel_data object and beamform it with the USTB routines. The data 
%   should be in the path /data/Alpinion/FI_linear/ from the root folder of
%   the USTB. The data can be downloaded from: 
%   https://www.dropbox.com/sh/wv7sa88dvhfszcl/AABYgOJixkKvQM_Q3jJlvFVWa?dl=0

%   date : 11.07.2017
%   author: Ole Marius Hoel Rindal (olemarius@olemarius.net)

clear all
close all

% Set up filepath to files with parameters and data from the Alpinion scanner

local_path = fullfile(ustb_path(), 'data'); % location of example data in this computer

data_folder  = fullfile(local_path, 'Alpinion', 'CPWC', 'CPWC_hypoechoic');

%% initiate Alpinion object pointing to files with data
alp = alpinion();
alp.data_folder = data_folder;

%% Create channel_data object
number_of_planewaves = 21;
number_of_frames = 4;
channel_data = alp.read_CPWC(number_of_planewaves,number_of_frames);

%% SCAN
sca=uff.linear_scan();
sca.x_axis = linspace(channel_data.probe.x(1),channel_data.probe.x(end),512).'
sca.z_axis = linspace(1e-3,55e-3,512).'
 
%% BEAMFORMER pipeline

pipe=pipeline();
pipe.channel_data=channel_data;
pipe.scan=sca;

pipe.receive_apodization.window=uff.window.boxcar;
pipe.receive_apodization.f_number=1.7;
pipe.transmit_apodization.window=uff.window.boxcar;
pipe.transmit_apodization.f_number=1.7;

b_data = pipe.go({midprocess.das() postprocess.coherent_compounding()});

%% Display image
b_data.plot(1,['CPWC : ',num2str(size(channel_data.data,3)), ' angles'],50);

%%
answer = questdlg('Do you want to save this dataset?');
if strcmp(answer,'Yes')
    if strfind(tag, 'scatterers')
        channel_data.name = {'CPWC dataset of hyperechoic cyst and points scatterers recorded on an Alpinion scanner with a L3-8 Probe from a CIRS General Purpose Ultrasound Phantom'};
    else
        channel_data.name = {'CPWC dataset of hypoechic cyst recorded on an Alpinion scanner with a L3-8 Probe from a CIRC General Purpose Ultrasound Phantom'};
    end
    channel_data.author = {'Ole Marius Hoel Rindal <olemarius@olemarius.net>','Muyinatu Lediju Bell <mledijubell@jhu.edu>'};
    channel_data.reference = {'www.ultrasoundtoolbox.com'};
    channel_data.version = {'1.0.1'};
    
    uff_filename = ['./Alpinion_L3-8_',tag,'.uff']
    channel_data.write(uff_filename,'channel_data');
end