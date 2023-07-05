%% Computation of a FI dataset with Field II and beamforming with USTB
%
% This example shows how to load the data from a Field II simulation into 
% USTB objects, and then beamformt it with the USTB routines. 
% This example uses the L11-4v 128 element Verasonics Transducer
% The Field II simulation program (field-ii.dk) should be in MATLAB's path.
%
% This example is imaging with focused transmit waves (Focused Imaging-FI),
% and is compared to the Fresnel simulation.
%
% authors:  Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>
%           Ole Marius Hoel Rindal <olemarius@olemarius.net>
%           Fabrice Prieur <fabrice@ifi.uio.no>
%
% Last updated: 12.11.2017

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

%% Transducer definition L11-4v, 128-element linear array transducer
% 
% Our next step is to define the ultrasound transducer array we are using.
% For this experiment, we shall use the L11-4v 128 element Verasonics
% Transducer and set our parameters to match it.

probe = uff.linear_array();
f0                      = 5.1333e+06;      % Transducer center frequency [Hz]
lambda                  = c0/f0;           % Wavelength [m]
probe.element_height    = 5e-3;            % Height of element [m]
probe.pitch             = 0.300e-3;        % probe.pitch [m]
kerf                    = 0.03e-03;        % gap between elements [m]
probe.element_width     = probe.pitch-kerf;% Width of element [m]
lens_el                 = 20e-3;           % position of the elevation focus
probe.N                 = 128;             % Number of elements
pulse_duration          = 2.5;             % pulse duration [cycles]
N_active                = 32;              % Nuber of elements for xmit
z_focus                 =40/1000;          %  Transmit focus

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
lag = length(two_way_ir)/2+1;   

% show the pulse to check that the lag estimation is on place (and that the pulse is symmetric)
figure;
plot((0:(length(two_way_ir)-1))*dt -lag*dt,two_way_ir); hold on; grid on; axis tight
plot((0:(length(two_way_ir)-1))*dt -lag*dt,abs(hilbert(two_way_ir)),'r')
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

% Usually you want to have one scan line per element and start the image
% so that you can use all active elements and don't have "roll" of the edge
if 0
    no_lines = (probe.N-N_active);                   %  Number of lines in image
    image_width=(probe.N-N_active)*probe.pitch;      %  Size of image sector
else
    %But for our simple simulation we want to oversample the number of
    %lateral lines, and only image a small area around our scatterer
    no_lines=256; 
    image_width = 10/1000; %Setting image with to 10 mm
   
end
d_x=image_width/no_lines;                           %  Increment for image
apo=ones(1,N_active);

%% Pantom with simple point creating the PSF
phantom_positions(1,:) = [0 0 z_focus];
phantom_amplitudes(1) = 1;

%% output data
cropat=round(1.1*2*sqrt((max(phantom_positions(:,1))-min(probe.x))^2+max(phantom_positions(:,3))^2)/c0/dt);   % maximum time sample, samples after this will be dumped
STA=zeros(cropat,probe.N,no_lines);    % impulse response channel data

%% Compute STA signals
disp('Field II: Computing FI dataset');

parfor n=1:no_lines
    fprintf('Now computing line %d\n',n);    
    % Define Th and Rh in loop to be able to do parfor
    field_init(0);
    Th = xdc_linear_array (probe.N, probe.element_width, probe.element_height, kerf, noSubAz, noSubEl, [0 0 Inf]); 
    Rh = xdc_linear_array (probe.N, probe.element_width, probe.element_height, kerf, noSubAz, noSubEl, [0 0 Inf]); 
    
    % setting excitation, impulse response and baffle
    xdc_excitation (Th, excitation);
    xdc_impulse (Th, impulse_response);
    xdc_baffle(Th, 0);
    xdc_impulse (Rh, impulse_response);
    xdc_baffle(Rh, 0);
    xdc_center_focus(Rh,[0 0 0]);

    % transmit aperture center
    x= -image_width/2 +(n-1)*d_x;

	% Set the focus for this direction with the proper reference point
    xdc_center_focus (Th, [x 0 0]);
    xdc_focus (Th, 0, [x 0 z_focus]);
	N_pre  = round(x/probe.pitch + probe.N/2 - N_active/2);
    N_post = probe.N - N_pre - N_active;
    apo_vector=[zeros(1,N_pre) apo zeros(1,N_post)];
    xdc_apodization (Th, 0, apo_vector);
    
    % receive aperture    
    xdc_apodization(Rh, 0, ones(1,probe.N));
    xdc_focus_times(Rh, 0, zeros(1,probe.N));

    % do calculation
    [v,t]=calc_scat_multi(Th, Rh, phantom_positions, phantom_amplitudes);

    % save data -> with parloop we need to pad the data
    if size(v,1)<cropat
        STA(:,:,n)=padarray(v,[cropat-size(v,1) 0],0,'post');    
    else
        STA(:,:,n)=v(1:cropat,:);
    end
    
    %% SEQUENCE GENERATION
    seq(n)=uff.wave();
    seq(n).probe=probe;
    seq(n).source.xyz=[x 0 z_focus];
    seq(n).origin.x = seq(n).source.x;
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
channel_data.data = STA./max(STA(:));

clear STA;

%% Run Fresnel beamformer to compare

% Fresnel Phantom
pha=uff.phantom();
pha.sound_speed=c0;            % speed of sound [m/s]
pha.points=[0,  0, z_focus, 1];    % point scatterer position [m] 

sim=fresnel();

% Setting up Frenel simulation
sim.phantom=pha;                % phantom
sim.pulse=pulse;                % transmitted pulse
sim.probe=probe;                % probe
sim.sequence=seq;               % beam sequence
sim.sampling_frequency=41.6e6;  % sampling frequency [Hz]

% we launch the simulation
channel_data_fresnel=sim.go();
%%
channel_data_fresnel.plot();title('Fresnel')
channel_data.plot(); title('Field II')

%% Create Scan
z_axis = linspace(35e-3,45e-3,200).';
x_axis = zeros(channel_data.N_waves,1); 
for n=1:channel_data.N_waves
    x_axis(n)=channel_data.sequence(n).source.x;
end
scan=uff.linear_scan('x_axis',x_axis,'z_axis',z_axis);

%% BEAMFORMER
mid=midprocess.das();
mid.channel_data=channel_data;
mid.scan=scan;
mid.dimension = dimension.both();
mid.receive_apodization.window=uff.window.boxcar;
mid.receive_apodization.f_number=1.7;
mid.transmit_apodization.window=uff.window.scanline;

% Delay and sum on receive, then coherent compounding
b_data_field_II = mid.go();

% Change to channel_data from Fresnel
mid.channel_data = channel_data_fresnel;
b_data_fresnel = mid.go();

%% Display images and the lateral line through the PSF
figure(1);
b_data_field_II.plot(subplot(1,2,1),'Field II')
b_data_fresnel.plot(subplot(1,2,2),'Fresnel');

img_field_II = b_data_field_II.get_image();
img_fresnel = b_data_fresnel.get_image();

figure; hold all;
plot(img_field_II(end/2,:)); 
plot(img_fresnel(end/2,:));
legend('Field II','Fresnel');

% Uncomment this to save to UFF file
% filename = 'FI_Field_II.uff'
% channel_data.write(filename,'channel_data');
% b_data.write(uff_filename,'b_data');
% scan.write(uff_filename,'scan');
