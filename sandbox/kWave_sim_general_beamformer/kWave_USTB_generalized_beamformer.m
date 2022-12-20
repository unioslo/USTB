% 2D simulation of linear array
%
% authors:  Anders E. Vrålstad 
%
% Based on code by Bradley Treeby k-Wave Toolbox (http://www.k-wave.org) 
% Copyright (C) 2009-2017 Bradley Treeby
%
% Last updated: 18.03.2022

clear all;
close all;

%% Basic definitions
%
% We define some constants to be used on the script

f0 = 2e6;       % pulse center frequency [Hz]
cycles=2;       % number of cycles in pulse
c = 1540;      % medium speed of sound [m/s]
rho_m = 1020;    % medium density [kg/m3]
N_tx=1;            % number of waves in sequence
focus_pnt_r = 40e-3; % focus depth
alpha_max=deg2rad(20);          % maximum angle span [rad]

%% uff.probe
%
% We define the ultrasound probe as a USTB structure.

prb=uff.linear_array();
prb.N=64;                  % number of elements
prb.pitch=4e-4;           % probe pitch in azimuth [m]
prb.element_width=4e-4;   % element width [m]
prb.element_height=4e-3; % element height [m]
fig_handle = prb.plot([],'Linear array');

%% Computational grid
%
% We can define the computational grid as a uff.linear_scan strcuture. We
% set different resolution options depending on frequency reference speed
% of sound.

% mesh resolution, choose one
mesh_resolution='element4'; 
switch mesh_resolution
    case 'element2' % around 50 sec per wave
        dx=prb.pitch/2;                                         % 2 elements per pitch 
    case 'element4' % around 6min sec per wave
        dx=prb.pitch/4;                                         % 2 elements per pitch 
    case 'element8'
        dx=prb.pitch/8;                                         % 2 elements per pitch 
    otherwise
        error('Not a valid option');
end

% mesh size
PML_size = 20;                                          % size of the PML in grid points
Nx=round(focus_pnt_r*2/dx); Nx=Nx+mod(Nx,2);
Nz=round(focus_pnt_r*2/dx); Nz=Nz+mod(Nz,2);
grid_width=Nx*dx;
grid_depth=Nz*dx;
domain=uff.linear_scan('x_axis', linspace(-grid_width/2,grid_width/2,Nx).', 'z_axis', linspace(0,grid_depth,Nz).');

kgrid = kWaveGrid(domain.N_z_axis, domain.z_step, domain.N_x_axis, domain.x_step);


%% Propagation medium
% We define the medium based by setting the sound speed and density in
% every pixel of the uff.scan. Here we set an hyperechoic cyst at the
% center of the domain.

rho_m_std = 0.03;
medium.sound_speed = c*ones(domain.N_z_axis, domain.N_x_axis);
medium.density =  random('normal',rho_m,rho_m*rho_m_std,domain.N_z_axis, domain.N_x_axis);

if 1
% Point Scatter 1
cx=0; cz=30e-3; cr = 0.2e-3;
cn=sqrt((domain.x-cx).^2+(domain.z-cz).^2)<cr;
medium.sound_speed(cn) = 1540;       % sound speed [m/s]
medium.density(cn) = 5e3;           % density [kg/m3]

cx=-5e-3; cz=30e-3; cr = 0.2e-3;
cn=sqrt((domain.x-cx).^2+(domain.z-cz).^2)<cr;
medium.sound_speed(cn) = 1540;       % sound speed [m/s]
medium.density(cn) = 5e3;           % density [kg/m3]

cx=5e-3; cz=30e-3; cr = 0.2e-3;
cn=sqrt((domain.x-cx).^2+(domain.z-cz).^2)<cr;
medium.sound_speed(cn) = 1540;       % sound speed [m/s]
medium.density(cn) = 5e3;           % density [kg/m3]

% include hyperechoic cyst
cyst_std = 10/100;
cx=0; cz=20e-3; cr = 5e-3;
cn=sqrt((domain.x-cx).^2+(domain.z-cz).^2)<cr;
medium.sound_speed(cn) = random('normal',1540,1540*cyst_std,size(medium.sound_speed(cn)));       % sound speed [m/s]
medium.density(cn) = random('normal',rho_m,rho_m*cyst_std,size(medium.density(cn)));               % density [kg/m3]

% gradient bar
gradient_std = 3/100;
cn=(abs(domain.z-45e-3)<5e-3)&(abs(domain.x)<15e-3);
grad_c0 = random('normal',0,10/100,size(medium.sound_speed(cn)));       % sound speed [m/s]
grad_rho = random('normal',0,10/100,size(medium.density(cn)));               % density [kg/m3]

medium.sound_speed(cn)=1540 + 1540*grad_c0.*10.^(-60*(domain.x(cn)+15e-3)/30e-3/20);
medium.density(cn)=1020 + 1020*grad_rho.*10.^(-60*(domain.x(cn)+15e-3)/30e-3/20);
% 
% include hyperechoic cyst
cyst_std = 0.001/100;
cx=0; cz=60e-3; cr = 5e-3;
cn=sqrt((domain.x-cx).^2+(domain.z-cz).^2)<cr;
medium.sound_speed(cn) = random('normal',1540,1540*cyst_std,size(medium.sound_speed(cn)));       % sound speed [m/s]
medium.density(cn) = random('normal',rho_m,rho_m*cyst_std,size(medium.density(cn)));               % density [kg/m3]
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
% We define the time vector depending on the CFL number, the size of the
% domain and the mean speed of sound.

cfl=0.3;
t_end=2*sqrt(grid_depth.^2+grid_depth.^2)/mean(medium.sound_speed(:));
kgrid.makeTime(medium.sound_speed,cfl,t_end);


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
clear n;

% Update uff probe with correct set element positions
for m = 1:prb.N_elements
    prb_x(m) = mean(domain.x(source_pixels{m}));
    prb_y(m) = mean(domain.y(source_pixels{m}));
    prb_z(m) = mean(domain.z(source_pixels{m}));
    element_width(m) = peak2peak(domain.x(source_pixels{m}));
    element_height(m) = peak2peak(domain.y(source_pixels{m}));
end
prb.geometry = [prb_x',prb_y',prb_z', zeros(prb.N_elements,1), zeros(prb.N_elements,1), element_width', element_height'];


% sensor mask
sensor.mask = zeros(domain.N_z_axis, domain.N_x_axis);
for m=1:prb.N_elements
    sensor.mask(source_pixels{m}) = sensor.mask(source_pixels{m}) + 1;
end

% source mask
source.u_mask=sensor.mask;

figure;
h=pcolor(domain.x_axis,domain.z_axis,source.u_mask); %axis equal tight;
title('Source/Sensor mask')
set(h,'edgecolor','none');
set(gca,'YDir','reverse');
xlabel('x [mm]');
ylabel('z [mm]');

%% Define Transmit Sequence
if N_tx>1
    angles=linspace(-alpha_max,alpha_max,N_tx);    % angle vector [rad]
else
    angles = 0;
end

seq=uff.wave();
for n=1:N_tx
    seq(n)=uff.wave();
    seq(n).source.azimuth=angles(n);
    seq(n).source.distance = -25/1000%inf;%focus_pnt_r;;%focus_pnt_r;%inf%5e-3%;
    seq(n).probe=prb;
    seq(n).sound_speed=c;    % reference speed of sound [m/s]
    seq(n).delay = min(seq(n).delay_values);
    seq(n).source.plot(fig_handle);
end
%% Calculation
%
% We are ready to launch the k-Wave calculation
sensor_data = gpuArray(zeros(length(kgrid.t_array),256))
disp('Launching kWave. This can take a while.');
for n=1:N_tx
    delay=seq(n).delay_values-seq(n).delay;
    delay=round(delay/kgrid.dt);
    seq(n).delay = seq(n).delay - cycles/f0/2;
    
    % offsets
    tone_burst_offset = [];
    for m=1:prb.N_elements
        tone_burst_offset = [tone_burst_offset repmat(delay(m),1,numel(source_pixels{m}))];
    end
    current_source = source;
    current_source.ux = toneBurst(1/kgrid.dt, f0, cycles, 'SignalOffset', tone_burst_offset); % create the tone burst signals
    current_source.uy = 0.*current_source.ux;
    current_source.u_mode ='dirichlet';
    
    % set the input arguements: force the PML to be outside the computational
    % grid; switch off p0 smoothing within kspaceFirstOrder2D
    input_args = {'PMLInside', false, 'PMLSize', PML_size, 'PlotPML', false, 'Smooth', false,'PlotScale',[-1.2,1.2]*1e6, 'RecordMovie', false,'LogScale',1e5,'DataCast','gpuArray-single'};
    
    current_sensor = sensor;
%     current_sensor.directivity_angle = current_sensor.mask.*seq(n).source.azimuth;

    % run the simulation
    sensor_data(:,:,n) = permute(kspaceFirstOrder2D(kgrid, medium, current_source, current_sensor, input_args{:}),[2 1]);
end
sensor_data(isnan(sensor_data))=0;

%% Calculation
% %
% % We are ready to launch the k-Wave calculation
% disp('Launching kWave. This can take a while.');
% for n=1:N_tx
%     delay=seq(n).delay_values-seq(n).delay;
%     denay=round(delay/kgrid.dt);
%     seq(n).delay = seq(n).delay - cycles/f0/2;
%     
%     % offsets
%     tone_burst_offset = [];
%     for m=1:prb.N_elements
%         tone_burst_offset = [tone_burst_offset repmat(denay(m),1,numel(source_pixels{m}))];
%     end
%     current_source = source;
%     current_source.ux = toneBurst(1/kgrid.dt, f0, cycles, 'SignalOffset', tone_burst_offset);   % create the tone burst signals
%     current_source.uy = 0.*current_source.ux;
%     current_source.u_mode ='dirichlet';
%     
%     % set the input arguements: force the PML to be outside the computational
%     % grid; switch off p0 smoothing within kspaceFirstOrder2D
%     input_args = {'PMLInside', false, 'PMLSize', PML_size, 'PlotPML', false, 'Smooth', true,'PlotScale',[-1.2,1.2]*1e6, 'RecordMovie', false,'LogScale',1e5,'DataCast','gpuArray-single'};
%     
%     current_sensor = sensor;
% %     current_sensor.directivity_angle = current_sensor.mask.*seq(n).source.azimuth;
% 
%     % run the simulation
%     sensor_data(:,:,n) = permute(kspaceFirstOrder2D(kgrid, medium, current_source, current_sensor, input_args{:}),[2 1]);
% end
% sensor_data(isnan(sensor_data))=0;

%% Gather element signals
%
% After calculaton we combine the signal recorded by the sensors according to the
% corresponding element
element_data=zeros(numel(kgrid.t_array),prb.N_elements,numel(seq));
for m=1:prb.N_elements
    if  ~isempty(element_sensor_index{m})
        temp = gather(sensor_data(:,element_sensor_index{m},:));
        element_data(:,m,:)=bsxfun(@times,sqrt(1./kgrid.t_array).',trapz(kgrid.y(source_pixels{m}),temp,2));
    end
end

%% Band-pass filter
%
% We remove some numerical noise by band-pass filtering
filtered_element_data=tools.band_pass(element_data,1/kgrid.dt,[0 1e6 8e6 10e6]);

%% Define pulse
pulse = uff.pulse('center_frequency',f0);
%% Channel_data
%
% We can now store the simulated data into a uff.channel_data class
channel_data = uff.channel_data();
channel_data.probe = prb;
channel_data.pulse = pulse;
channel_data.sequence = seq;
channel_data.initial_time = 0;
channel_data.sampling_frequency = 1/kgrid.dt;
channel_data.sound_speed = c;
channel_data.data = filtered_element_data;

% taking care of NaNs
channel_data.data(isnan(channel_data.data))=0;

%% Demodulating channeldata
pre = preprocess.fast_demodulation();
pre.input = channel_data;
pre.modulation_frequency = f0;
channel_data_demod = pre.go();
channel_data = channel_data_demod;

%% Beamforming
scan = uff.linear_scan('x_axis',linspace(-40e-3,40e-3,512)','z_axis',linspace(5e-3,domain.z_axis(end),1024)');
mid=midprocess.das();
mid.code = code.mex;
mid.spherical_transmit_delay_model = spherical_transmit_delay_model.unified;
mid.channel_data=channel_data;
mid.dimension = dimension.both();
mid.scan=scan;
mid.transmit_apodization.window = uff.window.none;
mid.receive_apodization.window=uff.window.hamming;
mid.receive_apodization.f_number = .5;

% Delay the data
b_data = mid.go();
b_data.plot()