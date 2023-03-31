%% Computation of a FI dataset with Field II and beamforming with USTB
%
% This example shows how to load the data from a Field II simulation into 
% USTB objects, and then beamformt it with the USTB routines. 
% This example uses the P4-2v 64 element Verasonics Transducer
% The Field II simulation program (field-ii.dk) should be in MATLAB's path.
%
% This example is imaging with focused transmit waves (Focused Imaging-FI).
% The example also demonstates calculation of the coherence factor and some
% functionality to plot the images using built in USTB routines, MATLAB
% commands and some details on scan conversion.
% 
%
% authors:  Ole Marius Hoel Rindal <olemarius@olemarius.net>
%           Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>
%
% Last updated: 15.01.2020

clear all;
close all;

%% basic constants

c0=1540;     % Speed of sound [m/s]
fs=100e6;    % Sampling frequency [Hz]
dt=1/fs;     % Sampling step [s] 

%% field II initialisation
field_init(0);
set_field('c',c0);              % Speed of sound [m/s]
set_field('fs',fs);             % Sampling frequency [Hz]
set_field('use_rectangles',1);  % use rectangular elements

%% transducer definition P4-2v Verasonics 64-element phased
% 
% Our next step is to define the ultrasound transducer array we are using.
% For this experiment, we shall use the L11-4v 128 element Verasonics
% Transducer and set our parameters to match it.
probe = uff.linear_array();
f0=2.56e6;                              % Transducer center frequency [Hz]
bw=0.67;                                % probe bandwidth [1]
lambda=c0/f0;                           % Wavelength [m]
probe.element_height=5e-3;              % Height of element [m]
probe.pitch =0.300e-3;                  % pitch [m]
kerf=0.050e-3;                          % gap between elements [m]
probe.element_width=probe.pitch-kerf;   % Width of element [m]
lens_el=60e-3;                          % position of the elevation focus
probe.N=64;                             % Number of elements
pulse_duration=2.5;                     % pulse duration [cycles]
z_focus =60/1000;                       % Transmit focus

%% pulse definition
pulse = uff.pulse();
pulse.center_frequency = f0;
pulse.fractional_bandwidth = 0.65;        % probe bandwidth [1]
t0 = (-1/pulse.fractional_bandwidth/f0): dt : (1/pulse.fractional_bandwidth/f0);
impulse_response = gauspuls(t0, f0, pulse.fractional_bandwidth);
impulse_response = impulse_response-mean(impulse_response); % To get rid of DC

te = (-pulse_duration/2/f0): dt : (pulse_duration/2/f0);
excitation = square(2*pi*f0*te+pi/2);
one_way_ir = conv(impulse_response,excitation);
two_way_ir = conv(one_way_ir,impulse_response);  
[~, lag] = max(abs(hilbert(two_way_ir)))

% show the pulse to check that the lag estimation is on place (and that the pulse is symmetric)
figure;
plot((1:(length(two_way_ir)))*dt -lag*dt,two_way_ir); hold on; grid on; axis tight
plot((1:(length(two_way_ir)))*dt -lag*dt,abs(hilbert(two_way_ir)),'r')
plot([0 0],[min(two_way_ir) max(two_way_ir)],'g');
legend('2-ways pulse','Envelope','Estimated lag');
title('2-ways impulse response Field II');

%% aperture objects
% definition of the mesh geometry
noSubAz=round(probe.element_width/(lambda/8));        % number of subelements in the azimuth direction
noSubEl=round(probe.element_height/(lambda/8));       % number of subelements in the elevation direction
Th = xdc_linear_array (probe.N, probe.element_width, probe.element_height, kerf, noSubAz, noSubEl, [0 0 Inf]); 
Rh = xdc_linear_array (probe.N, probe.element_width, probe.element_height, kerf, noSubAz, noSubEl, [0 0 Inf]); 

