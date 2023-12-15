%% Computation of a CPWC dataset with Field II using a 2D array and beamforming with USTB
%
% authors:  Ole Marius Hoel Rindal <olemarius@olemarius.net>
%           Stefano Fiorentini <stefano.fiorentini@ntnu.no>
%
% Last updated: 05.12.2023

clear all
close all
clc

%% basic constants
c0=1540;        % Speed of sound [m/s]
fs=100e6;       % Sampling frequency [Hz]
dt=1/fs;        % Sampling step [s]
downfact = 4;   % channel data downsampling factor;

f0 = 2.7e6;               % Transducer center frequency [Hz]
bw = 0.9;                 % Transducer bandwidth [1]
lambda = c0/f0;           % Wavelength [m]
Nc = 1.5;                 % Number of cycles
scat_density = 0.1;

%% Create idealized Matrix Array
kerf = lambda/5;

probe = uff.matrix_array();
probe.pitch_x = lambda*0.8;
probe.pitch_y = lambda*0.8;
probe.element_width = probe.pitch_x-kerf;
probe.element_height = probe.pitch_y-kerf;
probe.N_x = 40;
probe.N_y = 32;

%% Transmit definition
f = 30e-2; % focus set at 30 centimeters

theta = linspace(-15, 15, 7) * pi / 180; % azimuth tx angles
phi = linspace(-15, 15, 7) * pi / 180;  % elevation tx angles

[PH, TH] = ndgrid(phi, theta);

[tx.z, tx.y, tx.x] = sph2cart(TH(:), PH(:), f*ones([numel(TH), 1]));
tx = [tx.x, tx.y, tx.z];

N_waves = numel(TH);
%% Pulse definition
timp = -2/f0 : 1/fs : 2/f0;
impulse_response = 1e9 * gauspuls(timp, f0, bw);

impulse_response = impulse_response - mean(impulse_response); % To remove DC component

texc = 0:1/fs:(Nc/f0-1/fs);
excitation = square(2*pi*f0*texc);
ir = conv(conv(impulse_response,excitation), impulse_response);
[maxVal, lag] = max(abs(hilbert(ir)));

% show the pulse to check that the lag estimation is on place (and that the pulse is symmetric)
figure()
hold on
plot((0:(length(ir)-1))/fs*1e6, ir, 'k')
plot((0:(length(ir)-1))/fs*1e6, abs(hilbert(ir)),'--r')
plot(lag/fs*1e6, maxVal,'g*')
hold off
box on
grid on
axis tight
xlabel('Fast time [\mus]')
ylabel('two Impulse response')
legend('RF','Envelope','Estimated lag');
title('2-way impulse response Field II');

%% Phantom
% === Define region filled with scatterers ===
zr = [4e-2, 8e-2];
xr = [-2e-2, 2e-2];
yr = [-2e-2, 2e-2];

% === estimate PSF size to calculate scatterer number
f_n = [3, 3];
xPSF = 1.2*f_n(1)*lambda;
yPSF = 1.2*f_n(2)*lambda;
zPSF = Nc*lambda/2;

% === Define geometry of nonechoic cyst ===
rc = 1e-2;      % Radius of cyst [m]
xc = 0;        % Position of cyst in x [m]
yc = 0;
zc = 6e-2;     % Position of cyst in z [m]

N_scatterers = round(scat_density * diff(zr)*diff(xr)*diff(yr) / (pi/6*xPSF*yPSF*zPSF))
positions = (rand([N_scatterers, 3]) .* ...
        [diff(xr), diff(yr), diff(zr)]) + [xr(1), yr(1), zr(1)];

%Find the indexes inside cyst
positions(sqrt(sum((positions - [xc, yc, zc]).^2, 2)) < rc, :) = [];
amplitudes = randn([size(positions, 1), 1]);

figure()
plot3(positions(:,1)*1e3,positions(:,2)*1e3,positions(:,3)*1e3,'b.')
hold on
axis equal
grid on
xlabel('x[mm]')
ylabel('y[mm]')
zlabel('z[mm]')

