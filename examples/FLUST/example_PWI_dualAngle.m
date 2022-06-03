% Updated 10/11/2020, Joergen Avdal (jorgen.avdal@ntnu.no)

% Anne Saris 31-05-2022, first example script for dual angle plane wave imaging
% Data will be beamformed at angled grids, to be used seperately in the
% velocity-estimator.

% If using FLUST for scientific publications, please cite the original paper
% Avdal et al: Fast Flow-Line-Based Analysis of Ultrasound Spectral and
% Vector Velocity Estimators, tUFFC, 2019.

% FLUST is a simulation tool based on flowlines, useful for producing many
% realizations of the same flowfield. The motivation for making FLUST was
% to faciliate accurate assessment of statistical properties of velocity
% estimators like bias and variance.

% Using FLUST requires the user to provide/select two functions, one to create
% the flowlines, and one to calculate the PSFs from a vector of spatial
% positions. 

% After running this script, variable realTab contains realizations, and
% variables PSFs and PSFstruct contains point spread functions of the last flow line.

% FLUST accounts for interframe motion in plane wave sequences, assuming
% uniform firing rate, but not in scanned sequences.

% How to use FLUST:
% 1) Provide/select function to calculate PSFs from a vector of spatial positions. 
% 2) Run simulations with simple phantoms, check integrity of signal,
%    update quality parameters if necessary, repeat.
% 3) Run FLUST on phantom of interest.
% 4) Apply your favorite velocity estimator to realizations. 
% 5) Assess statistical properties of estimator, optimize estimator.
% 6) Publish results, report statistical properties, make results
%    reproducible.

clear all;
close all;

