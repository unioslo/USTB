%% ULM example using simulations and ground truth
% This example shows how the ULM module of USTB can be used to assess
% localization and beamformer performance in a ULM context, using the OPULM
% InSilicoFlow dataset.
% 
% This script assumes the data is prepared following the steps in 
% ustb/examples/ulm/OPULM_data_preparation_flow.m

%% Step 1: Data Loading
% Since the dataset is segmented quite large, but already separated into 20
% chunks of 1000 frames each, this example scripts only coveres using the
% first segment, as this makes it run faster, while still showing off the
% capabilities of the ULM module, without having to touch on piece-wise
% computations and concatinations.
% However, 1000 frames might still be too much for certain systems. Thus,
% the data will be clipped to only use 100 frames.

% Start by loading the first chunk of channel data, the uff scan object and
% the ground truth positions.
local_path = [ustb_path(),'/data/']; 
insilico_ch_data = uff.read_object([local_path 'InSilicoFlow.uff'], '/1/channel_data');
insilico_scan = uff.read_object([local_path 'InSilicoFlow.uff'], '/scan');
insilico_gt = load([local_path 'InSilicoFlow_GroundTruth.mat'], 'targetPositions').targetPositions;

% Use only the first 100 frames
insilico_ch_data.data = insilico_ch_data.data(:,:,:,1:100);
insilico_gt = insilico_gt(:,:,1:100); 

fprintf("\nInSilico Data:\nSamples: %d\nReceive: %d\nTransmits: %d\nFrames: %d\n", deal(size(insilico_ch_data.data)));

%% Step 2: Beamforming
% For this example, the beamforming step uses DAS only on transmit and
% combines the receive with the coherence-factor beamformer. The parameters
% used follows the tuned parameter case for lambda/2 sampling from Simon A.
% Bjørn's master's thesis, Figure 5.1.
% http://hdl.handle.net.ezproxy.uio.no/10852/120821

% Since the scan is by default using lambda-by-lambda sampling, upscaling
% the scan resolution by 2, yields a lambda/2-by-lambda/2 spatial sampling.
% A convinience script for this was added to the +tools module
insilico_scan = tools.scan_integer_upscale(insilico_scan, 2);

% The DAS-midprocess is configured as follows ...
das = midprocess.das();
das.dimension = dimension.transmit;
das.channel_data = insilico_ch_data;
das.scan = insilico_scan;
das.receive_apodization.f_number = 0.8;
das.receive_apodization.window = uff.window.hamming;

% ... and the coherence factor ...
cf = postprocess.coherence_factor();
cf.dimension = dimension.receive;

% Before computing them, setting a higher framerate, and displaying the
% results.
cf.input = das.go();
insilico_b_cf = cf.go();
insilico_b_cf.frame_rate = 100;
insilico_b_cf.plot([], 'InSilico Flow CF', 60)

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
u.numberOfParticles = 41;

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
u.lambda = insilico_ch_data.lambda;
u.input = insilico_b_cf;
u.scan = insilico_scan;

% Then simply execute the ULM process
tracks = u.go();

%% Step 4: Localization & pairing statistics
% With the tracks computed, they can be concatinated into one large matrix
% of particle positions per frame, and compared against the ground truth
% particle positions. 
stats = u.pairing(cell2mat(tracks), insilico_gt);

% The resulting array contains counts of each frame, as
% [# particles in GT, # particles in localization, # true positives, 
% # false negatives, # false positives]. Summing the array along dim 1,
% then yields the total count among all frames, from which follow up
% statistical metrics can be computed.
stats = sum(stats,1);
TP = stats(3);
FN = stats(4);
FP = stats(5);

jaccard = TP/(TP+FN+FP) * 100; % Jaccard Index in percent
fprintf("Jaccard Index: %.2f%%\n", jaccard);

%% Step 5a: ULM Image construction
% ULM is no fun without images.
% To synthesize an ULM image from tracks, the aptly named "create_image"
% method in the ULM process can be used. Simply feed it the tracks created
% from the main "go()" process.

% Synthesize a "track" image. Other image modes are available. See
% enumeration("ulm.image_mode") for more
ulm_img = u.create_image(tracks, "tracks");
figure;
imagesc(insilico_scan.x_axis * 1e3, insilico_scan.z_axis * 1e3, ulm_img);
xlabel("X [mm]");ylabel("z [mm]");
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
imagesc(insilico_scan.x_axis * 1e3, insilico_scan.z_axis * 1e3, ulm_img);
xlabel("X [mm]");ylabel("z [mm]");
colormap turbo;