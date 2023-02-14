%% CPWC simulation to compare speeds of the various USTB beamformers.
%
% In this example, we conduct a simple simulation to compare the speeds
% achieved with USTB:
%
% # MEX C beamformer
% # MEX CUDA beamformer
%
% Stefano Fiorentini <stefano.fiorentini@ntnu.no>
% Last edited: 01/02/2023

clear all
close all
clc

testCase = 1; % 0 = linear/planewave, 1 = sector/focused
do_demodulation = true;
nFrames = 60;

codeToBenchmark = [2, 4]; % check enumeration("code") to see which ones

[cid, cnames] = enumeration("code");

cid = cid(codeToBenchmark); % skip normal matlab-based scripts
cnames = cnames(codeToBenchmark);

%% Phantom
switch testCase
    case 0
        x_sca=[zeros(1,7), -15e-3:5e-3:15e-3];
        z_sca=[5e-3:5e-3:35e-3, 20e-3*ones(1,7)];
    case 1
        x_sca=[zeros(1,7), -45e-3:15e-3:45e-3];
        z_sca=[10e-3:15e-3:100e-3, 65e-3*ones(1,7)];
end

N_sca=length(x_sca);
pha=uff.phantom();
pha.sound_speed=1540;            % speed of sound [m/s]
pha.points=[x_sca.', zeros([N_sca,1]), z_sca.', ones([N_sca,1])];    % point scatterer position [m]

%% Probe
switch testCase
    case 0
        prb=uff.linear_array();
        prb.N=128;                  % number of elements
        prb.pitch=300e-6;           % probe pitch in azimuth [m]
        prb.element_width=270e-6;   % element width [m]
        prb.element_height=5e-3;    % element height [m]
    case 1
        prb=uff.linear_array();
        prb.N=90;                   % number of elements
        prb.pitch=220e-6;           % probe pitch in azimuth [m]
        prb.element_width=200e-6;   % element width [m]
        prb.element_height=8e-3;    % element height [m]

end

%% Pulse

switch testCase

    case 0
        pul=uff.pulse();
        pul.center_frequency=7e6;       % transducer frequency [MHz]
        pul.fractional_bandwidth=0.8;   % fractional bandwidth [unitless]

    case 1
        pul=uff.pulse();
        pul.center_frequency=4e6;       % transducer frequency [MHz]
        pul.fractional_bandwidth=0.8;   % fractional bandwidth [unitless]
end
%% Sequence generation

switch testCase
    case 0
        nTx=15;
        angles=linspace(-10, 10, nTx)/180*pi;
        seq=uff.wave();

        for n=1:nTx
            seq(n)=uff.wave();
            seq(n).probe=prb;
            seq(n).source.azimuth=angles(n);
            seq(n).wavefront = uff.wavefront.plane;
            seq(n).sound_speed=pha.sound_speed;
        end
    case 1
        nTx=81; % n transmits
        F = 6.5e-2; % focus speed
        angles=linspace(-35, 35, nTx)/180*pi;
        seq=uff.wave();

        for n=1:nTx
            seq(n)=uff.wave();
            seq(n).probe=prb;
            seq(n).source.azimuth=angles(n);
            seq(n).source.distance = F;
            seq(n).wavefront = uff.wavefront.spherical;
            seq(n).sound_speed=pha.sound_speed;
        end

    otherwise
        error("Case not supported")
end

%% Fresnel simulator
sim=fresnel();
sim.phantom=pha;                % phantom
sim.pulse=pul;                  % transmitted pulse
sim.probe=prb;                  % probe
sim.sequence=seq;               % beam sequence
sim.sampling_frequency=50e6;    % sampling frequency [Hz]

tic()
channel_data=sim.go();
toc()

if do_demodulation
    demod = preprocess.fast_demodulation();
    demod.input = channel_data;
    demod.modulation_frequency = pul.center_frequency;
    demod.downsample_frequency = 2*pul.center_frequency;

    channel_data = demod.go();
end

%% Scan
switch testCase
    case 0
        scan = uff.linear_scan('x_axis',linspace(-2e-2,2e-2,256).', 'z_axis', linspace(0, 4e-2, 512).');
    case 1
        scan = uff.sector_scan('azimuth_axis',linspace(angles(1),angles(end),256).', 'depth_axis', linspace(0, 12e-2, 768).');
