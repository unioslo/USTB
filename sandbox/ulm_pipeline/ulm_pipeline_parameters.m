function p = ulm_pipeline_parameters()
% ULM_PIPELINE_PARAMETERS Default parameters for ulm_process_buffer
%
% Returns a struct with every setting of the shared ULM pipeline. Each
% dataset script (PALA, ULMShare, ...) starts from these defaults and only
% overrides what depends on the data: grid, frame rate, SVD cutoff and the
% ULM localization/tracking parameters.
%
% See also ULM_PROCESS_BUFFER, ULM_RENDER_DENSITY

% Acquisition (must be set by the dataset script)
p.framerate = [];               % [Hz] compounded frame rate (not the PRF of each transmit)
p.lambda = [];                  % [m] if empty, taken from channel_data.lambda

% 1. SVD clutter filter on the channel data
% cutoff >= 1: first singular component kept (cutoff = 5 removes 1-4)
% cutoff <  1: fraction of the frames, as in ULMShare (0.05 of 400 frames
%              keeps from component 20, i.e. removes 1-19)
p.svd_cutoff = 5;

% 2. Beamforming (DAS on transmit, receive combined in step 3)
p.f_number = 1.4;
p.receive_window = uff.window.hamming;
p.code = code.mex;              % code.mex_gpu if available
p.batch_size = 20;              % frames beamformed at a time

% 3. Receive combination: any of 'CF' (coherence factor) and 'DAS'
% (coherent compounding). Each gives its own set of tracks.
p.beamformers = {'CF', 'DAS'};

% 4. Lag-1 autocorrelation signal enhancement (ULMShare)
p.use_lag1 = false;
p.lag1_window = 7;              % [frames] Hann window

% 5. Local noise normalization (ULMShare's TGC mask). 0 disables it.
p.normalization_sigma = 9;      % [pixels]

% 6. ULM localization and tracking (ulm.ULM)
p.fwhm = [5 5];                 % [pixels]
p.n_local_max = 7;
p.number_of_particles = 90;     % per frame
p.snr_threshold = 1.5;          % on the normalized intensity
p.max_linking_distance = 3;     % [lambda] per frame
p.min_length = 15;              % [frames]
p.resolution = 10;              % density map pixel = lambda/resolution
p.algorithm = ulm.algorithm.radial;
p.tracking = ulm.tracking.velocity_interpolation;

% Keep the beamformed (envelope) data of each beamformer in the output,
% e.g. for B-mode figures or a DAS vs CF gif. Costs memory.
p.keep_b_data = false;
end
