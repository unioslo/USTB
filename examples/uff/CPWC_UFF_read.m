%% Reading data from an UFF file
%
% In this example we show how to read channel and beamformed data from a
% UFF (Ultrasound File Format) file. You will need an internet connection
% to download data. Otherwise, you can run the *CPWC_UFF_write.m* first so
% the file 'test01.uff' is in the current path.
%
% _by Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no> 07.08.2017_

%% Checking the file is in the path
%
% To read data from a UFF file the first we need is, you guessed it, a UFF
% file. We check if it is on the current path and download it from the USTB 
% server otherwise.

% data location
url = tools.zenodo_dataset_files_base();
% if not found data will be downloaded from here
filename='PICMUS_simulation_contrast_speckle.uff';

% checks if the data is in your data path, and downloads it otherwise.
% The defaults data path is under USTB's folder, but you can change this
% by setting an environment variable with setenv(DATA_PATH,'the_path_you_want_to_use');
tools.download(filename, url, data_path);   

%% Reading beamformed data
%
% Now that the file is in the machine we can start loading data. The first 
% would be to check what is in there with the *uff.index* function 
uff.index([data_path filesep filename],'/',display);

%%
% 
% We see there is a *beamformed_data* dataset with name _b_data_. Let us
% load it and plot it. There are two ways of reading data from file: 
%
% * we can define an object of the correct class and use the method *read*:

b_data=uff.beamformed_data();
b_data.read([data_path filesep filename],'/beamformed_data');

%%
% 
% * or we can use the function *uff.read_object* and let the function
% create the correct object class for us

b_data2=uff.read_object([data_path filesep filename],'/beamformed_data');

%%
% 
% Either way the result is the correct uff.beamformed_data

figure;
h1=subplot(1,2,1)
b_data.plot(h1,'object.read');
h2=subplot(1,2,2)
b_data2.plot(h2,'uff.read object');

%% Reading channel data
%
% There are also two other structures in the file: a uff.scan and a
% uff.channel_data objects. Let us read them both

%scan=uff.read_object(filename,'/scan');
channel_data=uff.read_object([data_path filesep filename],'/channel_data');

%%
%
% And let us beamform that data with USTB
 
mid=midprocess.das();
mid.dimension = dimension.both;

mid.channel_data=channel_data;
mid.scan=scan;

mid.transmit_apodization.window=uff.window.tukey50;
mid.transmit_apodization.f_number=1.0;

mid.receive_apodization.window=uff.window.tukey50;
mid.receive_apodization.f_number=1.0;

% beamforming
b_data=mid.go();
b_data.plot();

%%
%
% which matches the images we saw previously. 

%% Reading once and for all
%
% It is possible to load all the data in the file into matlab memory
% without having to access each dataset individually. It suffices to call
% the *read* method without parameters and...

vars=uff.read_object([data_path filesep filename]);

%%
%
% ... we get all the objects in the file into a cell structure

vars{1}.plot();




