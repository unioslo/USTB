% Computation of a STAI dataset with Field II to test efficency of 
% demodulation processors

clear all
close all

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
probe = uff.linear_array();
f0                      = 5.1333e+06;      % Transducer center frequency [Hz]
lambda                  = c0/f0;           % Wavelength [m]
probe.element_height    = 5e-3;            % Height of element [m]
probe.pitch             = 0.300e-3;        % probe.pitch [m]
kerf                    = 0.03e-03;        % gap between elements [m]
probe.element_width     = probe.pitch-kerf;% Width of element [m]
lens_el                 = 20e-3;           % position of the elevation focus
probe.N                 = 128;             % Number of elements
pulse_duration          = 1.5;             % pulse duration [cycles]

%% pulse definition
pulse = uff.pulse();
pulse.center_frequency = f0;
pulse.fractional_bandwidth = 1;        % probe bandwidth [1]
t0 = (-1/pulse.fractional_bandwidth/f0): dt : (1/pulse.fractional_bandwidth/f0);
impulse_response = 1e10*gauspuls(t0, f0, pulse.fractional_bandwidth);
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

%% phantom of speckle
number_of_scatterers = 100;
xxp_speckle=random('unif',-5e-3,5e-3,number_of_scatterers,1);
zzp_speckle=random('unif',15e-3,20e-3,number_of_scatterers,1);
sca = [xxp_speckle zeros(length(xxp_speckle),1) zzp_speckle];  % list with the scatterers coordinates [m]
amp=randn(length(sca));                   % list with the scatterers amplitudes

%% output data
cropat=round(1.1*2*sqrt((max(sca(:,1))-min(probe.x))^2+max(sca(:,3))^2)/c0/dt);   % maximum time sample, samples after this will be dumped
STA=zeros(cropat,probe.N,probe.N);    % impulse response channel data

%% Compute STA signals
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
    [v,t]=calc_scat_multi(Th, Rh, sca, amp);
    
    % build the dataset
    STA(1:size(v,1),:,n)=v;
    
    %% SEQUENCE GENERATION
    seq(n)=uff.wave();
    seq(n).probe=probe;
    seq(n).source.xyz=[probe.x(n) probe.y(n) probe.z(n)];
    seq(n).sound_speed=c0;
    seq(n).delay = probe.r(n)/c0-lag*dt+t; % t0 and center of pulse compensation
end
close(wb);

% RF channel data
ch_rf = uff.channel_data();
ch_rf.sampling_frequency = fs;
ch_rf.sound_speed = c0;
ch_rf.initial_time = 0;
ch_rf.pulse = pulse;
ch_rf.probe = probe;
ch_rf.sequence = seq; 
ch_rf.data = STA; % repmat(STA, [1,1,1,50]); % increase dataset to test slicing strategy

clear STA 

% Test demodulation processors
demod = preprocess.fast_demodulation();
demod.plot_on = true;
demod.input = ch_rf;
tic()
demod.go();
toc()

demod = preprocess.demodulation();
demod.plot_on = true;
demod.input = ch_rf;
tic()
demod.go();
toc()

demod = preprocess.hilbert_transform_demodulation();
demod.plot_on = true;
demod.input = ch_rf;
tic()
demod.go();
toc()
