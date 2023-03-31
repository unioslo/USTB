%% A comparison of axial and lateral PSF profiles of Field II against USTB's Fresnel simulator.
%
% This example shows how to load the data from a Field II simulation into
% USTB objects, and then beamform it with the USTB routines and compare the
% axial and lateral PSF profiles of Field II against USTB's Fresnel simulator. 
% This example uses the 128 element L9-4/38 Ultrasonix ultrasound transducer
% The Field II simulation program (<field-ii.dk>) should be in MATLAB's path.
% 
% This tutorial assumes familiarity with the contents of the 
% <../../fresnel/linear_array/html/CPWC_linear_array.html 'CPWC simulation with the USTB built-in Fresnel 
% simulator'> tutorial. Please feel free to refer back to that for more 
% details.
% 
% _by Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>, Ole Marius Hoel 
% Rindal <olemarius@olemarius.net> and Arun Asokan Nair <anair8@jhu.edu> 09.05.2017_

%% Clear old workspace and close old plots

clear all;
close all;

%% Basic Constants
% 
% Our first step is to define some basic constants for our imaging scenario
% - below, we set the speed of sound in the tissue, sampling frequency and
% sampling step size in time.

c0=1540;     % Speed of sound [m/s]
fs=100e6;    % Sampling frequency [Hz]
dt=1/fs;     % Sampling step [s] 

%% field II initialisation
% 
% Next, we initialize the field II toolbox. Again, this only works if the 
% Field II simulation program (<field-ii.dk>) is in MATLAB's path. We also
% pass our set constants to it.

field_init(0);
set_field('c',c0);              % Speed of sound [m/s]
set_field('fs',fs);             % Sampling frequency [Hz]
set_field('use_rectangles',1);  % use rectangular elements

%% Transducer definition L9-4/38 Ultrasonix, 128-element linear array transducer
% 
% Our next step is to define the ultrasound transducer array we are using.
% For this experiment, we shall use the L9-4/38 128 element Ultrasonix
% Transducer and set our parameters to match it.

probe = uff.linear_array();
f0                      =5e6;             % Transducer center frequency [Hz]
lambda                  =c0/f0;           % Wavelength [m]
probe.element_height    =6e-3;            % Height of element [m]
probe.pitch             =0.3048e-3;       % probe.pitch [m]
kerf                    =0.035e-3;        % gap between elements [m]
probe.element_width     =probe.pitch-kerf;% Width of element [m]
lens_el                 =19e-3;           % position of the elevation focus
probe.N                 =128;             % Number of elements

%% Pulse definition
% 
% We then define the pulse-echo signal which is done here using the 
% *fresnel* simulator's *pulse* structure. We could also use 
% <http://field-ii.dk/ 'Field II'> for a more accurate model.

pulse = uff.pulse();
pulse.center_frequency = f0;
pulse.fractional_bandwidth = 0.1;             % probe bandwidth [1]
t0=(-1.0/pulse.fractional_bandwidth /f0): dt : (1.0/pulse.fractional_bandwidth /f0);
excitation=1;
impulse_response=gauspuls(t0, f0, pulse.fractional_bandwidth );
two_ways_ir= conv(conv(impulse_response,impulse_response),excitation)./norm(impulse_response).^2;
if mod(length(impulse_response),2)
    lag=(length(two_ways_ir)-1)/2;          
else
    lag=(length(two_ways_ir))/2;
end

% We display the pulse to check that the lag estimation is on place 
% (and that the pulse is symmetric)

fig_handle=figure;
plot(((0:(length(two_ways_ir)-1))*dt -lag*dt)*1e6,two_ways_ir); hold on; grid on; axis tight
plot(((0:(length(two_ways_ir)-1))*dt -lag*dt)*1e6,abs(hilbert(two_ways_ir)),'r')
plot([0 0],[min(two_ways_ir) max(two_ways_ir)],'g');
legend('2-ways pulse','Envelope','Estimated lag');
title('2-ways impulse response Field II');
pulse.plot(fig_handle,'','--');