% addpath('C:\Users\ingvilek\FieldIIpro\m_files'); 
% addpath('C:\Users\ingvilek\OneDrive - NTNU\FLUST\ustb_phantomDB\');
% addpath('Phantoms')
% addpath('PSF_acquisition')

addpath('H:\MUSIC\software third party\FIELD_II_Pro_2020');
addpath('H:\MUSIC\staff\anne\_MATLAB_external\20220523_FLUST');
addpath('Phantoms')
addpath('PSF_acquisition')

s = struct();

%% DATA OUTPUT PARAMETERS
s.firing_rate = 8000; % firing rate of output signal, (Doppler PRF) = (firing rate)/(nr of firings)
s.nrReps = 10;         % nr of realizations 
s.nrSamps = 40;       % nr of slow time samples in each realization (Ensemble size)

contrastMode = 0;      % is set to 1, will simulate contrast scatterers propagating in flow field
contrastDensity = 0.1; % if using contrastMode, determines the density of scatterers, typically < 0.2

%% QUALITY PARAMETERS
s.dr = 5e-5;           % spatial discretization along flowlines: lambda/4 or smaller recommended if phase information is important
s.overSampFact = 2;    % slow time oversampling factor, should be high enough to avoid aliasing
                       % in slow time signal. Without oversampling, slow time sampling rate = firing rate

%% PERFORMANCE PARAMETER
chunksize = 2;         % chunking on scanlines, adjust according to available memory.


%% DEFINE ACQUSITION SETUP / PSF FUNCTIONS 
s.PSF_function = @PSFfunc_LinearProbe_PlaneWaveImaging_rotatedGrid;

% Tranducer and acquisition parameters. Print s.PSF_params after running simulation to see which parameters can be set.
s.PSF_params = [];     
% Transducer params
s.PSF_params.trans.f0 = 7.8e6;
s.PSF_params.trans.pulse_duration = 1.5;
% Acquisition params
s.PSF_params.acq.alphaTx = [-20 20]*pi/180;
s.PSF_params.acq.alphaRx = [-20 20]*pi/180; 
% Image/scan region params
s.PSF_params.scan.rx_apod = 'tukey25';
s.PSF_params.scan.xStart = -5e-3;
s.PSF_params.scan.xEnd = 5e-3;
s.PSF_params.scan.Nx = 256;
s.PSF_params.scan.zStart = 5e-3;
s.PSF_params.scan.zEnd = 25e-3;
s.PSF_params.scan.Nz = 256;

% Runtime params
s.PSF_params.run.chunkSize = 100; % Description?

%% DEFINE PHANTOM AND PSF FUNCTIONS
%s.phantom_function = @Phantom_parabolic3Dtube;
% s.phantom_function = @Phantom_parabolic2Dtube;
s.phantom_function = @Phantom_gradient2Dtube;


% Phantom parameters. Print s.phantom_params after running simulation to see which parameters can be set.
s.phantom_params = []; 
% s.phantom_params.btfAZ = 90;
s.phantom_params.btf = 90;
s.phantom_params.diameter = 0.001; % Number of flowlines = ceil(diameter/maxLineSpacing)+1
s.phantom_params.tubedepth = 0.020;
s.phantom_params.maxLineSpacing = 0.0001; % NB: Needs to be sufficiently small for given application - in the order of lambda/2;
% s.phantom_params.vel_low = 0.001;
% s.phantom_params.vel_high = 0.5;
s.phantom_params.vel_1 = 0.001;
s.phantom_params.vel_2 = 0.5;

% To output true velocities in phantom, define grid
myX = linspace(s.PSF_params.scan.xStart,s.PSF_params.scan.xEnd,s.PSF_params.scan.Nx);
myZ = linspace(s.PSF_params.scan.zStart,s.PSF_params.scan.zEnd,s.PSF_params.scan.Nz);
[X,Z] =  meshgrid(myX,myZ);

% make phantom, get true velocity and phantom parameters
%  [flowField, s.phantom_params, GT] = s.phantom_function(s.phantom_params,X,Z); % flowField should have timetab and postab fields
Y = zeros( size(X) );
[flowField, s.phantom_params, GT] = s.phantom_function(s.phantom_params,X,Y,Z); % flowField should have timetab and postab fields

%% AS, visualize flowlines & GT
figure
for i = 1:size(flowField,2) % all flowlines
    hold on, plot3(flowField(i).postab(:,1)*1000,flowField(i).postab(:,2)*1000, flowField(i).postab(:,3)*1000,'*-')    
end
hold on, plot3(0, 0, s.phantom_params.tubedepth*1000, '.k')
%     hold on, plot3(zeros(size(depthtab,2)), zeros(size(depthtab,2)), depthtab*1000, 'sqk')
xlabel('X (mm)'), ylabel('Y (mm)'), zlabel('Z (mm)')
hold off
grid on
title('Flowlines, rF(t)')
set(gca,'zdir','reverse')
view(3)

% GTT = reshape(GT, [s.PSF_params.scan.Nx, s.PSF_params.scan.Nz, 3]);
% figure,subplot(1,4,1), imagesc(X(:),Z(:),GTT(:,:,1)), title('Vx'), colorbar
% hold on, subplot(1,4,2), imagesc(X(:),Z(:), GTT(:,:,2)), title('Vy'), colorbar
% subplot(1,4,3), imagesc(X(:),Z(:), GTT(:,:,3)), title('Vz'), colorbar

% figure, imagesc(X(:),Z(:),GT), title('Vmagn'), colorbar
figure, hold on, pcolor(X*1000,Z*1000,GT), shading interp, title('Vmagn (m/s)'), colorbar
set(gca,'ydir','reverse'), axis image
xlabel('X (mm)'), ylabel('Z (mm)')  
    

%% FLUST main loop
runFLUST;

%% VISUALIZE FIRST REALIZATION using the built-in beamformed data object

% AS: not possble yet to show data on linear_scan_rotated using ustb yet
% --> where to find in USTB?

firstRealization = realTab(:,:,:,1,1);

b_data = uff.beamformed_data();
b_data.scan = PSFstruct.scan;
b_data.data = reshape(firstRealization,size(firstRealization,1)*size(firstRealization,2),1,1,size(firstRealization,3));
b_data.plot([],['Flow from FLUST'],[20])

%% AS - temp, own visualization of realizations


            

%% True velocities?

figure(); imagesc(X(:), Z(:), GT); title('Vmag') % Example, looking at velocity magnitude (NB, change to x and z component)


%GT_rsh = reshape( GT, [s.PSF_params.scan.Nz s.PSF_params.scan.Nx 3] );
%figure(); imagesc(X(:), Z(:), GT_rsh(:,:,1)); title('Vx') % Example, looking at x component of velocity field

