% 2D simulation of linear array
%
% This example demonstrates the use of k-Wave simulation of ultrasounic 
% beams in a 2D domain and how it can interact with USTB structures.
%
% authors:  Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>
%
% Based on code by Bradley Treeby k-Wave Toolbox (http://www.k-wave.org) 
% Copyright (C) 2009-2017 Bradley Treeby
%
% Last updated: 30.10.2018

clear all;
close all;

%% Basic definitions
%
% We define some constants to be used on the script

f0 = 2e6;       % pulse center frequency [Hz]
cycles=2;       % number of cycles in pulse
c0 = 1540;      % medium speed of sound [m/s]
rho0 = 1020;    % medium density [kg/m3]
F_number = 1.7; % F number for CPWC sequence (i.e. maximum angle)
N=1;            % number of plane waves in CPWC sequence

%% uff.probe
%
% We define the ultrasound probe as a USTB structure.

prb=uff.linear_array();
prb.N=128;                  % number of elements
prb.pitch=300e-6;           % probe pitch in azimuth [m]
prb.element_width=300e-6;   % element width [m]
prb.element_height=5000e-6; % element height [m]
fig_handle = prb.plot([],'Linear array');

%% Computational grid
%
% We can define the computational grid as a uff.linear_scan strcuture. We
% set different resolution options depending on frequency reference speed
% of sound.

f_max = 1.2*f0;
lambda_min = c0/f_max;

% mesh resolution, choose one
mesh_resolution='element2'; 
switch mesh_resolution
    case 'element2' % around 50 sec per wave
        dx=prb.pitch/2;                                         % 2 elements per pitch 
    case 'element4' % around 6min sec per wave
        dx=prb.pitch/4;                                         % 2 elements per pitch 
    otherwise
        error('Not a valid option');
end

% mesh size
PML_size = 20;                                          % size of the PML in grid points
Nx=round(40e-3/dx); Nx=Nx+mod(Nx,2);
Nz=round(40e-3/dx); Nz=Nz+mod(Nz,2);
grid_width=Nx*dx;
grid_depth=Nz*dx;
domain=uff.linear_scan('x_axis', linspace(-grid_width/2,grid_width/2,Nx).', 'z_axis', linspace(0,grid_depth,Nz).');

kgrid = kWaveGrid(domain.N_z_axis, domain.z_step, domain.N_x_axis, domain.x_step);

%% Propagation medium
%
% We define the medium based by setting the sound speed and density in
% every pixel of the uff.scan. Here we set an hyperechoic cyst at the
% center of the domain.

% transparent background
medium.sound_speed = c0*ones(domain.N_z_axis, domain.N_x_axis);   % sound speed [m/s]
medium.density = rho0.*ones(domain.N_z_axis, domain.N_x_axis);      % density [kg/m3]

% include fat layer
fat_std = 3/100;
cn=abs(domain.z-(10e-3 + 0.025e-3*sin(2*pi*domain.x/5e-3)))<0.5e-3;
medium.sound_speed(cn) = random('normal',1450,1450*fat_std,size(medium.sound_speed(cn)));       % sound speed [m/s]
medium.density(cn) = random('normal',950,950*fat_std,size(medium.density(cn)));               % density [kg/m3]

% include cyst
cyst_std = 3/100;
cx=0; cz=20e-3; cr = 5e-3;
cn=sqrt((domain.x-cx).^2+(domain.z-cz).^2)<cr;
medium.sound_speed(cn) = random('normal',1540,1540*cyst_std,size(medium.sound_speed(cn)));       % sound speed [m/s]
medium.density(cn) = random('normal',1020,1020*cyst_std,size(medium.density(cn)));               % density [kg/m3]

% include point
if true
    cx=0; cz=20e-3; cr = 0.06125e-3;
    cn=sqrt((domain.x-cx).^2+(domain.z-cz).^2)<cr;
    medium.sound_speed(cn) = 1450;       % sound speed [m/s]
    medium.density(cn) = 1020;           % density [kg/m3]
end

% attenuation
medium.alpha_coeff = 0.3;  % [dB/(MHz^y cm)]
medium.alpha_power = 1.5;

% show physical map: speed of sound and density
figure;
subplot(1,2,1);
imagesc(domain.x_axis*1e3,domain.z_axis*1e3,medium.sound_speed); colormap gray; colorbar; axis equal tight;
xlabel('x [mm]');
ylabel('z [mm]');
title('c_0 [m/s]');
subplot(1,2,2);
imagesc(domain.x_axis*1e3,domain.z_axis*1e3,medium.density); colormap gray; colorbar; axis equal tight;
xlabel('x [mm]');
ylabel('z [mm]');
title('\rho [kg/m^3]');

%% Time vector
%
% We define the time vector depending on the CFL number, the size of the
% domain and the mean speed of sound.

cfl=0.3;
t_end=2*sqrt(grid_depth.^2+grid_depth.^2)/mean(medium.sound_speed(:));
kgrid.makeTime(medium.sound_speed,cfl,t_end);

%% Sequence
%
% We define a sequence of plane-waves
alpha_max=1/2/F_number;                         % maximum angle span [rad]
if N>1
    angles=linspace(-alpha_max,alpha_max,N);    % angle vector [rad]
else
    angles = 0;
end
seq=uff.wave();
for n=1:N
    seq(n)=uff.wave();
    seq(n).apodization = uff.apodization('f_number',1,'window',uff.window.rectangular,'focus',uff.scan('xyz',[0 0 10e-3]));
    seq(n).source.azimuth=angles(n);
    seq(n).source.distance=-Inf;
    seq(n).probe=prb;
    seq(n).sound_speed=1540;    % reference speed of sound [m/s]
    seq(n).delay = min(seq(n).delay_values);
    seq(n).source.plot(fig_handle);
end

%% Source & sensor mask
%
% Based on the uff.probe we find the pixels in the domain that must work as
% source and sensors.

% find the grid-points that match the element
source_pixels={};
element_sensor_index = {};
n=1;
for m=1:prb.N_elements
    plot((prb.x(m)+[-prb.width(m)/2 prb.width(m)/2])*1e3,[0 0],'k+-'); hold on; grid on;
    source_pixels{m}=find(abs(domain.x-prb.x(m))<prb.width(m)/2 & abs(domain.y-prb.y(m))<prb.height(m) & abs(domain.z-prb.z(m))<=domain.z_step/2);
    element_sensor_index{m} = n:n+numel(source_pixels{m})-1;
    n=n+numel(source_pixels{m});
end

% sensor mask
sensor.mask = zeros(domain.N_z_axis, domain.N_x_axis);
for m=1:prb.N_elements
    sensor.mask(source_pixels{m}) = sensor.mask(source_pixels{m}) + 1;
end

% source mask
source.u_mask=sensor.mask;

figure;
h=pcolor(domain.x_axis,domain.z_axis,source.u_mask); axis equal tight;
title('Source/Sensor mask')
set(h,'edgecolor','none');
set(gca,'YDir','reverse');
xlabel('x [mm]');
ylabel('z [mm]');

%% Calculation
%
% We are ready to launch the k-Wave calculation

disp('Launching kWave. This can take a while.');
for n=1:N
    delay=seq(n).delay_values-seq(n).delay;
    denay=round(delay/kgrid.dt);
    seq(n).delay = seq(n).delay - cycles/f0/2;
    
    % offsets
    tone_burst_offset = [];
    for m=1:prb.N_elements
        tone_burst_offset = [tone_burst_offset repmat(denay(m),1,numel(source_pixels{m}))];
    end
    source.ux = toneBurst(1/kgrid.dt, f0, cycles, 'SignalOffset', tone_burst_offset);   % create the tone burst signals
    source.uy = 0.*source.ux;
    source.u_mode ='dirichlet';
    
    % set the input arguements: force the PML to be outside the computational
    % grid; switch off p0 smoothing within kspaceFirstOrder2D
    input_args = {'PMLInside', false, 'PMLSize', PML_size, 'PlotPML', false, 'Smooth', false};
    
    % run the simulation
    sensor_data(:,:,n) = permute(kspaceFirstOrder2D(kgrid, medium, source, sensor, input_args{:}),[2 1]);
end
sensor_data(isnan(sensor_data))=0;

%% Gather element signals
%
% After calculaton we combine the signal recorded by the sensors according to the
% corresponding element
element_data=zeros(numel(kgrid.t_array),prb.N_elements,numel(seq));
for m=1:prb.N_elements
    if  ~isempty(element_sensor_index{m})
        element_data(:,m,:)=bsxfun(@times,sqrt(1./kgrid.t_array).',trapz(kgrid.y(source_pixels{m}),sensor_data(:,element_sensor_index{m},:),2));
    end
end

%% Band-pass filter
%
% We remove some numerical noise by band-pass filtering
filtered_element_data=tools.band_pass(element_data,1/kgrid.dt,[0 1e6 8e6 10e6]);

%% Channel_data
%
% We can now store the simulated data into a uff.channel_data class
channel_data = uff.channel_data();
channel_data.probe = prb;
channel_data.sequence = seq;
channel_data.initial_time = 0;
channel_data.sampling_frequency = 1/kgrid.dt;
channel_data.data = filtered_element_data;

% taking care of NaNs
channel_data.data(isnan(channel_data.data))=0;

%% Beamforming
%
% To beamform we define a new (coarser) uff.linear_scan. We also define the
% processing pipeline and launch the beamformer

domain=uff.linear_scan('x_axis',linspace(domain.x_axis(1),domain.x_axis(end),512).',...
    'z_axis',linspace(domain.z_axis(1),domain.z_axis(end),512).');

pipe = pipeline();
pipe.channel_data = channel_data;
pipe.scan = domain;

pipe.receive_apodization.window = uff.window.hanning;
pipe.receive_apodization.f_number = F_number;

b=postprocess.coherent_compounding();
b.dimension = dimension.both;

das = pipe.go({midprocess.das b});
das.plot([],'DAS'); hold on;