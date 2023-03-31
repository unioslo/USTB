%% Preliminary example of the Generalized Coherence Factor compared to SLSC
%
% _by Ole Marius Hoel Rindal <olemarius@olemarius.net>_
%
% Last updated 15.05.2018

%% Setting up file path
%
% To read data from a UFF file the first we need is, you guessed it, a UFF
% file. We check if it is on the current path and download it from the USTB
% websever.

clear all; close all;

% data location
url='http://ustb.no/datasets/';      % if not found downloaded from here
local_path = [ustb_path(),'/data/']; % location of example data

% Choose dataset
filename='Alpinion_L3-8_FI_hypoechoic.uff';

% check if the file is available in the local path or downloads otherwise
tools.download(filename, url, local_path);

%% Reading channel data from UFF file
channel_data=uff.read_object([local_path filename],'/channel_data');

%%
%Print info about the dataset
channel_data.print_authorship

%% Define Scan
% Define the image coordinates we want to beamform in the scan object.
% Notice that we need to use quite a lot of samples in the z-direction. 
% This is because the DMAS creates an "artificial" second harmonic signal,
% so we need high enough sampling frequency in the image to get a second
% harmonic signal.

z_axis=linspace(34e-3,48e-3,750).';
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
clear das;
das = midprocess.das();
%Sum only on transmit, so that we can do DMAS on receice
das.dimension = dimension.transmit(); 
b_data_tx = pipe.go({das});


%% Beamform with the GCF (Generalized Coherence Factor)
gcf = postprocess.generalized_coherence_factor();
gcf.dimension = dimension.receive;
gcf.M0 = 4;
gcf.input = b_data_tx;
gcf.transmit_apodization = pipe.transmit_apodization;
gcf.receive_apodization = pipe.receive_apodization;

b_data_gcf=gcf.go();

%% beamforming
figure(88);
b_data_gcf.plot(subplot(411),'GCF');
gcf.GCF.plot(subplot(412),'GCF factor',[],['none']); 

%% Lets try the SLSC implementation in the USTB as well
slsc = postprocess.short_lag_spatial_coherence();
slsc.dimension = dimension.receive;
slsc.channel_data = channel_data;
slsc.input = b_data_tx;
slsc.K_in_lambda = 1;
slsc.maxM = 10;

b_data_slsc = slsc.go();

%%
b_data_slsc.plot(subplot(413),'SLSC',[],['none']);
%% Beamform DAS image
% Notice that I redefine the beamformer to use Hamming apodization and
% summing on both transmit and receive.
das.dimension = dimension.both();
das.receive_apodization.window=uff.window.hamming;
das.receive_apodization.f_number=1.7;

b_data_das=pipe.go({das});
%%
b_data_das.plot(subplot(414),'DAS');

%% Measure contrast !!! WARNING: Mixed measurment, not comparable. We measure after log compression
%
% Lets measure the contrast using the "contrast ratio" as our metric.

% First we need to put our images in a different data struct that the 
% measure contrast function expects
images.all{1} = b_data_gcf.get_image();
images.tags{1} = 'GCF';
images.all{2} = gcf.GCF.get_image();
images.tags{2} = 'GCF factor';
images.all{3} = b_data_slsc.get_image();
images.tags{3} = 'SLSC';
images.all{4} = b_data_das.get_image();
images.tags{4} = 'DAS';


% Define the coordinates of the regions used to measure contrast
xc_nonecho = -9.5;      % Center of cyst in X
zc_nonecho = 40.8;      % Center of cyst in Z
r_nonecho = 2.8;        % Radi of the circle in the cyst
r_speckle_inner = 4.5;  % Radi of the inner circle defining speckle region
r_speckle_outer = 7;    % Radi of the outer circle defining speckle region

% Call the "tool" to measure the contrast
[CR,C] = tools.measure_contrast_ratio(b_data_das,images,xc_nonecho,...
                    zc_nonecho,r_nonecho,r_speckle_inner,r_speckle_outer);

% Plot the contrast as a bar graph together with the two images
figure(3);clf;hold on
bar([CR'])   
set(gca,'XTick',linspace(1,length(images.tags),length(images.tags)))
set(gca,'XTickLabel',images.tags)
title('Measured Contrast');
ylabel('CR');

%% Here I measure the contrast with another definition before log compression
close all;

% Normalize and prepare data to measure contrast
images.all{1} = (b_data_gcf.get_image('none'));
images.all{1} = images.all{1} ./ max(images.all{1}());
images.tags{1} = 'GCF';
images.all{2} = gcf.GCF.get_image('none');
images.all{2} = images.all{2} ./ max(images.all{2}());
images.tags{2} = 'GCF factor';
images.all{3} = b_data_slsc.get_image('none');
images.all{3}(images.all{3} < 0) = 0; % THIS IS IMPORTANT! We set the negative correlation values to zero.
images.all{3} = images.all{3} ./ max(images.all{3}());
images.tags{3} = 'SLSC';
images.all{4} = (b_data_das.get_image('none'));
images.all{4} = images.all{4} ./ max(images.all{4}());
images.tags{4} = 'DAS';


% Define the coordinates of the regions used to measure contrast
xc_nonecho = -9.5;      % Center of cyst in X
zc_nonecho = 40.8;      % Center of cyst in Z
r_nonecho = 2.5;        % Radi of the circle in the cyst
r_speckle_inner = 4.5;  % Radi of the inner circle defining speckle region
r_speckle_outer = 7;    % Radi of the outer circle defining speckle region

% Call the "tool" to measure the contrast
[CR,C] = tools.measure_contrast_ratio(b_data_das,images,xc_nonecho,...
                    zc_nonecho,r_nonecho,r_speckle_inner,r_speckle_outer,[],1);

% Plot the contrast as a bar graph together with the two images
figure(40);clf;hold on
bar([C'])   
set(gca,'XTick',linspace(1,length(images.tags),length(images.tags)))
set(gca,'XTickLabel',images.tags)
title('Measured Contrast');
ylabel('C');