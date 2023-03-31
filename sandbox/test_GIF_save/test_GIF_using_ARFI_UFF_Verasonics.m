%% Acoustic Radiation Force Imaging from UFF file recorded with the Verasonics ARFI_L7 example
%
% This is a modified version of the ARFI_UFF_Verasonics example found under
% /examples/acoustical_radiation_force_imaging/ARFI_UFF_Verasonics. It is
% simplified to just test the GIF writing function. 
%
% In this example we demonstrate the speckle tracking of displacement created
% by a shear wave induced with an acoustic "push" pulse. Also known as
% acoustic radiation force imaging, or share wave elastography. You will 
% need an internet connection to download the data. Otherwise, you can run 
% the *ARFI_L7.m* Verasonics example and create your own .uff file.
%
% _Ole Marius Hoel Rindal <olemarius@olemarius.net> 15.08.2017 updated 02.02.2021

%% Reading the channel data from the UFF file
clear all; close all;

% data location
url='http://ustb.no/datasets/';            % if not found data will be downloaded from here
local_path = [data_path(), filesep];  % location of example data on this computer

filename='ARFI_dataset.uff';

% check if the file is available in the local path & downloads otherwise
tools.download(filename, url, local_path);

%%
% Reading channel data from the UFF file
% and print out information about the dataset.

channel_data = uff.read_object([local_path filename],'/channel_data');
channel_data.print_authorship

% Only use 50 frames
channel_data.N_frames = 50;
%% Beamform images 
% First, we need to beamform the images from the channel data. We'll do the
% usual drill of defining the scan and the beamformer object.

% SCAN
sca=uff.linear_scan();
sca.x_axis = linspace(channel_data.probe.x(1),channel_data.probe.x(end),256).';
sca.z_axis = linspace(0,30e-3,768).';
 
% Define processing pipeline
pipe=pipeline();
pipe.channel_data=channel_data;
pipe.scan=sca;

pipe.receive_apodization.window=uff.window.tukey50;
pipe.receive_apodization.f_number=1.7;

pipe.transmit_apodization.window=uff.window.tukey50;
pipe.transmit_apodization.f_number=1.7;

%% We can do it all in once!!
% Since the *autocorrelation_displacement_estimation* is a process, we can trust
% the default paramters (which are the same as the ones used above) and do
% the beamforming and the displacement estimation all in one call!
%
% And the pipe will check if some of the calculations allready have been
% done and skip them.
%
% Isn't the USTB great?!

disp = postprocess.autocorrelation_displacement_estimation();
disp.channel_data = channel_data;

disp_img = pipe.go({midprocess.das postprocess.coherent_compounding ...
                                disp});
%%
% Display the displacement 
% Which gives us the same result as above.
f5 = figure(5);clf;
disp_img.plot(f5,['Displacement'],[],'none',[],[],[],'dark');
caxis([-0.1*10^-6 0.2*10^-6]); % Updating the colorbar
colormap(gca(f5),'hot');       % Changing the colormap
% Save to GIF file
disp_img.save_as_gif('Displacement.gif')