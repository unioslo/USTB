% Updated 10/11/2020, Joergen Avdal (jorgen.avdal@ntnu.no)

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
% 2) Run FLUST on phantom of interest.
% 3) Apply your favorite velocity estimator to realizations. 
% 4) Assess statistical properties of estimator, optimize estimator.
% 5) Publish results, report statistical properties, make results
%    reproducible.
% 6) Cite original FLUST paper

clear all;
close all;

setPathsScript;

%% DATA OUTPUT PARAMETERS
s = struct();

s.firing_rate = 12000; % firing rate of output signal, (Doppler PRF) = (firing rate)/(nr of firings)
s.nrReps = 100;         % nr of realizations 
s.nrSamps = 50;       % nr of slow time samples in each realization (Ensemble size)

s.contrastMode = 0;      % is set to 1, will simulate contrast scatterers propagating in flow field
s.contrastDensity = 0.1; % if using contrastMode, determines the density of scatterers, typically < 0.2

%% QUALITY PARAMETERS, SET ONLY ONE OF THESE
% s.dr = 5e-5;  % spatial discretization along flowlines: lambda/4 or smaller recommended if phase information is important
s.interpErrorLimit = 4; % FLUST will set s.dr to attain interpolation error smaller than this value in percent

%% PERFORMANCE PARAMETER
s.chunksize = 5;         % chunking on scanlines, adjust according to available memory.
s.useGPU = 0;


%% DEFINE ACQUSITION SETUP / PSF FUNCTIONS 
s.PSF_function = @PSFfunc_LinearProbe_LinearScan;

% Tranducer and acquisition parameters. Print s.PSF_params after running simulation to see which parameters can be set.
s.PSF_params = [];     
% Transducer params
s.PSF_params.trans.f0 = 6.25e6;
s.PSF_params.trans.pulse_duration = 1.5;
s.PSF_params.trans.pitch = 200e-6;
s.PSF_params.trans.element_height = 5e-3;
% Acquisition params
s.PSF_params.acq.noTx = 4;
s.PSF_params.acq.F_number_Tx = 3;
s.PSF_params.acq.F_number_Rx = 1;
s.PSF_params.acq.Txspacing = s.PSF_params.trans.pitch*2;
s.PSF_params.acq.noMLA = 8;
% Image/scan region params
s.PSF_params.scan.zStart = 15e-3;
s.PSF_params.scan.zEnd = 25e-3;
s.PSF_params.scan.Nz = 128;

% Runtime params
s.PSF_params.run.chunkSize = 101; % Description?

%% DEFINE PHANTOM AND PSF FUNCTIONS
%s.phantom_function = @Phantom_parabolic3Dtube;
s.phantom_function = @Phantom_parabolic2Dtube;
%s.phantom_function = @Phantom_gradient2Dtube;


% Phantom parameters. Print s.phantom_params after running simulation to see which parameters can be set.
s.phantom_params = []; 
s.phantom_params.btfAZ = 60;
s.phantom_params.diameter = 0.001;  % Number of flowlines = ceil(diameter/maxLineSpacing)+1
s.phantom_params.maxLineSpacing = 0.0001; % NB: Needs to be sufficiently small for given application - in the order of lambda/2;
s.phantom_params.vel_low = 0.8;
s.phantom_params.vel_high = 1.2;
s.phantom_params.flowlength = 0.006; 
s.phantom_params.tubedepth = 0.02; %0.03;

% make phantom, get true velocity and phantom parameters
[flowField, s.phantom_params] = s.phantom_function(s.phantom_params); % flowField should have timetab and postab fields

%% FLUST main loop
runFLUST;

%% Extract ground truth using grid from PSF function
[~, ~, GT] = s.phantom_function(s.phantom_params, PSFstruct.scan.x, PSFstruct.scan.y, PSFstruct.scan.z);

%% VISUALIZE FIRST REALIZATION using the built-in beamformed data object
firstRealization = realTab(:,:,:,1,1);

b_data = uff.beamformed_data();
b_data.scan = PSFstruct.scan;
b_data.data = reshape(firstRealization,size(firstRealization,1)*size(firstRealization,2),1,1,size(firstRealization,3));
b_data.frame_rate = 20;
b_data.plot([],'Flow from FLUST',20)

%% True velocities?

GT_rsh = reshape( GT, [PSFstruct.scan.N_z_axis PSFstruct.scan.N_x_axis 1 3] );
figure(2); imagesc(PSFstruct.scan.x_axis(:), PSFstruct.scan.z_axis(:), GT_rsh(:,:,1,1)); axis equal; title('Vx') % Example, looking at x component of velocity field
figure(3); imagesc(PSFstruct.scan.x_axis(:), PSFstruct.scan.z_axis(:), GT_rsh(:,:,1,3)); axis equal; title('Vz') % Example, looking at z component of velocity field

