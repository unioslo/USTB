%% CPWC simulation script to profile the MEX CUDA beamformer
%
% The script is meant to be run using NVIDIA profiling tools such as nsys
%
% # MEX CUDA beamformer
%
% Stefano Fiorentini <stefano.fiorentini@ntnu.no>
% Last edited: 03-11-2022


addpath(genpath("D:\stefafi\code\USTB-dev"));

do_demodulation = true;
nFrames = 100;

%% Phantom
x_sca=[zeros(1,7) -15e-3:5e-3:15e-3];
z_sca=[5e-3:5e-3:35e-3 20e-3*ones(1,7)];
N_sca=length(x_sca);
pha=uff.phantom();
pha.sound_speed=1540;                                               % speed of sound [m/s]
pha.points=[x_sca.', zeros(N_sca,1), z_sca.', ones(N_sca,1)];       % point scatterer position [m]

%% Probe
prb=uff.linear_array();
prb.N=128;                  % number of elements
prb.pitch=300e-6;           % probe pitch in azimuth [m]
prb.element_width=270e-6;   % element width [m]
prb.element_height=5e-3;    % element height [m]

%% Pulse

pul=uff.pulse();
pul.center_frequency=5e6;         % transducer frequency [MHz]
pul.fractional_bandwidth=0.8;     % fractional bandwidth [unitless]

%% Sequence generation

nPlaneWaves=5;
angles=linspace(-10, 10, nPlaneWaves)/180*pi;
seq=uff.wave();
for n=1:nPlaneWaves
    seq(n)=uff.wave();
    seq(n).probe=prb;
    seq(n).source.azimuth=angles(n);
    seq(n).source.distance=Inf;
    seq(n).sound_speed=pha.sound_speed;
end

%% Fresnel simulator

sim=fresnel();
sim.phantom=pha;                % phantom
sim.pulse=pul;                  % transmitted pulse
sim.probe=prb;                  % probe
sim.sequence=seq;               % beam sequence
sim.sampling_frequency=50e6;    % sampling frequency [Hz]

channel_data=sim.go();

if do_demodulation
    demod = preprocess.fast_demodulation();
    demod.input = channel_data;
    demod.modulation_frequency = pul.center_frequency;
    demod.downsample_frequency = 2*pul.center_frequency;
    demod.plot_on = false;

    channel_data = demod.go();
end

%% Scan
scan = uff.linear_scan('x_axis',linspace(-2e-2,2e-2,256).', 'z_axis', linspace(0, 4e-2, 256).');

%% Setup beamformer

bmf = midprocess.das;
bmf.channel_data = channel_data;
bmf.channel_data.data = repmat(channel_data.data(:,:,:,1), [1, 1, 1, nFrames]);

bmf.scan=scan;

bmf.receive_apodization.window=uff.window.hamming;
bmf.receive_apodization.f_number=2;

bmf.transmit_apodization.window=uff.window.none;

bmf.code       = code.mex_gpu();
bmf.dimension  = dimension.both;

%% Call beamformer
bmf.go();

%% exit MATLAB
exit()