%% CPWC simulation to compare speeds of the various USTB beamformers.
% 
% In this example, we conduct a simple simulation to compare the speeds 
% achieved with USTB's:
% 
% # MATLAB GPU beamformer
% # MEX CUDA beamformer
% # MEX CPU beamformer
% 
% This tutorial assumes familiarity with the contents of the 
% <./CPWC_linear_array.html 'CPWC simulation with the USTB built-in Fresnel 
% simulator'> tutorial. Please feel free to refer back to that for more 
% details.
% 
% Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no> 
% Arun Asokan Nair <anair8@jhu.edu> 
% Stefano Fiorentini <stefano.fiorentini@ntnu.no>
% Last edited: 03-01-2018

clear all;
close all;
clear classes
clc

%% Phantom


x_sca=[zeros(1,7) -15e-3:5e-3:15e-3];
z_sca=[5e-3:5e-3:35e-3 20e-3*ones(1,7)];
N_sca=length(x_sca);
pha=uff.phantom();
pha.sound_speed=1540;            % speed of sound [m/s]
pha.points=[x_sca.', zeros(N_sca,1), z_sca.', ones(N_sca,1)];    % point scatterer position [m]
% fig_handle=pha.plot();             
             
%% Probe

prb=uff.linear_array();
prb.N=128;                  % number of elements 
prb.pitch=300e-6;           % probe pitch in azimuth [m]
prb.element_width=270e-6;   % element width [m]
prb.element_height=5000e-6; % element height [m]
% prb.plot(fig_handle);

%% Pulse

pul=uff.pulse();
pul.center_frequency=5.2e6;       % transducer frequency [MHz]
pul.fractional_bandwidth=0.6;     % fractional bandwidth [unitless]

%% Sequence generation

N_plane_waves=3;
angles=linspace(-0.3,0.3,N_plane_waves);
seq=uff.wave();
for n=1:N_plane_waves 
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
sim.sampling_frequency=41.6e6;  % sampling frequency [Hz]

channel_data=sim.go();
 
%% Scan

sca=uff.linear_scan('x_axis',linspace(-20e-3,20e-3,512).', 'z_axis', linspace(0e-3,40e-3,512).');
 
%% Pipeline

pipe=pipeline();
pipe.channel_data=channel_data;
pipe.scan=sca;

pipe.receive_apodization.window=uff.window.tukey50;
pipe.receive_apodization.f_number=1.0;

pipe.transmit_apodization.window=uff.window.tukey50;
pipe.transmit_apodization.f_number=1.0;

%% Test beamforming speed 

n_frame=1:25:100;
do_per_frame = sca.N_pixels*channel_data.N_channels*channel_data.N_waves;
das_mex_time = zeros(length(n_frame), 1);
das_mex_gpu_time = zeros(length(n_frame), 1);
das_matlab_gpu_time = zeros(length(n_frame), 1);
das_gpu_frameloop_chunk_time = zeros(length(n_frame), 1);
for n=1:length(n_frame)
    % replicate frames
    channel_data.data=repmat(channel_data.data(:,:,:,1),[1 1 1 n_frame(n)]);

    % Time USTB's MEX GPU implementation
    proc            = midprocess.das();
    proc.code       = code.mex_gpu;
    proc.dimension  = dimension.both;
    tic()
    bf_data_mex_gpu          = pipe.go({proc});
    das_mex_gpu_time(n) = toc;
    
    % Time USTB's MATLAB GPU implementation
    proc            = midprocess.das();
    proc.code       = code.matlab_gpu;
    proc.dimension  = dimension.both;
    tic()
    bf_data_matlab_gpu          = pipe.go({proc});
    das_matlab_gpu_time(n) = toc;
    
    % Time USTB's MEX CPU implementation
    proc            = midprocess.das();
    proc.code       = code.mex;
    proc.dimension  = dimension.both;
    tic()
    bf_data_mex_cpu          = pipe.go({proc});
    das_mex_time(n) = toc;
end

% Plot the runtimes
figure(101); hold on; grid on; box on;
plot(n_frame(1:n)*do_per_frame/1e9,das_matlab_gpu_time(1:n),'bs-','linewidth',2);
plot(n_frame(1:n)*do_per_frame/1e9,das_mex_gpu_time(1:n),'cs-','linewidth',2);
plot(n_frame(1:n)*do_per_frame/1e9,das_mex_time(1:n),'ro-','linewidth',2);

for nn=1:length(n_frame)
    text(n_frame(nn)*do_per_frame/1e9+0.1,das_matlab_gpu_time(nn)-0.1,sprintf('%0.2f s',das_matlab_gpu_time(nn)));
    text(n_frame(nn)*do_per_frame/1e9+0.1,das_mex_gpu_time(nn)-0.1,sprintf('%0.2f s',das_mex_gpu_time(nn)));
    text(n_frame(nn)*do_per_frame/1e9+0.1,das_mex_time(nn)-0.1,sprintf('%0.2f s',das_mex_time(nn)));
end
legend('MATLAB GPU', 'MEX CUDA', 'MEX CPU', 'Location','NorthWest');
xlabel('Delay operations [10^9]');
ylabel('Elapsed time [s]');
set(gca,'fontsize', 12)




