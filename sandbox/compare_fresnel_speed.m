clear all
close all
clc

N = [10, 50, 100];

% Phantom
pha = uff.phantom();
pha.sound_speed = 1540;                 % speed of sound [m/s]
pha.points = [0,  0,  5e-3, 1;...
            0,  0, 10e-3, 1;...
            0,  0, 20e-3, 1;...
            0,  0, 30e-3, 1;...
            0,  0, 40e-3, 1;...
            10e-3,  0, 20e-3, 1;...
            -10e-3,  0, 20e-3, 1];    % point scatterer position [m]
        
% Probe
prb = uff.linear_array();
prb.N = 128;                  % number of elements
prb.pitch = 300e-6;           % probe pitch in azimuth [m]
prb.element_width = 270e-6;   % element width [m]
prb.element_height = 5000e-6; % element height [m]

% Pulse
pul = uff.pulse();
pul.center_frequency = 5.2e6;       % transducer frequency [MHz]
pul.fractional_bandwidth = 0.6;     % fractional bandwidth [unitless]

% Sequence
F_number = 1.7;
alpha_max = 1/2/F_number;                
N = 31;                                       % number of plane waves
angles = linspace(-alpha_max,alpha_max,N);    % angle vector [rad]
seq = uff.wave();
for n=1:N 
    seq(n)=uff.wave();
    seq(n).wavefront=uff.wavefront.plane;
    seq(n).source.azimuth=angles(n);
    
    seq(n).probe=prb;
    
    seq(n).sound_speed=pha.sound_speed;
end

% Set up new implementation
sim_new = fresnel_new();
sim_new.phantom = pha;                % phantom
sim_new.pulse = pul;                  % transmitted pulse
sim_new.probe = prb;                  % probe
sim_new.sequence = seq;               % beam sequence
sim_new.sampling_frequency = 41.6e6;  % sampling frequency [Hz]

% Set up old implementation
sim_old = fresnel_old();
sim_old.phantom = pha;                % phantom
sim_old.pulse = pul;                  % transmitted pulse
sim_old.probe = prb;                  % probe
sim_old.sequence = seq;               % beam sequence
sim_old.sampling_frequency = 41.6e6;  % sampling frequency [Hz]

% Use timeit() to compare the execution times
tn = timeit(@() sim_new.go())
to = timeit(@() sim_old.go())

% Run both simulators one more time to check that the resulting beamformed
% data looks the same
ch_data_new = sim_new.go();
ch_data_old = sim_old.go();

% Scan
scan = uff.linear_scan('x_axis', linspace(-25e-3,25e-3,512).', ...
    'z_axis', linspace(0, 50e-3, 512).');

bmf = midprocess.das();
bmf.channel_data = ch_data_new;
bmf.scan = scan;
bmf.dimension = dimension.both;

bmf.receive_apodization.window=uff.window.hanning;
bmf.receive_apodization.f_number=F_number;
bmf.receive_apodization.minimum_aperture = [3e-3 3e-3];

bmf.transmit_apodization.window=uff.window.hanning;
bmf.transmit_apodization.f_number=F_number;
bmf.transmit_apodization.minimum_aperture = [3e-3 3e-3];

bf_data_new = bmf.go();

bmf.channel_data = ch_data_old;

bf_data_old = bmf.go();

bf_data_new.plot();
bf_data_old.plot();

err = sum(abs(bf_data_new.data(:)-bf_data_old.data(:)).^2)