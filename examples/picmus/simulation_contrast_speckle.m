%% PICMUS challenge: simulation, contrast-speckle test
%
% This example reads (or downloads if it cannot find the data locally) a 
% dataset used in the <http://ieeexplore.ieee.org/document/7728908/ PICMUS challenge>
% and beamforms it with USTB's general beamformer.
% A 75 plane-wave sequence was simulated with <http://field-ii.dk/ Field
% II> to estimate the method constrast and speckle statistics. 
%
% _by Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no> 
%  and Olivier Bernard <olivier.bernard@insa-lyon.fr>_
%
%   $Last updated: 2017/09/15$

%% Checking if the file is in the local path, and downloading otherwise
%
% We define the local path and the url where the data is stored

% data location
url = tools.zenodo_dataset_files_base();
filename='PICMUS_simulation_contrast_speckle.uff';

% checks if the data is in your data path, and downloads it otherwise.
% The defaults data path is under USTB's folder, but you can change this
% by setting an environment variable with setenv(DATA_PATH,'the_path_you_want_to_use');
tools.download(filename, url, data_path);   

%% What's inside?
%
% This dataset should contain the following structures:
% * *channel_data*,
% * *beamformed_data* and,
% * *scan*
%
% We can check it out with the *index* function
display=true;
content = uff.index([data_path filesep filename],'/',display);

%% Plotting beamformed_data
%
% We can read the *beamformed_data* object and plot it 

b_data=uff.read_object([data_path filesep filename],'/beamformed_data');
b_data.plot();

%% Loading channel data & scan
%
% The file also contain channel_data and scan. We read it so we can
% replicate the beamformed image in the UFF file.

channel_data=uff.read_object([data_path filesep filename],'/channel_data');
scan=uff.read_object([data_path filesep filename],'/scan');

%% Beamforming
%
% We define a beamformer, and the corresponding transmit and apodization
% windows, and launch it.

pipe=pipeline();
pipe.channel_data=channel_data;
pipe.scan=scan;
    
% receive apodization
pipe.receive_apodization.window=uff.window.tukey50;
pipe.receive_apodization.f_number=1.7;

% transmit apodization
pipe.transmit_apodization.window=uff.window.tukey50;
pipe.transmit_apodization.f_number=1.7;

% launch beamforming
b_data_new=pipe.go({midprocess.das postprocess.coherent_compounding});

%% Comparing results
%
% We plot both images side by side.

figure;
b_data.plot(subplot(1,2,1),'Original');
b_data_new.plot(subplot(1,2,2),'New');
set(gcf,'Position',[100   100   750   450])
