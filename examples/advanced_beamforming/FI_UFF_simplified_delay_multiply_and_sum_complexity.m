%% Processing time comparison of Delay multiply and sum and its simplified version on FI data from an UFF file
%
% _by Sufayan Ikabal Mulani <sufayanm@ifi.uio.no> and Ole Marius Hoel Rindal <olemarius@olemarius.net>

%% Setting up file path
%
% To read data from a UFF file the first we need is, you guessed it, a UFF
% file. We check if it is on the current path and download it from the USTB
% websever.

clc; clear all; close all;

% data location
url='http://ustb.no/datasets/';      % if not found downloaded from here
local_path = [ustb_path(),'/data/']; % location of example data


% Choose dataset
filename='Alpinion_L3-8_FI_hyperechoic_scatterers.uff';

% check if the file is available in the local path or downloads otherwise
tools.download(filename, url, local_path);

%% Reading channel data from UFF file
channel_data=uff.read_object([local_path filename],'/channel_data');
% Check that the user have the correct version of the dataset

channel_data.N_frames = 1; %Only process one frame, they are quite similar anyway
%%
%Print info about the dataset
channel_data.print_authorship

%% Define Scan
% Define the image coordinates we want to beamform in the scan object.
% Notice that we need to use quite a lot of samples in the z-direction. 
% This is because the DMAS creates an "artificial" second harmonic signal,
% so we need high enough sampling frequency in the image to get a second
% harmonic signal.

z_axis=linspace(25e-3,45e-3,1024).';
x_axis=zeros(channel_data.N_waves,1);
for n=1:channel_data.N_waves
    x_axis(n) = channel_data.sequence(n).source.x;
end

scan=uff.linear_scan('x_axis',x_axis,'z_axis',z_axis);

%% Set up the processing pipeline
pipe=pipeline();
pipe.channel_data=channel_data;
pipe.scan=scan;

pipe.transmit_apodization.window=uff.window.scanline;

pipe.receive_apodization.window=uff.window.none;
pipe.receive_apodization.f_number=1.7;

%% Define the DAS beamformer
das = midprocess.das();
%Sum only on transmit, so that we can do DMAS on receice
das.dimension = dimension.transmit(); 

%% Create the DMAS image using the delay_multiply_and_sum postprocess
dmas = postprocess.delay_multiply_and_sum();
dmas.dimension = dimension.receive;
dmas.channel_data = channel_data;
dmas.receive_apodization = pipe.receive_apodization;

tic
b_data_dmas=pipe.go({das dmas});
DMAS_time = toc ;

% beamforming
b_data_dmas.plot([],'DMAS');

%% Create the DMAS image using the simplified_delay_multiply_and_sum postprocess
s_dmas = postprocess.simplified_delay_multiply_and_sum();
s_dmas.dimension = dimension.receive;
s_dmas.channel_data = channel_data;
s_dmas.receive_apodization = pipe.receive_apodization;

tic
b_data_s_dmas=pipe.go({das s_dmas});
s_DMAS_time = toc ;

b_data_s_dmas.plot([],'s-DMAS');

%% Beamform DAS image
% Notice that I redefine the beamformer to summing on both transmit and receive.
das.dimension = dimension.both();

tic
b_data_das=pipe.go({das});
DAS_time = toc ;
b_data_das.plot([],'DAS');

%% Time comparison

fprintf('USTB DMAS beamformer completed in %.2f seconds.\n', DMAS_time)
fprintf('USTB simplified DMAS beamformer completed in %.2f seconds.\n', s_DMAS_time)
fprintf('USTB DAS beamformer completed in %.2f seconds.\n', DAS_time)

%% Plot both images in same plot
% Plot both in same plot with connected axes, try to zoom!
f3 = figure;clf
b_data_dmas.plot(subplot(1,3,1),'DMAS'); % Display image
ax(1) = gca;
b_data_s_dmas.plot(subplot(1,3,2),'s-DMAS'); % Display image
ax(2) = gca;
b_data_das.plot(subplot(1,3,3),'DAS'); % Display image
ax(3) = gca;
linkaxes(ax);

%% Plot in same beamformed data for comparison
b_data_compare = uff.beamformed_data(b_data_das)
b_data_compare.data(:,1,1,1) = b_data_dmas.data./max(b_data_dmas.data);
b_data_compare.data(:,1,1,2) = b_data_s_dmas.data./max(b_data_s_dmas.data);
b_data_compare.data(:,1,1,3) = b_data_das.data./max(b_data_das.data);
b_data_compare.plot([],['1 = DMAS, 2 = Simplified DMAS, 3 = DAS'])

%% Compare DIFF
f3 = figure;clf
b_data_dmas.plot(subplot(1,3,1),'DMAS'); % Display image
ax(1) = gca;
b_data_s_dmas.plot(subplot(1,3,2),'s-DMAS'); % Display image
ax(2) = gca;
subplot(1,3,3)% Display image
imagesc(b_data_dmas.scan.x_axis*1000, b_data_dmas.scan.z_axis*1000, b_data_dmas.get_image()-b_data_s_dmas.get_image());
colorbar; axis image;title('Difference image');
ax(3) = gca;
linkaxes(ax);