%% Aperture Objects
% Next, we define the the mesh geometry with the help of Field II's
% *xdc_linear_array* function.

noSubAz=round(probe.element_width/(lambda/8));        % number of subelements in the azimuth direction
noSubEl=round(probe.element_height/(lambda/8));       % number of subelements in the elevation direction
Th = xdc_linear_array (probe.N, probe.element_width, probe.element_height, kerf, noSubAz, noSubEl, [0 0 Inf]); 
Rh = xdc_linear_array (probe.N, probe.element_width, probe.element_height, kerf, noSubAz, noSubEl, [0 0 Inf]); 

% We also set the excitation, impulse response and baffle as below:
xdc_excitation (Th, excitation);
xdc_impulse (Th, impulse_response);
xdc_baffle(Th, 0);
xdc_center_focus(Th,[0 0 0]);
xdc_impulse (Rh, impulse_response);
xdc_baffle(Rh, 0);
xdc_center_focus(Rh,[0 0 0]);

%% Phantom
%
% In our next step, we define our phantom. Here, our phantom is a single point 
% scatterer. 

pha=uff.phantom();
pha.sound_speed=1540;            % speed of sound [m/s]
pha.points=[0,  0, 20e-3, 1];    % point scatterer position [m]
fig_handle=pha.plot();   
cropat=round(1.1*2*sqrt((max(pha.points(:,1))-min(probe.x))^2+max(pha.points(:,3))^2)/c0/dt);   % maximum time sample, samples after this will be dumped

%% Output data
% 
% We define the variables to store our output data

t_out=0:dt:((cropat-1)*dt);                 % output time vector
STA=zeros(cropat,probe.N,probe.N);    % impulse response channel data
%% Compute STA signals using Field II
% 
% Now, we finally reach the stage where we generate a STA (Synthetic
% Transmit Aperture) dataset with the help of Field II.

disp('Field II: Computing STA dataset');
wb = waitbar(0, 'Field II: Computing STA dataset');
for n=1:probe.N
    waitbar(n/probe.N, wb);

    % transmit aperture
    xdc_apodization(Th, 0, [zeros(1,n-1) 1 zeros(1,probe.N-n)]);
    xdc_focus_times(Th, 0, zeros(1,probe.N));
    
    % receive aperture    
    xdc_apodization(Rh, 0, ones(1,probe.N));
    xdc_focus_times(Rh, 0, zeros(1,probe.N));
    
    % do calculation
    [v,t]=calc_scat_multi(Th, Rh, pha.points(1:3), pha.points(4));
    
    % build the dataset
    STA(1:size(v,1),:,n)=v;
    
    % Sequence generation
    seq(n)=uff.wave();
    seq(n).probe=probe;
    seq(n).source.xyz=[probe.x(n) probe.y(n) probe.z(n)];
    seq(n).sound_speed=c0;
    seq(n).delay = probe.r(n)/c0 - lag*dt + t; % t0 and center of pulse compensation
    seq(n).apodization = uff.apodization();
    seq(n).apodization.window=uff.window.sta;
    seq(n).apodization.origin=seq(n).source;
end
close(wb);

%% Channel Data
% 
% In this part of the code, we creat a uff data structure to specifically
% store the captured ultrasound channel data.

channel_data_field_ii = uff.channel_data();
channel_data_field_ii.sampling_frequency = fs;
channel_data_field_ii.sound_speed = c0;
channel_data_field_ii.initial_time = 0;
channel_data_field_ii.pulse = pulse;
channel_data_field_ii.probe = probe;
channel_data_field_ii.sequence = seq;
channel_data_field_ii.data = STA;

%% Scan
%
% The scan area is defines as a collection of pixels spanning our region of 
% interest. For our example here, we use the *linear_scan* structure, 
% which is defined with two components: the lateral range and the 
% depth range. *scan* too has a useful *plot* method it can call.

sca=uff.linear_scan('x_axis',linspace(-4e-3,4e-3,256).','z_axis', linspace(16e-3,24e-3,256).');