%% Compute STAI channel data
to = 2*zr(1)/c0 : 1/fs : 2*zr(2)/c0;

ch = zeros([length(to(1:downfact:end)), probe.N_elements, N_waves], 'single');   

% === Start Field II ===
field_init(0)
set_field('c',c0);              % Speed of sound [m/s]
set_field('fs',fs);             % Sampling frequency [Hz]
%set_field('threads', 12)
set_field('show_times', 0)

noSubAz = round(probe.element_width/(lambda/8));        % number of subelements in the azimuth direction
noSubEl = round(probe.element_height/(lambda/8));       % number of subelements in the elevation direction
enabled = ones(probe.N_x, probe.N_y);

% === Define transmit aperture ===
Th = xdc_2d_array(probe.N_x, probe.N_y, probe.element_width, probe.element_height, ...
                    kerf, kerf, enabled, noSubAz, noSubEl, [0, 0, 0]);

xdc_excitation (Th, excitation);
xdc_impulse(Th, impulse_response);
xdc_apodization(Th, 0, ones([1, probe.N_elements]));

% === Define receive aperture ===
Rh = xdc_2d_array(probe.N_x, probe.N_y, probe.element_width, probe.element_height, kerf, kerf, ...
                    enabled, noSubAz, noSubEl, [0, 0, 0]);
xdc_apodization(Rh, 0, ones([1, probe.N_elements]));
xdc_times_focus(Rh, 0, zeros([1, probe.N_elements]))

h = waitbar(0, 'Simulating channel data...');

try
    for n = 1:N_waves
        waitbar(n/N_waves, h, sprintf('Simulating channel data...Tx %d of %d', n, N_waves))

        % === Set transmit focus ===
        xdc_focus(Th, 0, tx(n,:))

        % Generate channel data
        [scat, start_time] = calc_scat_multi(Th, Rh, positions, amplitudes);

        ti = start_time + (0:length(scat)-1)/fs - lag/fs;

        % Interpolation
        tmp = interp1(ti, scat, to, 'linear', 0);

        % === Downsampling ===
        ch(:,:,n) = tmp(1:downfact:end,:);
    end
catch ME
    close(h)
    xdc_free(Th)
    xdc_free(Rh)
    field_end()

    rethrow(ME)
end
    
% === Close Field II ===
close(h)
xdc_free(Th)
xdc_free(Rh)
field_end()


%% Generate UFF wave sequence
for n = 1:N_waves
    seq(n) = uff.wave();
    seq(n).wavefront = uff.wavefront.spherical;
    seq(n).probe = probe;
    seq(n).source = uff.point();
    seq(n).source.xyz = tx(n,:);
    seq(n).sound_speed=c0;
end

probe.plot();

hold on
for n = 1:N_waves
    quiver3(seq(n).origin.x, seq(n).origin.y, seq(n).origin.z, ...
            seq(n).source.x, seq(n).source.y, seq(n).source.z, 1e-2, 'filled');
end

%% Channel data object
ch_rf = uff.channel_data();
ch_rf.sampling_frequency = fs/downfact;
ch_rf.modulation_frequency = f0;
ch_rf.sound_speed = c0;
ch_rf.initial_time = to(1);
ch_rf.probe = probe;
ch_rf.sequence = seq;
ch_rf.data = ch;

%% Demodulation
demod = preprocess.fast_demodulation();      
demod.input = ch_rf;
demod.plot_on = true;
demod.downsample_frequency = 5e6;
demod.lowpass_frequency_vector = [0.45, 0.9];

ch_iq = demod.go();

%% Create Sector scan
xzScan = uff.sector_scan();
xzScan.azimuth_axis = linspace(-15, 15,100)*pi/180;
xzScan.elevation_axis = 0;
xzScan.depth_axis = 4e-2 : c0/2/ch_iq.sampling_frequency : 8e-2;

yzScan = uff.sector_scan();
yzScan.azimuth_axis = 0;
yzScan.elevation_axis = linspace(-15,15,100)*pi/180;
yzScan.depth_axis = 4e-2 : c0/2/ch_iq.sampling_frequency : 8e-2;

