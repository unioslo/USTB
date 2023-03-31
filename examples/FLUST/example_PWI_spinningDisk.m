% Updated 10/11/2020, Joergen Avdal (jorgen.avdal@ntnu.no)

% If using FLUST for scientific publications, please cite the original paper
% Avdal et al: Fast Flow-Line-Based Analysis of Ultrasound Spectral and
% Vector Velocity Estimators, tUFFC, 2019. DOI: 10.1109/TUFFC.2018.2887398

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
% 2) Run FLUST on phantom of interest.
% 3) Apply your favorite velocity estimator to realizations. 
% 4) Assess statistical properties of estimator, optimize estimator.
% 5) Publish results, report statistical properties, make results
%    reproducible, cite original paper DOI: 10.1109/TUFFC.2018.2887398


clear all;
close all;

setPathsScript;

%% DATA OUTPUT PARAMETERS
s = struct();

s.firing_rate = 8000; % firing rate of output signal, (Doppler PRF) = (firing rate)/(nr of firings)
s.nrReps = 100;         % nr of realizations 
s.nrSamps = 40;       % nr of slow time samples in each realization (Ensemble size)

s.contrastMode = 0;      % is set to 1, will simulate contrast scatterers propagating in flow field
s.contrastDensity = 0.1; % if using contrastMode, determines the density of scatterers, typically < 0.2

%% QUALITY PARAMETERS, SET ONLY ONE OF THESE
% s.dr = 5e-5;  % spatial discretization along flowlines: lambda/4 or smaller recommended if phase information is important
s.interpErrorLimit = 4; % FLUST will set s.dr to attain interpolation error smaller than this value in percent

%% PERFORMANCE PARAMETER
s.chunksize = 16;         % chunking on scanlines, adjust according to available memory.
s.useGPU = 0;


%% DEFINE ACQUSITION SETUP / PSF FUNCTIONS 
s.PSF_function = @PSFfunc_LinearProbe_PlaneWaveImaging;

% Tranducer and acquisition parameters. Print s.PSF_params after running simulation to see which parameters can be set.
s.PSF_params = [];     
% Transducer params
s.PSF_params.trans.f0 = 7.8e6;
s.PSF_params.trans.pulse_duration = 1.5;
s.PSF_params.trans.element_height = 5e-3;
s.PSF_params.trans.pitch = 135e-6;
s.PSF_params.trans.kerf = 13.5e-6;
s.PSF_params.trans.N = 192;

% Acquisition params
s.PSF_params.acq.alphaTx = [-15 15]*pi/180;
s.PSF_params.acq.alphaRx = [0 0]*pi/180; 
s.PSF_params.acq.F_number = 1.0;
% Image/scan region params
s.PSF_params.scan.rx_apod = 'tukey25';
s.PSF_params.scan.xStart = -5e-3;
s.PSF_params.scan.xEnd = 5e-3;
s.PSF_params.scan.Nx = 256;
s.PSF_params.scan.zStart = 15e-3;
s.PSF_params.scan.zEnd = 25e-3;
s.PSF_params.scan.Nz = 128;

% Runtime params
s.PSF_params.run.chunkSize = 125; % Description?

%% DEFINE PHANTOM AND PSF FUNCTIONS
%s.phantom_function = @Phantom_parabolic3Dtube;
% s.phantom_function = @Phantom_parabolic2Dtube;
%s.phantom_function = @Phantom_gradient2Dtube;
s.phantom_function = @Phantom_spinningDisk;


% Phantom parameters. Print s.phantom_params after running simulation to see which parameters can be set.
s.phantom_params = []; 
% s.phantom_params.btfAZ = 60;
% s.phantom_params.diameter = 0.006;  % Number of flowlines = ceil(diameter/maxLineSpacing)+1
% s.phantom_params.maxLineSpacing = 0.0001; % NB: Needs to be sufficiently small for given application - in the order of lambda/2;
% s.phantom_params.vel_low = 1.5;
% s.phantom_params.vel_high = 3;
% s.phantom_params.flowlength = 0.012; 
% s.phantom_params.vel_1 = 0.02;
% s.phantom_params.vel_2 = 2.0;
s.phantom_params.maxVel = 0.7;
s.phantom_params.minVel = 0.2;
s.phantom_params.diameter = 0.007; %m
s.phantom_params.tubedepth = 0.02; %0.03;

% To output true velocities in phantom, define grid
myX = linspace(s.PSF_params.scan.xStart,s.PSF_params.scan.xEnd,s.PSF_params.scan.Nx);
myZ = linspace(s.PSF_params.scan.zStart,s.PSF_params.scan.zEnd,s.PSF_params.scan.Nz);
myY = 0;
[X,Z,Y] =  meshgrid(myX,myZ,myY);

% make phantom, get true velocity and phantom parameters
% [flowField, s.phantom_params, GT] = s.phantom_function(s.phantom_params,X,Z); % flowField should have timetab and postab fields
%Y = zeros( size(X) );
[flowField, s.phantom_params, GT] = s.phantom_function(s.phantom_params,X,Y,Z); % flowField should have timetab and postab fields



%% FLUST main loop
runFLUST;

%% VISUALIZE FIRST REALIZATION using the built-in beamformed data object
firstRealization = realTab(:,:,:,1,1);

b_data = uff.beamformed_data();
b_data.scan = PSFstruct.scan;
b_data.data = reshape(firstRealization,size(firstRealization,1)*size(firstRealization,2),1,1,size(firstRealization,3));
b_data.frame_rate = 20;
b_data.plot([],'Flow from FLUST', 20)

%% True velocities?

%figure(); imagesc(X(:), Z(:), GT); title('Vmag') % Example, looking at velocity magnitude (NB, change to x and z component)


GT_rsh = reshape( GT, [s.PSF_params.scan.Nz s.PSF_params.scan.Nx 1 3] );
figure(2); imagesc(X(:), Z(:), GT_rsh(:,:,1,1)); axis equal; title('Vx') % Example, looking at x component of velocity field
figure(3); imagesc(X(:), Z(:), GT_rsh(:,:,1,3)); axis equal; title('Vz') % Example, looking at x component of velocity field