%% Pipeline
%
% With *channel_data* and a *scan* we have all we need to produce an
% ultrasound image. We now use a USTB structure *pipeline*, that takes an
% *apodization* structure in addition to the *channel_data* and *scan*.

pipe=pipeline();
pipe.channel_data=channel_data_field_ii;
pipe.scan=sca;

pipe.receive_apodization.window=uff.window.boxcar;
pipe.receive_apodization.f_number=1.7;
pipe.transmit_apodization.window=uff.window.boxcar;
pipe.transmit_apodization.f_number=1.7;

%% 
%
% The *beamformer* structure allows you to implement different beamformers 
% by combination of multiple built-in *processes*. By changing the *process*
% chain other beamforming sequences can be implemented. It returns yet 
% another *UFF* structure: *beamformed_data*.
% 
% To achieve the goal of this example, we use delay-and-sum (implemented in 
% the *das_mex()* process) as well as coherent compounding.

b_data_field_ii =pipe.go({midprocess.das() postprocess.coherent_compounding()});

%% Compute STA signals using USTB's Fresnel simulator
% 
% We also generate STA (Synthetic Transmit Aperture) data with the help of 
% USTB's Fresnel simulator in order to compare it with Field II.

sim=fresnel();

% setting input data 
sim.phantom=pha;                % phantom
sim.pulse=pulse;                  % transmitted pulse
sim.probe=probe;                  % probe
sim.sequence=seq;               % beam sequence
sim.sampling_frequency=channel_data_field_ii.sampling_frequency;  % sampling frequency [Hz]

% we launch the simulation
channel_data_fresnel=sim.go();


%% BEAMFORM data from Fresnel simulation
pipe.channel_data=channel_data_fresnel;
% Delay and sum on receive, then coherent compounding
b_data_fresnel =pipe.go({midprocess.das() postprocess.coherent_compounding()});


%% Display images
figure(101);
ax1 = subplot(121);
ax2 = subplot(122);

b_data_field_ii.plot(ax1,'Field II Simulation')
b_data_fresnel.plot(ax2,'Fresnel Simulation')


%% compare lateral profile to sinc
img_field_ii = b_data_field_ii.get_image;
lateral_profile_field_ii=img_field_ii(128,:);
lateral_profile_field_ii=lateral_profile_field_ii-max(lateral_profile_field_ii);

img_fresnel = b_data_fresnel.get_image;
lateral_profile_fresnel=img_fresnel(128,:);
lateral_profile_fresnel=lateral_profile_fresnel-max(lateral_profile_fresnel);

theoretical_profile=20*log10(sinc(1/pipe.receive_apodization.f_number(1)/lambda*b_data_field_ii.scan.x_axis).^2);

figure;
plot(b_data_field_ii.scan.x_axis*1e3,lateral_profile_field_ii); hold all; grid on; 
plot(b_data_field_ii.scan.x_axis*1e3,lateral_profile_fresnel,'k'); 
plot(b_data_field_ii.scan.x_axis*1e3,theoretical_profile,'r'); 
legend('Field II Simulation','Fresnel Simulation','Theoretical');
xlabel('x [mm]');
ylabel('Amplitude [dB]');
title('Lateral (x-axis) profile ');

%% compare axial profile
axial_profile_field_ii=img_field_ii(:,128);
axial_profile_field_ii=axial_profile_field_ii-max(axial_profile_field_ii);

axial_profile_fresnel=img_fresnel(:,128);
axial_profile_fresnel=axial_profile_fresnel-max(axial_profile_fresnel);

figure;
plot(b_data_field_ii.scan.x_axis*1e3,axial_profile_field_ii); hold all; grid on; 
plot(b_data_field_ii.scan.x_axis*1e3,axial_profile_fresnel,'k'); 
legend('Field II Simulation','Fresnel Simulation');
xlabel('z [mm]');
ylabel('Amplitude [dB]');
title('Axial (z-axis) profile ');