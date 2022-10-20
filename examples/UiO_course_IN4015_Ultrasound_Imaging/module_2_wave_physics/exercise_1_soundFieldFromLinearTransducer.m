%
% Script used in Module 2, IN3015/4015, 
% Dept. of Informatics, University of Oslo, Norway
%
% Version 1.0: August 31, 2021.
%
% Version 1.1: September 3, 2021
%	       Made dx independent of frequency, i.e.
% 	       changed "dx=c/f0/3" to "dx=c/f0/3*(f0/2.5e6)"
%              OBS: Choose f0<2.5e6 to have proper sampling.
%
%


if exist('path_to_k_wave'), clear('path_to_k_wave'); end

% =========================================================================
% SPECIFYING VARIABLES 
% =========================================================================

%  Path to k-wave
%  If you don't have k-wave in your default path, uncomment 
%  the following line and point out the correct directory

path_to_k_wave = '~/repos/k-wave-toolbox/k-Wave/';


% Physical and probe quantities
c = 1500;               % Speed of sound [m/s]
f0 = 2.5e6;             % Center frequency, transmitted pulse [Hz]
num_elements = 31;      % Odd number(!!) [grid points]
angle = 0;              % Steering angle [deg]
rFocus = 10000e-3;      % Focal radius, transducer [m]
cycles = 20;            % No of cycles in pulse


% Defining grid
Nx = 256;           % number of grid points in the x (row) direction
Ny = Nx/2;            % number of grid points in the y (column) direction
% dx = c/f0/3;    	% grid point spacing in the x direction [m]
dx = c/f0/3*(f0/2.5e6);    % grid point spacing in the x direction [m]
dy = dx;            % grid point spacing in the y direction [m]
x_offset = 20;      % x-position of transducer center [grid points]

% =========================================================================
% PREPAIR WHAT'S NEEDED TO SIMULATE
% =========================================================================

PMLSize = 10; 

% Add path if needed. Check if 'kWaveGrid' (part of k-wave) exist.

if (exist('path_to_k_wave') & ~(exist('kWaveGrid')==2))
    addpath(path_to_k_wave);
end

% Add our lib-functions
l = k_wave_lib();

% =========================================================================
% SIMULATION
% =========================================================================

% Define grid, medium & source matrices
[kgrid, medium, source] = l.defineSimulation(c, f0, ...
    num_elements, angle, rFocus, cycles, Nx, Ny, dx, dy, x_offset);

% create a sensor mask covering the entire computational domain using the
% opposing corners of a rectangle
sensor.mask = [1, 1, Nx, Ny].';

% set the record mode capture the final wave-field and the statistics at
% each sensor point 
sensor.record = {'p_max', 'p_rms'};

% assign the input options
input_args = {'DisplayMask', source.p_mask, 'RecordMovie', true, ...
     'MovieName', 'example_focus', ...
    'PMLSize', PMLSize, 'PMLInside', true};
          
% run the simulation
sensor_data = kspaceFirstOrder2D(kgrid, medium, source, sensor, ...
    input_args{:});

% =========================================================================
% VISUALISATION
% =========================================================================
textForPlots.rFocus = rFocus;
textForPlots.cycles = cycles;
textForPlots.c = c;
textForPlots.f0 = f0;
textForPlots.D = num_elements*dx;
textForPlots.angle = angle;


l.plotResponse(sensor_data, source, kgrid, textForPlots, PMLSize);
