clear all;
close all;

field_init(0);

%% basic constants
c0=1540;      % Speed of sound [m/s]
rho0=1020;    % Density [kg/m3]
fs=100e6;     % Sampling frequency [Hz]
dt=1/fs;      % Sampling step [s] 
f0=5e6;       % Transducer center frequency [Hz]
lambda=c0/f0; % Wavelength [m]

%% probe geometry
height=4.0e-3;                  % Height of element [m]
width=270e-6;                   % Width of element [m]
kerf=30e-6;                     % Distance between transducer elements [m]
N_elements=64;                  % Number of elements
no_sub_x=8;                     % Number of sub-divisions in x-direction of elements.
no_sub_y=8;                     % Number of sub-divisions in y-direction of elements.
elevation_focus=20e-3;          % Elevation focus (lens)
focus=[0 0 elevation_focus];    % Initial electronic focus
fractional_bandwidth = 0.65;    % probe fractional bandwidth [1]

%% excitation pulse
pulse_duration          = 2.5; % pulse duration [cycles]

% Define the transducer
%Th = xdc_linear_array (N_elements, width, height, kerf, no_sub_x, no_sub_y, focus);
Th = xdc_focused_array (N_elements, width, height, kerf, elevation_focus, no_sub_x, no_sub_y, focus);

%% element electromechanical impulse response
t0 = (-1/fractional_bandwidth/f0): dt : (1/fractional_bandwidth/f0);
impulse_response = gauspuls(t0, f0, fractional_bandwidth);
xdc_impulse (Th, impulse_response);

%% excitation pulse
te = (-pulse_duration/2/f0): dt : (pulse_duration/2/f0);
excitation = square(2*pi*f0*te+pi/2);
xdc_excitation (Th, excitation);

%% scan area
scan_x = uff.linear_scan('x_axis',linspace(-20e-3,20e-3,128).','z_axis',linspace(0e-3,40e-3,256).');
scan_y = uff.linear_3D_scan('radial_axis',linspace(-20e-3,20e-3,128).','axial_axis',linspace(0e-3,40e-3,256).','roll',pi/2);

%% calculate the field 
[px, t] = calc_hp (Th,scan_x.xyz);
[py, t] = calc_hp (Th,scan_y.xyz);

%% pulse intensity integral [J/m^2]
pii_x=reshape(sum(px.^2,1)*dt/rho0/c0,[scan_x.N_z_axis scan_x.N_x_axis]);
pii_y=reshape(sum(py.^2,1)*dt/rho0/c0,[scan_y.N_axial_axis scan_y.N_radial_axis]);

%% depth normalized, dB, PII map
pii_x_dB=10*log10(bsxfun(@rdivide,pii_x, max(pii_x,[],2)));
pii_y_dB=10*log10(bsxfun(@rdivide,pii_y, max(pii_y,[],2)));

figure;
subplot(1,2,1);
imagesc(scan_x.x_axis*1e3,scan_x.z_axis*1e3,pii_x_dB); axis equal tight; colorbar
ylabel('z [mm]')
xlabel('x [mm]')
title('Lateral plane');
caxis([-60 0]);

subplot(1,2,2);
imagesc(scan_y.radial_axis*1e3,scan_y.axial_axis*1e3,pii_y_dB); axis equal tight; colorbar
ylabel('z [mm]')
xlabel('x [mm]')
title('Elevation plane')
caxis([-60 0]);

%% compute elevation FWHM
mask=find(scan_y.radial_axis>=0);
for n=1:scan_y.N_axial_axis
    el_6dB(n)=interp1(pii_y_dB(n,mask).',scan_y.radial_axis(mask),-6);
end

figure;
plot(scan_y.axial_axis*1e3,2*el_6dB*1e3,'k','linewidth',2); grid on; hold on;
xlabel('Depth [mm]');
ylabel('Scanplane thickness [mm]');
set(gca,'fontsize', 14);


