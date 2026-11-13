function cfg = ulm_paper_config()
%ULM_PAPER_CONFIG  All paths and parameters used to produce the figures of
%   Bjorn et al., "Enhanced Ultrasound Localization Microscopy through
%   Coherence Factor Adaptive Beamforming".
%
%   Every script in this folder reads its settings from here, so a
%   parameter is changed in one place only. Values are taken from the
%   manuscript tables and from Simon A. Bjorn's MSc thesis (UiO, 2025).
%   Values that the thesis does not state are marked ASSUMPTION.

%% Paths
cfg.data_path    = fullfile(ustb_path(), 'data');
cfg.results_path = fullfile(cfg.data_path, 'ULM_coherence_paper');
cfg.figure_path  = fullfile(cfg.results_path, 'figures');

%% Beamforming shared by both datasets
cfg.window           = uff.window.hamming; % receive apodization window
cfg.frames_per_batch = 50;                 % frames beamformed at a time (memory)

%% ULM settings shared by both datasets
cfg.ulm.algorithm       = ulm.algorithm.radial; % radial symmetry localizer
cfg.ulm.min_length      = 15;   % minimum track length [frames]
cfg.ulm.max_gap_closing = 0;
cfg.ulm.resolution      = 6;    % lambda/12 ULM grid on a lambda/2 B-mode grid

%% OPULM / PALA in silico flow (Zenodo record 4343435)
cfg.insilico.pala_path = fullfile(cfg.data_path, 'PALA_data_InSilicoFlow');
cfg.insilico.chunks    = 1:20;  % 20 chunks of 1000 frames
cfg.insilico.snr_db    = 10;    % SNR after adding white noise to the RF data
cfg.insilico.f_number  = 0.8;
cfg.insilico.upscale   = 2;     % native scan is lambda x lambda
cfg.insilico.framerate = 500;   % P.FrameRate of the PALA sequence
cfg.insilico.numberOfParticles = 40;

% Jaccard-optimal parameters at lambda/2 (manuscript Table "opulm-ulm-tuned")
cfg.insilico.ulm.das = struct('fwhm', [5 5], 'NLocalMax', 4, 'max_linking_distance', 3);
cfg.insilico.ulm.cf  = struct('fwhm', [3 3], 'NLocalMax', 2, 'max_linking_distance', 3);

% Regions of interest of the simulated scene, [x_min x_max z_min z_max] in mm
cfg.insilico.roi.horseshoe      = [-4.89 -3.62 3.59 4.75];
cfg.insilico.roi.flow           = [-4.70 -0.78 4.95 7.30];
cfg.insilico.roi.cross          = [ 5.45  6.34 8.98 9.50];
cfg.insilico.roi.vertical_gap   = [-5.00  0.69 9.15 9.40];
cfg.insilico.roi.horizontal_gap = [ 5.73  6.02 2.80 8.47];
cfg.insilico.gap_threshold      = 0.05; % fraction of the target maximum

%% OPULM / PALA in vivo rat brain (Zenodo record 7883227)
cfg.invivo.rf_path    = fullfile(cfg.data_path, 'RF');        % RF_001.hdf5 ...
cfg.invivo.param_file = fullfile(cfg.data_path, 'param.mat');
cfg.invivo.chunks     = 1:250;  % 250 chunks of 800 frames; missing files are skipped
cfg.invivo.f_number   = 1.5;
cfg.invivo.upscale    = 1;      % the PALA rat-brain scan is already lambda/2
cfg.invivo.framerate  = 1000;   % param.FrameRate of the dataset
cfg.invivo.svd_cutoff = 5;      % keep singular vectors 5:end (removes the first four), as PALA

% ULM parameters (manuscript Table "invivo-parameters"), identical for DAS and CF.
% ASSUMPTION: NLocalMax and numberOfParticles are not given in the thesis;
% the ulm.ULM class defaults (3 and 70) are used.
cfg.invivo.ulm = struct('fwhm', [5 5], 'NLocalMax', 3, ...
    'max_linking_distance', 2, 'numberOfParticles', 70);

% Regions of interest of the rat brain, [x_min x_max z_min z_max] in mm
cfg.invivo.roi.b = [-1.35  0.99 7.35 8.98]; % deep central
cfg.invivo.roi.c = [ 0.94  3.24 4.86 6.47]; % mid-field
cfg.invivo.roi.d = [-3.43 -0.19 1.34 3.59]; % superficial cortex

% Heuristic image indices
% ASSUMPTION: window size and number of bins are not given in the thesis.
cfg.metrics.window = 15;   % local standard deviation window [ULM pixels]
cfg.metrics.bins   = 256;  % histogram bins for matching and entropy

%% Display
cfg.display.gamma = 1/3;   % power compression of ULM density images (as PALA)

if ~exist(cfg.results_path, 'dir'), mkdir(cfg.results_path); end
if ~exist(cfg.figure_path, 'dir'),  mkdir(cfg.figure_path);  end
end