% setting excitation, impulse response and baffle
xdc_excitation (Th, excitation);
xdc_impulse (Th, impulse_response);
xdc_baffle(Th, 0);
xdc_center_focus(Th,[0 0 0]);
xdc_impulse (Rh, impulse_response);
xdc_baffle(Rh, 0);
xdc_center_focus(Rh,[0 0 0]);

%% Set up the transmit sequence
no_transmits=128; 
transmit_angles = linspace(-30,30,no_transmits);
R_focus = 60/1000;


%% Create a phantom to image
phantom_positions(1,:) = [0 0 R_focus];
phantom_positions(2,:) = [0 0 20/1000];
phantom_positions(3,:) = [0 0 40/1000];
phantom_positions(4,:) = [0 0 80/1000];
phantom_positions(5,:) = [0 0 100/1000];
phantom_positions(6,:) = [R_focus*sind(-15) 0 R_focus*cosd(-15)];
phantom_positions(7,:) = [20/1000*sind(-15) 0 20/1000*cosd(-15)];
phantom_positions(8,:) = [40/1000*sind(-15) 0 40/1000*cosd(-15)];
phantom_positions(9,:) = [80/1000*sind(-15) 0 80/1000*cosd(-15)];
phantom_positions(10,:) = [100/1000*sind(-15) 0 100/1000*cosd(-15)];
phantom_amplitudes(1:10) = 1;

%% output data
cropat=round(1.1*2*sqrt((max(phantom_positions(:,1))-min(probe.x))^2+max(phantom_positions(:,3))^2)/c0/dt);   % maximum time sample, samples after this will be dumped
data=zeros(cropat,probe.N,no_transmits);    % impulse response channel data