xyScan = uff.sector_scan();
xyScan.azimuth_axis = linspace(-15, 15, 100)*pi/180;
xyScan.elevation_axis = linspace(-15, 15, 100)*pi/180;
xyScan.depth_axis = 6e-2;

%% Define beamforming object
mid = midprocess.das();
mid.channel_data = ch_iq;
mid.dimension = dimension.both();
mid.scan = xzScan;
mid.spherical_transmit_delay_model = spherical_transmit_delay_model.spherical;
mid.receive_apodization.window = uff.window.hamming;
mid.receive_apodization.maximum_aperture = 1.5*[probe.N_x, probe.N_y] .* [probe.pitch_x, probe.pitch_y];
mid.receive_apodization.f_number = 3.5;
mid.transmit_apodization.window = uff.window.hamming;
mid.transmit_apodization.maximum_aperture = ([probe.N_x, probe.N_y] .* [probe.pitch_x, probe.pitch_y]);
mid.transmit_apodization.f_number = 30e-2 ./ mid.transmit_apodization.maximum_aperture;

bf_iq_xz = mid.go();

mid.scan = yzScan;
bf_iq_yz = mid.go();

mid.scan = xyScan;
bf_iq_xy = mid.go();

%% Plot

% === Plot engine does not work for 3-D data for now. Need to plot
% beamformed data manually ===
Xxz = reshape(xzScan.x, [xzScan.N_depth_axis, xzScan.N_azimuth_axis]);
Yxz = reshape(xzScan.y, [xzScan.N_depth_axis, xzScan.N_azimuth_axis]);
Zxz = reshape(xzScan.z, [xzScan.N_depth_axis, xzScan.N_azimuth_axis]);

Xyz = reshape(yzScan.x, [yzScan.N_depth_axis, yzScan.N_elevation_axis]);
Yyz = reshape(yzScan.y, [yzScan.N_depth_axis, yzScan.N_elevation_axis]);
Zyz = reshape(yzScan.z, [yzScan.N_depth_axis, yzScan.N_elevation_axis]);

Xxy = reshape(xyScan.x, [xyScan.N_azimuth_axis, xyScan.N_elevation_axis]);
Yxy = reshape(xyScan.y, [xyScan.N_azimuth_axis, xyScan.N_elevation_axis]);
Zxy = reshape(xyScan.z, [xyScan.N_azimuth_axis, xyScan.N_elevation_axis]);

% === Generate reference geometry ===
[Xc, Yc, Zc] = sphere(25);

figure()
colormap(gray(256))
hold on
surface(Xxz*1e2, Yxz*1e2, Zxz*1e2, reshape(20*log10(abs(bf_iq_xz.data).' / max(abs(bf_iq_xz.data), [], 'all')), ...
    [xzScan.N_depth_axis, xzScan.N_azimuth_axis]), 'LineStyle', 'none')
surface(Xyz*1e2, Yyz*1e2, Zyz*1e2, reshape(20*log10(abs(bf_iq_yz.data).' / max(abs(bf_iq_yz.data), [], 'all')), ...
    [yzScan.N_depth_axis, yzScan.N_elevation_axis]), 'LineStyle', 'none')
surface(Xxy*1e2, Yxy*1e2, Zxy*1e2, reshape(20*log10(abs(bf_iq_xy.data).' / max(abs(bf_iq_xy.data), [], 'all')), ...
    [xyScan.N_azimuth_axis, xyScan.N_elevation_axis]), 'LineStyle', 'none')
surface((Xc*rc + xc)*1e2, (Yc*rc + yc)*1e2, (Zc*rc + zc)*1e2, 'LineStyle', 'none', ...
    'FaceColor', [0.85, 0.33, 0.1], 'FaceAlpha', 0.25)
hold off
grid on
box on
axis equal tight
xlabel('x [cm]')
ylabel('y [cm]')
zlabel('z [cm]')
view(3)
set(gca, 'ZDir', 'reverse')
clim([-40, 0])
ylabel(colorbar(), '[dB]')


%% Show Transmit apodization
mid.transmit_apodization.plot();
mid.receive_apodization.plot()