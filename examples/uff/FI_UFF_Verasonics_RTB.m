%% Reading FI data from an UFF file recorded from a Verasonics Scanner
%
% In this example we show how to read channel data from a
% UFF (Ultrasound File Format) file recorded with a Verasonics scanner.
% You will need an internet connection to download data.
%
% _by Ole Marius Hoel Rindal <olemarius@olemarius.net>
%   and Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>
%
%   $Last updated: 2017/10/06$

%% Checking the file is in the path
%
% To read data from a UFF file the first we need is, you guessed it, a UFF
% file. We check if it is on the current path and download it from the USTB
% websever.

clear all; close all;

% data location
url='http://ustb.no/datasets/';      % if not found downloaded from here
filename='L7_FI_IUS2018.uff';

% checks if the data is in your data path, and downloads it otherwise.
% The defaults data path is under USTB's folder, but you can change this
% by setting an environment variable with setenv(DATA_PATH,'the_path_you_want_to_use');
tools.download(filename, url, data_path);   

%% Reading data
%
% Let's first check if we are lucky and the file allready contains
% beamformed_data that we can display.
display=true;
content = uff.index([data_path filesep filename],'/',display);


%% Channel data
% If it doesn't have any beamformed data at least it should have some
% channel_data. So let's read that.

channel_data=uff.read_object([data_path filesep filename],'/channel_data');

%%  
%
% And then do the normal routine of defining the scan,
x_axis=zeros(channel_data.N_waves,1);
for n=1:channel_data.N_waves
    x_axis(n)=channel_data.sequence(n).source.x;
end
z_axis=linspace(1e-3,62e-3,512*2).';
scan=uff.linear_scan('x_axis',x_axis,'z_axis',z_axis);

%%
%
% setting up and running the pipeline
mid=midprocess.das();
mid.dimension = dimension.both();

mid.channel_data=channel_data;
mid.scan=scan;

mid.transmit_apodization.window=uff.window.scanline;

mid.receive_apodization.window=uff.window.none;
mid.receive_apodization.f_number=1.7;

b_data=mid.go();

%% Display image
%
% And finally display the image.
b_data.plot([],'Beamformed image');


%% Retrospective beamforming
MLA = 4;

scan_RTB = uff.linear_scan('x_axis',linspace(x_axis(1),x_axis(end),length(x_axis)*MLA)','z_axis',z_axis);

mid_RTB=midprocess.das();
mid_RTB.dimension = dimension.both();

mid_RTB.channel_data=channel_data;
mid_RTB.scan=scan_RTB;
% We are using the hybrid transmit delay model. See the reference below:
% Rindal, O. M. H., Rodriguez-Molares, A., & Austeng, A. (2018). A simple , artifact-free , virtual source model. 
% IEEE International Ultrasonics Symposium, IUS, 1–4. 
mid_RTB.spherical_transmit_delay_model = spherical_transmit_delay_model.hybrid;
mid_RTB.transmit_apodization.window=uff.window.tukey25;
mid_RTB.transmit_apodization.f_number = 2;
mid_RTB.transmit_apodization.MLA = MLA;
mid_RTB.transmit_apodization.MLA_overlap = MLA;
mid_RTB.transmit_apodization.minimum_aperture = [3.0000e-03 3.0000e-03];

mid_RTB.receive_apodization.window=uff.window.boxcar;
mid_RTB.receive_apodization.f_number=1.7;
b_data_RTB=mid_RTB.go();

b_data_RTB.plot(767,'RTB image using virtual source model');


%%
tx_apod = mid_RTB.transmit_apodization.data;

%%
weighting = 1./sum(tx_apod,2);

b_data_RTB_compensated = uff.beamformed_data(b_data_RTB);
b_data_RTB_compensated.data = b_data_RTB.data .* weighting;
b_data_RTB_compensated.plot([],'RTB image using virtual source model TX weighted');