end

%% Pipeline

bmf=midprocess.das();
bmf.channel_data=channel_data;
bmf.scan=scan;

switch testCase
    case 0
        bmf.receive_apodization.window=uff.window.hamming;
        bmf.receive_apodization.f_number=2;

        bmf.transmit_apodization.window=uff.window.hamming;
        bmf.transmit_apodization.f_number=2;
    case 1
        bmf.receive_apodization.window=uff.window.none;
        bmf.receive_apodization.f_number=3.5;
        bmf.receive_apodization.maximum_aperture = 2e-2 * bmf.receive_apodization.f_number(1)^2;

        bmf.transmit_apodization.window=uff.window.hamming;
        bmf.transmit_apodization.f_number=3.5;
        bmf.transmit_apodization.minimum_aperture = 4e-3 * bmf.transmit_apodization.f_number(1)^2;
end

bmf.code = code.mex();
fprintf(1, 'Precalculating apodization\n')
bmf.go();

% Clear data
bmf.beamformed_data = [];
%% Test beamforming speed

dOp_per_frame = 2*scan.N_pixels*channel_data.N_channels*channel_data.N_waves;

for c = 1:length(cid)
    das_time.(cnames{c}) = zeros([length(nFrames), 1]);
end


if isscalar(nFrames)
    profile on
end

for n=1:length(nFrames)

    % Replicate frames
    channel_data.data=repmat(channel_data.data(:,:,:,1),[1, 1, 1, nFrames(n)]);
    fprintf(1, 'Processing %d frames\n', nFrames(n))

    for c = 1:length(cid)
        bmf.code       = cid(c);
        bmf.gpu_id = 0;

        bf_data.(cnames{c}) = bmf.go();
        das_time.(cnames{c})(n) = bmf.elapsed_time;
    end
end

if isscalar(nFrames)
    profile off
    profile viewer
end

%% Plot the images for visual inspection of the results
switch class(scan)
    case "uff.linear_scan"
        dim = [scan.N_z_axis, scan.N_x_axis];

    case "uff.sector_scan"
        dim = [scan.N_depth_axis, scan.N_azimuth_axis];

end

X = reshape(scan.x, dim);
Y = reshape(scan.y, dim);
Z = reshape(scan.z, dim);


figure('Color', 'white')
tiledlayout("flow", "TileSpacing", "compact", "Padding", "compact")

for c = 1:length(cid)

    hAx(c) = nexttile();
    surface(X*1e2, Y*1e2, Z*1e2, ...
        20*log10(abs(reshape(bf_data.(cnames{c}).data(:,end), dim)) / ...
        max(abs(bf_data.(cnames{c}).data(:,end)))), "LineStyle", "none")
    clim([-60, 0])
    view([0, 0])
    set(gca, "ZDir", "reverse", "Layer", "top")
    grid on
    box on
    axis equal tight
    xlabel("x [cm]")
    ylabel("z [cm]")
    title(upper(strjoin(strsplit(cnames{c}, "_"))))
    ylabel(colorbar, "dB")

end

linkaxes(hAx)
linkprop(hAx, {'CameraPosition','CameraUpVector'});


%% Plot the runtimes
figure('Color', 'white')

cMap = lines(length(cid));

hold on
for c = 1:length(cid)
    plot(nFrames*dOp_per_frame/1e9,das_time.(cnames{c}),'s-','linewidth',1.5,'color',cMap(c,:), 'DisplayName', upper(strjoin(strsplit(cnames{c}, "_"))));
end
hold off

for n=1:length(nFrames)
    for c = 1:length(cid)

        text(nFrames(n)*dOp_per_frame/1e9,das_time.(cnames{c})(n),sprintf('%0.2f s', das_time.(cnames{c})(n)), ...
            'horizontalalignment', 'left', 'verticalalignment', 'top','color',cMap(c,:),'fontweight','bold');

    end
end

grid on
box on

legend('Location','Best');
xlabel('Delay operations [1e9]');
ylabel('Elapsed time [s]');



