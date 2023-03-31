% A simple propagating wave example and one way beamforming
%
% based on the k-wave example 
% "Monopole Point Source In A Homogeneous Propagation Medium Example"
%
% This example provides a simple demonstration of using k-Wave for the
% simulation and detection of a time varying pressure source within a
% two-dimensional homogeneous propagation medium.  It builds on the
% Homogeneous Propagation Medium and Recording The Particle Velocity
% examples.
%
% orgiginal author: Bradley Treeby
% date: 2nd December 2009
%
% Modified by Ole Marius Hoel Rindal <olemarius@olemarius.net>
%   Using a "burst" instead of continous sinus as transmit signal
%   Using multiple receive sensors
%   One-way beamforming using the USTB.

function [channel_data, kgrid] = run_kwave_simulation(number_of_sensors,transmit_signal)
% create the computational grid
Nx = 128;           % number of grid points in the x (row) direction
Ny = 128;           % number of grid points in the y (column) direction
dx = 50e-3/Nx;    	% grid point spacing in the x direction [m]
dy = dx;            % grid point spacing in the y direction [m]
kgrid = kWaveGrid(Nx, dx, Ny, dy);

% define the properties of the propagation medium
medium.sound_speed = 1500;  % [m/s]
medium.alpha_coeff = 0.75;  % [dB/(MHz^y cm)]
medium.alpha_power = 1.5;

% create the time array
kgrid.makeTime(medium.sound_speed);

% define a single source point
source.p_mask = zeros(Nx, Ny);
source.p_mask(Nx/2, Ny/2) = 1;

% define a time varying sinusoidal source
source_freq = 0.5e6;0.25e6;   % [Hz]
source_mag = 5;         % [Pa]
switch transmit_signal
    case 'sinus'
        source.p = source_mag * sin(2 * pi * source_freq * kgrid.t_array);
    case 'gaussian_pulse'
        source.p = source_mag * gauspuls(kgrid.t_array-mean(kgrid.t_array),source_freq,1)
end


figure;plot(source.p);
% filter the source to remove high frequencies not supported by the grid
source.p = filterTimeSeries(kgrid, medium, source.p);

% define a single sensor point
sensor.mask = zeros(Nx, Ny);

%% or multiple sensor points
lambda = medium.sound_speed/source_freq;
sensor_spacing = round(lambda/2 / dx);

sensor.mask(Ny/32, Nx/2-(number_of_sensors/2)*sensor_spacing+sensor_spacing/2) = 1;
sensor_loc(1,:) = [kgrid.x_vec(Nx/2-(number_of_sensors/2)*sensor_spacing+sensor_spacing/2) kgrid.y_vec(Ny/32)];
for s = 1:number_of_sensors-1
    sensor.mask(Ny/32, Nx/2-(number_of_sensors/2)*sensor_spacing+sensor_spacing/2+sensor_spacing*s) = 1;
    sensor_loc(s+1,:) = [kgrid.x_vec(Nx/2-(number_of_sensors/2)*sensor_spacing+sensor_spacing/2+sensor_spacing*s) kgrid.y_vec(Ny/32) ];
end

%%
% define the acoustic parameters to record
sensor.record = {'p', 'p_final'};

% run the simulation
sensor_data = kspaceFirstOrder2D(kgrid, medium, source, sensor);

% =========================================================================
% VISUALISATION
% =========================================================================

% plot the final wave-field
figure;
imagesc(kgrid.y_vec * 1e3, kgrid.x_vec * 1e3, ...
    sensor_data.p_final + source.p_mask + sensor.mask, [-1, 1]);
colormap(getColorMap);
ylabel('x-position [mm]');
xlabel('y-position [mm]');
axis image;

%% plot the simulated sensor data
figure;
[t_sc, scale, prefix] = scaleSI(max(kgrid.t_array(:)));

subplot(size(sensor_data.p,1)+1, 1, 1);
plot(kgrid.t_array * scale, source.p, 'k-');
xlabel(['Time [' prefix 's]']);
ylabel('Signal Amplitude');
axis tight;
title('Input Pressure Signal');
                                                                                       

for s = 1:size(sensor_data.p,1)
    subplot(size(sensor_data.p,1)+1, 1, s + 1);
    plot(kgrid.t_array * scale, sensor_data.p(s,:), 'r-');
    xlabel(['Time [' prefix 's]']);
    ylabel('Signal Amplitude at sensor');
    axis tight;
    title(['Sensor Pressure Signal at sensor ',num2str(s)]);
end

%% 
% #     #  #####  ####### ######  
% #     # #     #    #    #     # 
% #     # #          #    #     # 
% #     #  #####     #    ######  
% #     #       #    #    #     # 
% #     # #     #    #    #     # 
%  #####   #####     #    ######  
%   
% processing below   

% Define the probe
probe = uff.linear_array();
probe.pitch = lambda/2;
probe.N = number_of_sensors;
probe.geometry(:,1) = sensor_loc(:,1);
probe.geometry(:,3) = 0;%sensor_loc(:,2);

% Define the transmit sequence
seq = uff.wave();
seq.probe = probe;
seq.wavefront = uff.wavefront.photoacoustic;
seq.sound_speed = medium.sound_speed;

% Create channel data object
channel_data = uff.channel_data();
channel_data.data = sensor_data.p';
channel_data.probe = probe;
channel_data.sequence = seq;
[~,lag] = max(source.p);
channel_data.sampling_frequency = 1./kgrid.dt;
channel_data.initial_time = -lag*kgrid.dt;

end
