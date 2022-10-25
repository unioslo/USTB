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

clear all
close all
clc

do_demodulation = true;
nFrames = 1:100:1000;
% nFrames = 5000;
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
prb.element_height=5e-3;    % element height [m]
% prb.plot(fig_handle);

%% Pulse

pul=uff.pulse();
pul.center_frequency=5e6;       % transducer frequency [MHz]
pul.fractional_bandwidth=0.8;     % fractional bandwidth [unitless]

%% Sequence generation

nPlaneWaves=3;
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

    channel_data = demod.go();
end

%% Scan
scan = uff.linear_scan('x_axis',linspace(-20e-3,20e-3,256).', 'z_axis', linspace(0e-3,40e-3,256).');
 
%% Pipeline

pipe=pipeline();
pipe.channel_data=channel_data;
pipe.scan=scan;

pipe.receive_apodization.window=uff.window.hamming;
pipe.receive_apodization.f_number=1.5;

pipe.transmit_apodization.window=uff.window.none;
pipe.transmit_apodization.f_number=1.5;

proc            = midprocess.das();
proc.code       = code.mex();
proc.dimension  = dimension.both;
fprintf(1, 'Precalculating apodization\n')
pipe.go({proc});

%% Test beamforming speed 


dOp_per_frame = scan.N_pixels*channel_data.N_channels*channel_data.N_waves;
if do_demodulation
    dOp_per_frame = dOp_per_frame * 2; % complex data
end

das_mexFast_time = zeros([length(nFrames), 1]);
das_mex_gpu_time = zeros([length(nFrames), 1]);

for n=1:length(nFrames)
    % replicate frames
    channel_data.data=repmat(channel_data.data(:,:,:,1),[1 1 1 nFrames(n)]);

    % Time USTB's MEX GPU implementation
    proc            = midprocess.das();
    proc.code       = code.mex_gpu;
    proc.dimension  = dimension.both;
    fprintf(1, 'Processing %d frames: MEX CUDA\n', nFrames(n))
    tic()
    bf_data_mex_gpu = pipe.go({proc});
    das_mex_gpu_time(n) = toc();

    % Time USTB's MEX FAST CPU implementation
    proc            = midprocess.das();
    proc.code       = code.mexFast;
    proc.dimension  = dimension.both;
    fprintf(1, 'Processing %d frames: MEX C\n', nFrames(n))
    tic()
    bf_data_mexFast_cpu = pipe.go({proc});
    das_mexFast_time(n) = toc();
end

%% Plot the images for visual inspection of the results
figure('Color', 'white')
tiledlayout(1, 3, "TileSpacing", "compact", "Padding", "compact")
hAx(1) = nexttile();
imagesc(scan.x_axis*1e2, scan.z_axis*1e2, ...
    20*log10(abs(reshape(bf_data_mex_gpu.data(:,1), [scan.N_z_axis, scan.N_x_axis])) / ...
    max(abs(bf_data_mex_gpu.data(:,1)))), [-60, 0])
grid on
box on
axis equal tight
xlabel("x [cm]")
ylabel("z [cm]")
title("mex CUDA")

hAx(2) = nexttile();
imagesc(scan.x_axis*1e2, scan.z_axis*1e2, ...
    20*log10(abs(reshape(bf_data_mexFast_cpu.data(:,1), [scan.N_z_axis, scan.N_x_axis])) / ...
    max(abs(bf_data_mexFast_cpu.data(:,1)))), [-60, 0])
grid on
box on
axis equal tight
xlabel("x [cm]")
ylabel("z [cm]")
title("mexFast")

hAx(3) = nexttile();
diff_data = bf_data_mex_gpu.data(:,1) - bf_data_mexFast_cpu.data(:,1);

imagesc(scan.x_axis*1e2, scan.z_axis*1e2, reshape(20*log10(abs(diff_data)), ...
    [scan.N_z_axis, scan.N_x_axis]), [-60, 0])

% imagesc(scan.x_axis*1e2, scan.z_axis*1e2, reshape(angle(diff_data), ...
%     [scan.N_z_axis, scan.N_x_axis]), [-pi, pi])

grid on
box on
axis equal tight
xlabel("x [cm]")
ylabel("z [cm]")
title("Difference image")

linkaxes(hAx)

%% Plot the runtimes
figure('Color', 'white')

cMap = lines(3);

hold on
plot(nFrames(1:n)*dOp_per_frame/1e9,das_mex_gpu_time(1:n),'s-','linewidth',1.5,'color',cMap(1,:));
% plot(nFrames(1:n)*dOp_per_frame/1e9,das_mex_time(1:n),'o-','linewidth',1.5,'color',cMap(2,:));
plot(nFrames(1:n)*dOp_per_frame/1e9,das_mexFast_time(1:n),'o-','linewidth',1.5,'color',cMap(3,:));
hold off

for nn=1:length(nFrames)
    text(nFrames(nn)*dOp_per_frame/1e9,das_mex_gpu_time(nn),sprintf('%0.2f s', das_mex_gpu_time(nn)), ...
        'horizontalalignment', 'left', 'verticalalignment', 'top','color',cMap(1,:),'fontweight','bold');
    %     text(nFrames(nn)*dOp_per_frame/1e9,das_mex_time(nn),sprintf('%0.2f s', das_mex_time(nn)), ...
    %         'horizontalalignment', 'right', 'verticalalignment', 'bottom','color',cMap(2,:),'fontweight','bold');
    text(nFrames(nn)*dOp_per_frame/1e9,das_mexFast_time(nn),sprintf('%0.2f s', das_mexFast_time(nn)), ...
        'horizontalalignment', 'right', 'verticalalignment', 'bottom','color',cMap(3,:),'fontweight','bold');
end

grid on
box on

legend('MEX CUDA', 'MEX FAST', 'Location','Best');
xlabel('Delay operations [Billions]');
ylabel('Elapsed time [s]');




