%% A comparison of axial and lateral PSF profiles of Field II against USTB's Fresnel simulator.
% 
% _by Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>, Ole Marius Hoel 

%% Clear old workspace and close old plots

clear all;
close all;

%% Basic Constants

c0=1540;     % Speed of sound [m/s]
fs=100e6;    % Sampling frequency [Hz]
dt=1/fs;     % Sampling step [s] 

%% field II initialisation

field_init(0);
set_field('c',c0);              % Speed of sound [m/s]
set_field('fs',fs);             % Sampling frequency [Hz]
set_field('use_rectangles',1);  % use rectangular elements

%% Transducer definition L9-4/38 Ultrasonix, 128-element linear array transducer

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

pulse = uff.pulse();
pulse.center_frequency = f0;
pulse.fractional_bandwidth = 0.6;             % probe bandwidth [1]
t0=(-1.0/pulse.fractional_bandwidth /f0): dt : (1.0/pulse.fractional_bandwidth /f0);
excitation=1;
impulse_response=gauspuls(t0, f0, pulse.fractional_bandwidth );
two_ways_ir= conv(conv(impulse_response,impulse_response),excitation)./norm(impulse_response).^2;
if mod(length(impulse_response),2)
    lag=(length(two_ways_ir)-1)/2;          
else
    lag=(length(two_ways_ir))/2;
end

fig_handle=figure;
plot(((0:(length(two_ways_ir)-1))*dt -lag*dt)*1e6,two_ways_ir); hold on; grid on; axis tight
plot(((0:(length(two_ways_ir)-1))*dt -lag*dt)*1e6,abs(hilbert(two_ways_ir)),'r')
plot([0 0],[min(two_ways_ir) max(two_ways_ir)],'g');
legend('2-ways pulse','Envelope','Estimated lag');
title('2-ways impulse response Field II');
pulse.plot(fig_handle,'','--');

%% Aperture Objects

noSubAz=round(probe.element_width/(lambda/8));        % number of subelements in the azimuth direction
noSubEl=round(probe.element_height/(lambda/8));       % number of subelements in the elevation direction
Th = xdc_linear_array (probe.N, probe.element_width, probe.element_height, kerf, noSubAz, noSubEl, [0 0 Inf]); 
Rh = xdc_linear_array (probe.N, probe.element_width, probe.element_height, kerf, noSubAz, noSubEl, [0 0 Inf]); 

%% Excitation
xdc_excitation (Th, excitation);
xdc_impulse (Th, impulse_response);
xdc_baffle(Th, 0);
xdc_center_focus(Th,[0 0 0]);
xdc_impulse (Rh, impulse_response);
xdc_baffle(Rh, 0);
xdc_center_focus(Rh,[0 0 0]);

%% Phantom

pha=uff.phantom();
pha.sound_speed=1540;            % speed of sound [m/s]
pha.points=[0,  0, 20e-3, 1];    % point scatterer position [m]
fig_handle=pha.plot();   
cropat=round(1.1*2*sqrt((max(pha.points(:,1))-min(probe.x))^2+max(pha.points(:,3))^2)/c0/dt);   % maximum time sample, samples after this will be dumped

%% Output data

t_out=0:dt:((cropat-1)*dt);                 % output time vector
STA=zeros(cropat,probe.N,probe.N);    % impulse response channel data

%% Compute STA signals using Field II

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
end
close(wb);

%% Channel Data

channel_data_field_ii = uff.channel_data();
channel_data_field_ii.sampling_frequency = fs;
channel_data_field_ii.sound_speed = c0;
channel_data_field_ii.initial_time = 0;
channel_data_field_ii.pulse = pulse;
channel_data_field_ii.probe = probe;
channel_data_field_ii.sequence = seq;
channel_data_field_ii.data = STA;

%% Scan

sca=uff.linear_scan('x_axis',linspace(-20e-3,20e-3,256).','z_axis', linspace(1e-3,40e-3,256).');

%% Pipeline

das = midprocess.das();
das.dimension = dimension.both;
das.channel_data=channel_data_field_ii;
das.scan=sca;

das.transmit_apodization.window=uff.window.hanning;
das.transmit_apodization.f_number=1.7;
%das.transmit_apodization.tilt=20*pi/180;
%das.transmit_apodization.plot()


das.receive_apodization.window=uff.window.hanning;
das.receive_apodization.f_number=1.7;
das.receive_apodization.tilt=20*pi/180;
%das.receive_apodization.probe = probe;
%das.receive_apodization.focus = sca;
%das.receive_apodization.plot()

b_data_field_ii =das.go();

b_data_field_ii.plot([],'Field II Simulation',70)

%das.receive_apodization.plot()

