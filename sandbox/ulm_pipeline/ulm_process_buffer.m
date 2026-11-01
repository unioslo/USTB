function out = ulm_process_buffer(channel_data, scan, p)
% ULM_PROCESS_BUFFER Shared ULM processing of one buffer of channel data
%
% Usage: out = ulm_process_buffer(channel_data, scan, p)
%
%   channel_data    uff.channel_data of one buffer [time x channel x wave x frame]
%   scan            uff.linear_scan to beamform on
%   p               parameters, see ulm_pipeline_parameters
%
%   out.tracks.<beamformer>   tracks from ulm.ULM.go(), positions in m
%   out.b_data.<beamformer>   uff.beamformed_data fed to ULM (if p.keep_b_data)
%   out.lambda                wavelength used [m]
%
% Steps, the same for every dataset:
%   1. SVD clutter filter on the channel data
%   2. DAS on transmit, in batches of frames
%   3. receive combination: coherence factor and/or coherent compounding
%   4. optional lag-1 autocorrelation signal enhancement
%   5. local noise normalization
%   6. ulm.ULM localization and tracking
%
% Tracks are not linked across buffers, so call this once per buffer and
% concatenate the tracks.
%
% See also ULM_PIPELINE_PARAMETERS, ULM_RENDER_DENSITY

assert(~isempty(p.framerate), 'Set p.framerate to the compounded frame rate.');
lambda = p.lambda;
if isempty(lambda)
    lambda = channel_data.lambda;
end
n_frames = size(channel_data.data, 4);

%% 1. SVD clutter filter
svd = preprocess.svd_filter();
svd.input = channel_data;
if p.svd_cutoff < 1
    svd.cutoff = max(2, round(p.svd_cutoff*n_frames));
else
    svd.cutoff = p.svd_cutoff;
end
svd_channel_data = svd.go();
clear channel_data

%% 2.-3. Beamforming in batches
das = midprocess.das();
das.scan = scan;
das.dimension = dimension.transmit;
das.code = p.code;
das.receive_apodization.window = p.receive_window;
das.receive_apodization.f_number = p.f_number;

rx = struct();
for name = p.beamformers
    switch name{1}
        case 'CF'
            rx.CF = postprocess.coherence_factor();
        case 'DAS'
            rx.DAS = postprocess.coherent_compounding();
        otherwise
            error('Unknown beamformer %s, use CF or DAS.', name{1});
    end
    rx.(name{1}).dimension = dimension.receive;
end

iq = struct();
for first_frame = 1:p.batch_size:n_frames
    frame_idx = first_frame:min(first_frame + p.batch_size - 1, n_frames);

    channel_batch = uff.channel_data(svd_channel_data);
    channel_batch.data = svd_channel_data.data(:, :, :, frame_idx);
    das.channel_data = channel_batch;
    b_data_tx = das.go();

    for name = p.beamformers
        rx.(name{1}).input = b_data_tx;
        b_batch = rx.(name{1}).go();
        if first_frame == 1
            iq.(name{1}) = zeros(scan.N_pixels, n_frames, 'like', b_batch.data);
        end
        iq.(name{1})(:, frame_idx) = reshape(b_batch.data, scan.N_pixels, []);
    end
    clear channel_batch b_data_tx b_batch
end
clear svd_channel_data

%% 4.-6. Signal enhancement, normalization and ULM per beamformer
u = ulm.ULM();
u.verbose = false;
u.workbars = false;
u.framerate = p.framerate;
u.lambda = lambda;
u.fwhm = p.fwhm;
u.NLocalMax = p.n_local_max;
u.numberOfParticles = p.number_of_particles;
u.intensity_threshold = p.snr_threshold;
u.max_linking_distance = p.max_linking_distance;
u.min_length = p.min_length;
u.resolution = p.resolution;
u.algorithm = p.algorithm;
u.tracking = p.tracking;

out.lambda = lambda;
for name = p.beamformers
    data = reshape(double(iq.(name{1})), scan.N_z_axis, scan.N_x_axis, []);
    iq.(name{1}) = [];

    % 4. Lag-1 autocorrelation (as ULMShare): one frame shorter
    if p.use_lag1
        window = hann(p.lag1_window);
        window = reshape(window./sum(window), 1, 1, []);
        envelope = sqrt(abs(convn(data(:, :, 1:end-1).*conj(data(:, :, 2:end)), window, 'same')));
    else
        envelope = abs(data);
    end
    clear data

    % 5. Divide each pixel by its RMS over time, smoothed by a Gaussian.
    % Otherwise the numberOfParticles brightest maxima per frame all end up
    % in the brightest region (top of the image for DAS, deep noise or skull
    % clutter for ULMShare). TGC mask from ULMShare, see
    % code/example_script.m in https://github.com/provostultrasoundlab/ulmshare
    if p.normalization_sigma > 0
        envelope = envelope./imgaussfilt(sqrt(mean(envelope.^2, 3)), p.normalization_sigma);
    end

    % 6. ULM
    b_ulm = uff.beamformed_data();
    b_ulm.scan = scan;
    b_ulm.frame_rate = p.framerate;
    b_ulm.data = reshape(single(envelope), scan.N_pixels, 1, 1, []);
    clear envelope

    u.input = b_ulm;
    u.scan = scan;
    tracks = u.go();
    out.tracks.(name{1}) = tracks(:);
    if p.keep_b_data
        out.b_data.(name{1}) = b_ulm;
    end
end
end
