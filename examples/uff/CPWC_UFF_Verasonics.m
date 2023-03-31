%% Reading data from an UFF file recorded with the Verasonics CPWC_L7 example
%
% In this example we show how to read channel and beamformed data from a
% UFF (Ultrasound File Format) file recorded with the Verasonics example.
% You will need an internet connectionto download data. Otherwise, you can
% run the *CPWC_L7.m* Verasonics example so the file 'L7_CPWC_193328.uff'
% is in the current path.
%
% _by Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no> 
%  and Ole Marius Hoel Rindal <olemarius@olemarius.net>_ 
%
%   $Last updated: 2017/09/15$

%% Checking the file is in the path
%
% To read data from a UFF file the first we need is, you guessed it, a UFF
% file. We check if it is on the current path and download it from the USTB
% websever.

% data location
url='http://ustb.no/datasets/';      % if not found data will be downloaded from here
filename='L7_CPWC_193328.uff';

% checks if the data is in your data path, and downloads it otherwise.
% The defaults data path is under USTB's folder, but you can change this
% by setting an environment variable with setenv(DATA_PATH,'the_path_you_want_to_use');
tools.download(filename, url, data_path);   

%% Checking what's inside
%
% Now that the file is in the machine we can start loading data. The first 
% would be to check what is in there with the *uff.index* function 
uff.index([data_path filesep filename],'/',true);

%%
% Let's read the channel data,
    
channel_data=uff.read_object([data_path filesep filename],'/channel_data');

%%
%
% define a scan
   
scan=uff.linear_scan();
scan.x_axis = linspace(channel_data.probe.x(1),channel_data.probe.x(end),256).';
scan.z_axis = linspace(0,50e-3,256).';
    
%%
%
% and beamform
mid=midprocess.das();
mid.dimension = dimension.both;

mid.channel_data=channel_data;
mid.scan=scan;

mid.transmit_apodization.window=uff.window.none;
mid.transmit_apodization.f_number=1.7;

mid.receive_apodization.window=uff.window.none;
mid.receive_apodization.f_number=1.7;
    
b_data2=mid.go();
b_data2.plot();
