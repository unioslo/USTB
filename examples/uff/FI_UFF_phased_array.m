%% Example script demonstrating phased array focused imaging (FI) with a
% dataset recorded from the Verasonics Vantage 256 with a P4-2v probe.
%
% The dataset was used in the publication;
% Rindal, O. M. H., Aakhus, S., Holm, S., &  
%		 Austeng, A. (2017). Hypothesis of Improved  
%		 Visualization of Microstructures in the  
%		 Interventricular Septum with Ultrasound and  
%		 Adaptive Beamforming. Ultrasound in Medicine and  
%		 Biology, 43(10), 2494?2499.  
%		 https://doi.org/10.1016/j.ultrasmedbio.2017.05.023 
%
% If you want to use this dataset you have to reference the article.
%



% Clear up
clear all;close all;

% Read the data, poentitally download it
url='http://ustb.no/datasets/';      % if not found downloaded from here
local_path = [ustb_path(),'/data/']; % location of example data
addpath(local_path);

% Choose dataset
filename='Verasonics_P2-4_parasternal_long_small.uff';
% check if the file is available in the local path or downloads otherwise
tools.download(filename, url, local_path);
channel_data = uff.read_object([local_path, filename],'/channel_data');

%%
% Print info about the dataset. Remeber that if you want to use this dataset
% you have to reference this article!
channel_data.print_authorship

%% Do beamforming
depth_axis=linspace(0e-3,110e-3,512).';
azimuth_axis=zeros(channel_data.N_waves,1);
for n=1:channel_data.N_waves
    azimuth_axis(n) = channel_data.sequence(n).source.azimuth;
end

scan=uff.sector_scan('azimuth_axis',azimuth_axis,'depth_axis',depth_axis);

mid=midprocess.das();
mid.channel_data=channel_data;
mid.dimension = dimension.both();
mid.scan=scan;
mid.transmit_apodization.window=uff.window.scanline;
mid.receive_apodization.window=uff.window.tukey25;
mid.receive_apodization.f_number = 1.7;

b_data = mid.go();

%% Plot image
b_data.plot(3,['DAS']);


%% Beamform the image with 4 MLA's per scan line with two overlapping
MLA = 4;
scan_MLA=uff.sector_scan('azimuth_axis',...
    linspace(channel_data.sequence(1).source.azimuth,channel_data.sequence(end).source.azimuth,...
    length(channel_data.sequence)*MLA)','depth_axis',depth_axis);

mid_MLA=midprocess.das();
mid_MLA.channel_data=channel_data;
mid_MLA.dimension = dimension.both();
mid_MLA.scan=scan_MLA;
mid_MLA.transmit_apodization.window=uff.window.scanline;
mid_MLA.transmit_apodization.MLA = MLA;
mid_MLA.transmit_apodization.MLA_overlap = MLA/2;
mid_MLA.receive_apodization.window=uff.window.tukey25;
mid_MLA.receive_apodization.f_number = 1.7;

b_data_MLA = mid_MLA.go();
%% Plot the image 
b_data_MLA.plot(4,['DAS with MLAs']);