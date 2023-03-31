% run after example_PWI
% Updated 28/06/2022, Joergen Avdal (jorgen.avdal@ntnu.no) and 
% Ingvild Kinn Ekroll (ingvild.k.ekroll@ntnu.no)

%% Load data
addpath( 'Estimators');
addpath( 'Validation');
addpath( 'Tools');

tag = 'PWI_demo';
loadBinary(tag);

assessParams = struct();

%% Assessment parameters
maxXVal = 0.003;
scanMask = ones(size(X));
scanMask(abs(X(:))>maxXVal) = NaN;
assessParams.scanMask = scanMask; % Mask accounting for valid scan region (optional)

assessParams.scatterDecimationFac = 10;
assessParams.SNR = 20;
assessParams.biasPercentage = 500; % Percentage of Nyquist velocity
assessParams.stdPercentage = 100;  % Percentage of Nyquist velocity

%% Add noise
if ~isnan( assessParams.SNR)
    noisyTab = addNoise( realTab, assessParams.SNR);
else
    noisyTab = realTab;
end

%% Get autocorrelation estimates from FLUST realizations
assessParams.result = estimate_autocorr(noisyTab);

%% Run performance analysis
validate_autocorr(assessParams);

