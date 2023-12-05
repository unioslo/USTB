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
scat_density = 5;

%% Create idealized Matrix Array
kerf = lambda/5;

probe = uff.matrix_array();
probe.pitch_x = lambda/2;
probe.pitch_y = lambda/2;
probe.element_width = probe.pitch_x-kerf;
probe.element_height = probe.pitch_y-kerf;
probe.N_x = 40;
probe.N_y = 32;
probe.plot();

%% Transmit definition
f = 1e3; % focus set at 1000 meters

theta = linspace(-15, 15, 9) * pi / 180; % azimuth tx angles
phi = 0; %linspace(-10, 10, 5) * pi / 180;  % elevation tx angles

[TH, PH] = ndgrid(theta, phi);

[tx.z, tx.x, tx.y] = sph2cart(TH(:), PH(:), f*ones([numel(TH), 1]));
tx = [tx.x, tx.y, tx.z];

N_waves = numel(TH);
%% Pulse definition
ti = -2/f0 : 1/fs : 2/f0;
impulse_response = 1e9 * gauspuls(ti, f0, bw);

te = 0:1/fs:(Nc/f0-1/fs);
excitation = square(2*pi*f0*te);
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
yr = [-0.2e-2, 0.2e-2];

% === estimate PSF size to calculate scatterer number
f_n = [3, 3];
xPSF = 1.2*f_n(1)*lambda;
yPSF = 1.2*f_n(2)*lambda;
zPSF = Nc*lambda/2;

% === Define geometry of nonechoic cyst ===
r = 1e-2;      % Radius of cyst [m]
xc = 0;        % Position of cyst in x [m]
yc = 0;
zc = 6e-2;     % Position of cyst in z [m]

N_scatterers = round(scat_density * diff(zr)*diff(xr)*diff(yr) / (pi/6*xPSF*yPSF*zPSF));
positions = (rand([N_scatterers, 3]) .* ...
        [diff(xr), diff(yr), diff(zr)]) + [xr(1), yr(1), zr(1)];

%Find the indexes inside cyst
positions(sqrt(sum((positions - [xc, yc, zc]).^2, 2)) < r, :) = [];
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
set_field('threads', 12)
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

%% Channel data object
channel_data = uff.channel_data();
channel_data.sampling_frequency = fs/downfact;
channel_data.modulation_frequency = f0;
channel_data.sound_speed = c0;
channel_data.initial_time = to(1);
channel_data.probe = probe;
channel_data.sequence = seq;
channel_data.data = ch;

%% Demodulation
demod = preprocess.fast_demodulation();      
demod.input = channel_data;
demod.plot_on = true;
demod.downsample_frequency = 5e6;
demod.lowpass_frequency_vector = [0.3, 0.85];

channel_data_iq = demod.go();

%% Create Sector scan
azScan = uff.sector_scan();
azScan.azimuth_axis = linspace(-15, 15,100)*pi/180;
azScan.elevation_axis = 0;
azScan.depth_axis = 4e-2 : c0/2/fs*downfact : 8e-2;

elScan = uff.sector_scan();
elScan.azimuth_axis = 0;
elScan.elevation_axis = linspace(-15,15,100)*pi/180;
elScan.depth_axis = 3e-2 : c0/2/fs*downfact : 8e-2;

%% Define beamforming object
mid = midprocess.das();
mid.channel_data = channel_data_iq;
mid.dimension = dimension.both();
mid.scan = azScan;
mid.spherical_transmit_delay_model = spherical_transmit_delay_model.spherical;
mid.receive_apodization.window = uff.window.hamming;
mid.receive_apodization.f_number = 2.5;
mid.transmit_apodization.window = uff.window.tukey50;
mid.transmit_apodization.maximum_aperture = [probe.N_x, probe.N_y] .* [probe.pitch_x, probe.pitch_y];

azBfData = mid.go();

% mid.scan = elScan;
% elBfData = mid.go();

%% Plot
Xaz = reshape(azScan.x, [azScan.N_depth_axis, azScan.N_azimuth_axis]);
Yaz = reshape(azScan.y, [azScan.N_depth_axis, azScan.N_azimuth_axis]);
Zaz = reshape(azScan.z, [azScan.N_depth_axis, azScan.N_azimuth_axis]);

% Xel = reshape(elScan.x, [elScan.N_depth_axis, elScan.N_elevation_axis]);
% Yel = reshape(elScan.y, [elScan.N_depth_axis, elScan.N_elevation_axis]);
% Zel = reshape(elScan.z, [elScan.N_depth_axis, elScan.N_elevation_axis]);


figure()
colormap(gray(256))
hold on
surface(Xaz*1e2, Yaz*1e2, Zaz*1e2, reshape(20*log10(abs(azBfData.data) / max(abs(azBfData.data), [], 'all')), [azScan.N_depth_axis, azScan.N_azimuth_axis]), ...
    'LineStyle', 'none')
hold off
grid on
box on
axis equal tight
xlabel('x [cm]')
ylabel('y [cm]')
zlabel('z [cm]')
view(3)
set(gca, 'ZDir', 'reverse')
clim([-60, 0])
ylabel(colorbar(), '[dB]')


%% Show Transmit apodization
mid.transmit_apodization.plot();