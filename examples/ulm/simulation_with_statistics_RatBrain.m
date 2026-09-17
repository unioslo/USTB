%% Step 1: Data Loading
% Start by loading the first chunk of channel data and the uff scan object 
file_path = [ustb_path(),'/data/']; 
invivo_ch_data = uff.read_object([file_path filesep 'InVivoRatBrain.uff'], '/1/channel_data');
invivo_scan = uff.read_object([file_path filesep 'InVivoRatBrain.uff'], '/scan');

% Use only the first xx frames
invivo_ch_data.data = invivo_ch_data.data(:,:,:,1:40);

fprintf("\nInVivo Data:\nSamples: %d\nReceive: %d\nTransmits: %d\nFrames: %d\n", deal(size(invivo_ch_data.data)));

%% Step 2: Beamforming
% For this example, the beamforming step uses DAS only on transmit and
% combines the receive with the coherence-factor beamformer. The parameters
% used follows the tuned parameter case for lambda/2 sampling from Simon A.
% Bjørn's master's thesis, Figure 5.1.
% http://hdl.handle.net.ezproxy.uio.no/10852/120821

% Since the scan is by default using lambda-by-lamture bda sampling, upscaling
% the scan resolution by 2, yields a lambda/2-by-lambda/2 spatial sampling.
% A convinience script for this was added to the +tools module
invivo_scan = tools.scan_integer_upscale(invivo_scan, 2);

%%
% Preprocess SVD-filter
svd = preprocess.svd_filter();
svd.input = invivo_ch_data;
svd.cutoff = 2;
svd_ch_data = svd.go();

%%
% The DAS-midprocess is configured as follows ...
das = midprocess.das();
das.dimension = dimension.transmit;
%das.channel_data = invivo_ch_data;
das.channel_data = svd_ch_data; % With SVD filtering
das.scan = invivo_scan;
das.receive_apodization.f_number = 0.8; 
das.receive_apodization.window = uff.window.hamming;

% ... and the coherence factor ...
cf = postprocess.coherence_factor();
cf.dimension = dimension.receive;


% Before computing them, setting a higher framerate, and displaying the
% results.
cf.input = das.go();
invivo_b_cf = cf.go();
invivo_b_cf.frame_rate = 100;
invivo_b_cf.plot([], 'InVivo Rat Brain CF', 60)


%% Step 3: The actual ULM part
% With some data beamformed and configured, this step walks through a basic
% configurationg of a ULM pipeline.
% The basis for all pipelines is the ULM handle object. This creature
% behaves similar to postprocesses, where a uff.beamformed_data is fed into
% its 'input' property, and 'go()' executes its algorithm. However, there
% are quite a few parameters and options that goes along with it. Some of
% which will be covered here.

% Start by instantiating a simple ULM object:
u = ulm.ULM();

% The following parameters used in chapter 5 of Simon A.
% Bjørn's master's thesis, Table 5.1b: CF @ lambda/2:
% The framerate specifies the framerate at which the RF data is captured.
% This is required due its implications on linking particales across
% frames.
u.framerate = 500;

% The full-width half-maximum (fwhm) parameter tunes the kernel sizes of
% initial particle position guesses, and is configured in number of pixels.
% For this case, the fwhm is estimated to be 3x3 (width, height) pixels.
u.fwhm = [3 3];

% The numberOfParticles parameter sets the upper limit for how many
% particles the ULM process tries to localize. If more than this number is
% located, only the specified number of strongest points will be recorded.
% This is per frame without heuristics, so overshooting a bit is better, as
% this allows for a small amount of false positives in addition to true 
% positives, instead of potentially discarding true positives. For this
% pure example, however, we know there are a maximum of 41 particles in 
% any given frame, meaning its a good estimate to use here.
u.numberOfParticles = 40;

% The last 3 parameters are a bit more advanced and not well documented in
% the toolbox yet. For now, see Chapter 3.3 "ULM implementation in USTB" 
% of Simon A. Bjørn's master's thesis.
u.NLocalMax = 2;
u.max_linking_distance = 3; 
u.min_length = 15;


% The next two options are not parameters, but settings deciding how the
% ULM process is performed. 

% The first is the algorithm, which specifies
% which localization algorithm to use. The radial symmetry localization
% algorithm is implemented under the ulm.algorithm.radial, and is quite
% fast and efficient, so its used in this example. For other options, see
% enumeration('ulm.algorithm')
u.algorithm = ulm.algorithm.radial;

% The second option specifies how the linker operates. In this example, we
% want to compare the raw localized datapoints against ground truth, and so
% we do not want any interpolation of the trackes based on velocity or
% positions. This equates to using the "tracks" tracking algorithm, which
% simply outputs a cell array, containing arrays of particle tracks over
% with positions at each frame the track exists.
u.tracking = ulm.tracking.tracks;

% Lastly, the data from the previous step is supplied. Lambda must be
% supplied separately, as beamformed_data has no lambda property.
u.lambda = invivo_ch_data.lambda;
u.input = invivo_b_cf;
u.scan = invivo_scan;

% Then simply execute the ULM process
tracks = u.go();


%% Step 5a: ULM Image construction
% ULM is no fun without images.
% To synthesize an ULM image from tracks, the aptly named "create_image"
% method in the ULM process can be used. Simply feed it the tracks created
% from the main "go()" process.

% Synthesize a "track" image. Other image modes are available. See
% enumeration("ulm.image_mode") for more
ulm_img = u.create_image(tracks, "tracks");
figure;
imagesc(invivo_scan.x_axis * 1e3, invivo_scan.z_axis * 1e3, ulm_img);
xlabel("X [mm]");ylabel("z [mm]");
title('ULM InVivo Rat Brain')
colormap turbo;


%% Step 5b: ULM Image Construction with interpolation
% As is visible, the image is quite choppy, and the tracks are pixelated.
% This is because the tracking algorithm only used the particle positions
% at every "full frame". This is especially visable for fast moving 
% particles, as large gaps are formed as the particle moves multiple pixels
% between frames. No interpolation, no smooth paths.
% Changing the tracking algorithm to use velocity_interpolation instead
% yields a much better image.

u.tracking = ulm.tracking.velocity_interpolation;
ulm_img = u.create_image(u.go(), "tracks");
figure;
imagesc(invivo_scan.x_axis * 1e3, invivo_scan.z_axis * 1e3, ulm_img);
xlabel("X [mm]");ylabel("z [mm]");
title('ULM InVivo Rat Brain with interpolation')
colormap turbo;