%% Compute STA signals
fprintf('Field II: Computing FI dataset \n \n');
disp('~')
for n=1:no_transmits
    s = sprintf('\nSimulating transmit %d / %d',n,no_transmits);
    b = repmat('\b', [1, length(s)]);
    fprintf(1, [b, s]);
    % Define Th and Rh in loop to be able to do parfor
    %field_init(0);
    %Th = xdc_linear_array (probe.N, probe.element_width, probe.element_height, kerf, noSubAz, noSubEl, [0 0 Inf]); 
    %Rh = xdc_linear_array (probe.N, probe.element_width, probe.element_height, kerf, noSubAz, noSubEl, [0 0 Inf]); 
    
    % setting excitation, impulse response and baffle
    %xdc_excitation (Th, excitation);
    %xdc_impulse (Th, impulse_response);
    %xdc_baffle(Th, 0);
    %xdc_impulse (Rh, impulse_response);
    %xdc_baffle(Rh, 0);
    %xdc_center_focus(Rh,[0 0 0]);

    x_focus = sind(transmit_angles(n)).*R_focus;
    z_focus = cosd(transmit_angles(n)).*R_focus;

	% Set the focus for this direction with the proper reference point
    xdc_center_focus (Th, [0 0 0]);
    xdc_focus (Th, 0, [x_focus 0 z_focus]);
    xdc_apodization (Th, 0, ones(1,probe.N));
    
    % receive aperture    
    xdc_apodization(Rh, 0, ones(1,probe.N));
    xdc_focus_times(Rh, 0, zeros(1,probe.N));

    % do calculation
    [v,t]=calc_scat_multi(Th, Rh, phantom_positions, phantom_amplitudes');

    % save data -> with parloop we need to pad the data
    if size(v,1)<cropat
        data(:,:,n)=padarray(v,[cropat-size(v,1) 0],0,'post');    
    else
        data(:,:,n)=v(1:cropat,:);
    end
    
    %% SEQUENCE GENERATION
    seq(n)=uff.wave();
    seq(n).probe=probe;
    seq(n).source.xyz=[x_focus 0 z_focus];
    seq(n).sound_speed=c0;
    seq(n).delay = -lag*dt+t;
end


%% CHANNEL DATA
channel_data = uff.channel_data();
channel_data.sampling_frequency = fs;
channel_data.sound_speed = c0;
channel_data.initial_time = 0;
channel_data.pulse = pulse;
channel_data.probe = probe;
channel_data.sequence = seq;
channel_data.data = data./max(data(:)) + 1000*eps*randn(size(data));
clear data

%% Create Sector Scan
z_axis = linspace(0,100e-3,200).';
x_axis = zeros(channel_data.N_waves,1); 
for n=1:channel_data.N_waves
    x_axis(n)=channel_data.sequence(n).source.x;
end
scan=uff.linear_scan('x_axis',x_axis,'z_axis',z_axis);

%% Create Sector scan
depth_axis=linspace(0e-3,110e-3,512).';
azimuth_axis=zeros(channel_data.N_waves,1);
for n=1:channel_data.N_waves
    azimuth_axis(n) = channel_data.sequence(n).source.azimuth;
end

scan=uff.sector_scan('azimuth_axis',azimuth_axis,'depth_axis',depth_axis);
%% BEAMFORMER
mid=midprocess.das();
mid.channel_data=channel_data;
mid.dimension = dimension.transmit()
mid.scan=scan;
mid.receive_apodization.window=uff.window.boxcar;
mid.receive_apodization.f_number=1.7;
mid.transmit_apodization.window=uff.window.scanline;

% Delay the data
b_data_delayed = mid.go();

%% Do coherent compounding to get DAS image
das = postprocess.coherent_compounding();
das.input = b_data_delayed;
b_data_das = das.go();
b_data_das.plot([],'DAS');

%% Calculate the coherence factor
cf = postprocess.coherence_factor();
cf.dimension = dimension.receive();
cf.input = b_data_delayed;
b_data_weighted_cf = cf.go();

b_data_weighted_cf.plot([],'Das Weighted CF'); %This is the DAS.*CF as suggested by the authors

%% This is the "pure" coherence factor
cf.CF.plot([],'CF',[],'none');
caxis([0 1])

%% Get the delayed channel data as a matrix
delayed_channel_data = reshape(b_data_delayed.data,scan.N_depth_axis,scan.N_azimuth_axis,probe.N_elements);

das = sum(delayed_channel_data,3);

cf = abs(sum(delayed_channel_data,3)).^2./(probe.N * sum(abs(delayed_channel_data).^2,3));

%% Plot images in beamspace
figure();clf;
subplot(121)
imagesc((abs(das./max(das))));caxis([0 1])
title('DAS linear scale');
subplot(122)
imagesc(cf);caxis([0 1])
title('CF linear scale');

%% "Manual" implementation of the coherence factor creating a coherent and an incoherent image
coherent = abs(sum(delayed_channel_data,3)).^2;
incoherent = sum(abs(delayed_channel_data).^2,3);

cf = coherent./(probe.N * incoherent);
subplot(224)
imagesc(incoherent./max(incoherent(:)));caxis([0 1]),colorbar
title('Incoherent image');
 
%% New code cell demonstrating some plotting functionalities

% Plotting using matlab functions
figure()
subplot(121)
wImg = 20*log10(coherent);
wImgNormFactor = max(wImg(:));
imagesc(wImg(:,:)-wImgNormFactor); colormap(gray(256)); caxis([-55 0]); colorbar;
subplot(122)
wImg = 20*log10(incoherent);
wImgNormFactor = max(wImg(:));
imagesc(wImg(:,:)-wImgNormFactor); colormap(gray(256)); caxis([-55 0]); colorbar;

%Creating new objects copying info from b_data_das
b_data_coherent = uff.beamformed_data(b_data_das);
b_data_incoherent = uff.beamformed_data(b_data_das);

% Overwriting data with coherent and incoherent images
b_data_coherent.data = coherent(:);
b_data_incoherent.data = incoherent(:);

% Plotting using built in USTB functions
b_data_coherent.plot([],'Coherent');
b_data_incoherent.plot([],'Incoherent');

% Plotting using built in USTB functions in same figure
figure
b_data_coherent.plot(subplot(121),'Coherent');
b_data_incoherent.plot(subplot(122),'Incoherent');
