%% CPWC simulation with the USTB built-in Fresnel simulator
%
% In this example we show how to use the built-in fresnel simulator in USTB
% to generate a Coherent Plane-Wave Compounding (CPWC) dataset and how it can
% be beamformed with USTB.
%
% Related materials:
%
% * <http://ieeexplore.ieee.org/stamp/stamp.jsp?arnumber=4816058 Montaldo et al. 2009>
%
% _by Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no> 31.03.2017_

%% Phantom

pha=uff.phantom();
pha.sound_speed=1540;                 % speed of sound [m/s]
pha.points=[0,  0, 20e-3, 1];    % point scatterer position [m]
fig_handle=pha.plot();           
             
%% Probe

prb=uff.linear_array();
prb.N=128;                  % number of elements 
prb.pitch=300e-6;           % probe pitch in azimuth [m]
prb.element_width=270e-6;   % element width [m]
prb.element_height=5000e-6; % element height [m]
prb.plot(fig_handle);

%% Pulse

pul=uff.pulse();
pul.center_frequency=5.2e6;       % transducer frequency [MHz]
pul.fractional_bandwidth=0.6;     % fractional bandwidth [unitless]
pul.plot([],'2-way pulse');

%% Sequence generation

F_number=1.7;
alpha_max=1/2/F_number;                
N=31;                                       % number of plane waves
angles=linspace(-alpha_max,alpha_max,N);    % angle vector [rad]
seq=uff.wave();
for n=1:N 
    seq(n)=uff.wave();
    seq(n).wavefront=uff.wavefront.plane;
    seq(n).source.azimuth=angles(n);
    
    seq(n).probe=prb;
    
    seq(n).sound_speed=pha.sound_speed;
    
    % show source
    fig_handle=seq(n).source.plot(fig_handle);
end

%% The Fresnel simulator

sim=fresnel();

% setting input data 
sim.phantom=pha;                % phantom
sim.pulse=pul;                  % transmitted pulse
sim.probe=prb;                  % probe
sim.sequence=seq;               % beam sequence
sim.sampling_frequency=41.6e6;  % sampling frequency [Hz]

% we launch the simulation
channel_data=sim.go();
 
%% Scan
scan=uff.linear_scan('x_axis', linspace(-2e-3,2e-3,256).', 'z_axis', linspace(18e-3,22e-3,256).');
 
%% midprocess

das=midprocess.das();
das.channel_data=channel_data;
das.scan=scan;

das.dimension = dimension.both();

das.transmit_apodization.window=uff.window.tukey25;
das.transmit_apodization.f_number=F_number;

das.receive_apodization.window=uff.window.tukey25;
das.receive_apodization.f_number=F_number;

% beamforming
b_data=das.go();

% show
figure;
h1=subplot(2,2,1)
b_data.plot(h1,'No tilt');

%% transmit tilt
das.transmit_apodization.tilt=30*pi/180;
b_data=das.go();
h2=subplot(2,2,2)
b_data.plot(h2,'TX 20 degrees');

%% receive tilt
das.transmit_apodization.tilt=0;
das.receive_apodization.tilt=-30*pi/180;
b_data=das.go();
h3=subplot(2,2,3)
b_data.plot(h3,'RX -20 degrees');

%% transmit & receive tilt
das.transmit_apodization.tilt=30*pi/180;
das.receive_apodization.tilt=-30*pi/180;
b_data=das.go();
h4=subplot(2,2,4)
b_data.plot(h4,'TX 20 RX -20 degrees');
