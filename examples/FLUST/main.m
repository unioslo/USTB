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
% 2) Run simulations with simple phantoms, check integrity of signal,
%    update quality parameters if necessary, repeat.
% 3) Run FLUST on phantom of interest.
% 4) Apply your favorite velocity estimator to realizations. 
% 5) Assess statistical properties of estimator, optimize estimator.
% 6) Publish results, report statistical properties, make results
%    reproducible.

clear all;
close all;

addpath('C:\Users\ingvilek\FieldIIpro\m_files'); 
addpath('C:\Users\ingvilek\OneDrive - NTNU\FLUST\ustb_flust_git');
addpath('Phantoms')
addpath('PSF_acquisition')

s = struct();

%% DATA OUTPUT PARAMETERS
s.firing_rate = 12000; % firing rate of output signal, (Doppler PRF) = (firing rate)/(nr of firings)
s.nrReps = 10;         % nr of realizations 
s.nrSamps = 100;       % nr of slow time samples in each realization

contrastMode = 0;      % is set to 1, will simulate contrast scatterers propagating in flow field
contrastDensity = 0.1; % if using contrastMode, determines the density of scatterers, typically < 0.2

%% QUALITY PARAMETERS
s.dr = 5e-5;           % spatial discretization along flowlines: lambda/4 or smaller recommended if phase information is important
s.overSampFact = 2;    % slow time oversampling factor, should be high enough to avoid aliasing
                       % in slow time signal. Without oversampling, slow time sampling rate = firing rate

%% PERFORMANCE PARAMETER
chunksize = 5;         % chunking on scanlines, adjust according to available memory.


%% DEFINE ACQUSITION SETUP / PSF FUNCTIONS 
s.PSF_function = @PSFfunc_LinearProbe_PlaneWaveImaging;

s.PSF_params = [];     % Tranducer and acquisition parameters. Default values used if not set
% Transducer params
s.PSF_params.trans.f0 = 6.25e6;
s.PSF_params.trans.pulse_duration = 1.5;
% Acquisition params
s.PSF_params.acq.alphaTx = [-10 -10 0 10 10]*pi/180;
s.PSF_params.acq.alphaRx = [-10 -5 0 5 10]*pi/180; 
% Image/scan region params
s.PSF_params.scan.rx_apod = 'tukey25';
s.PSF_params.scan.xStart = -5e-3;
s.PSF_params.scan.xEnd = 5e-3;
s.PSF_params.scan.zStart = 5e-3;
s.PSF_params.scan.zEnd = 25e-3;
% Runtime params
s.PSF_params.run.chunkSize = 100;

%% DEFINE PHANTOM AND PSF FUNCTIONS
s.phantom_function = @Phantom_small2Dtube;
s.phantom_params = []; % this structure may contain phantom parameters

% make phantom
flowField = s.phantom_function(s.phantom_params); % flowField should have timetab and postab fields


%% FLUST main loop
runFLUST;

%% VISUALIZE FIRST REALIZATION using the built-in beamformed data object
firstRealization = realTab(:,:,:,1,1);

b_data = uff.beamformed_data();
b_data.scan = PSFstruct.scan;
b_data.data = reshape(firstRealization,size(firstRealization,1)*size(firstRealization,2),1,1,size(firstRealization,3));
b_data.plot([],['Flow from FLUST'],[20])