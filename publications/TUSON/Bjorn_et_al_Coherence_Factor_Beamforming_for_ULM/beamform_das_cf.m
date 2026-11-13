function [b_das, b_cf] = beamform_das_cf(channel_data, scan, f_number, window, frames_per_batch, frames)
%BEAMFORM_DAS_CF  Beamform channel data with DAS and with the Coherence
%   Factor, sharing delays and apodization (Eqs. (2)-(5) of the manuscript).
%
%   [b_das, b_cf] = beamform_das_cf(channel_data, scan, f_number, window, ...
%                                   frames_per_batch, frames)
%
%   The transmit dimension is summed first (synthetic transmit focusing).
%   The receive dimension is then combined either coherently (DAS) or with
%   the coherence factor weighting (CF). Frames are processed in batches,
%   because the delayed data [pixels x channels x frames] is kept in memory.
%
%   frames is optional and selects which frames to beamform (default all).

if nargin < 6 || isempty(frames), frames = 1:channel_data.N_frames; end

all_data = channel_data.data;
restore = onCleanup(@() set_data(channel_data, all_data));

n_frames = numel(frames);
for first = 1:frames_per_batch:n_frames
    idx = first:min(first + frames_per_batch - 1, n_frames);
    channel_data.data = all_data(:, :, :, frames(idx));

    das = midprocess.das();
    das.dimension    = dimension.transmit;
    das.channel_data = channel_data;
    das.scan         = scan;
    das.receive_apodization.f_number = f_number;
    das.receive_apodization.window   = window;
    b_tx = das.go();

    das_rx = postprocess.coherent_compounding();
    das_rx.dimension = dimension.receive;
    das_rx.input     = b_tx;
    batch_das = das_rx.go();

    cf = postprocess.coherence_factor();
    cf.dimension = dimension.receive;
    cf.input     = b_tx;
    batch_cf = cf.go();

    if first == 1
        b_das = uff.beamformed_data(batch_das);
        b_cf  = uff.beamformed_data(batch_cf);
        data_das = zeros(scan.N_pixels, 1, 1, n_frames, 'like', batch_das.data);
        data_cf  = zeros(scan.N_pixels, 1, 1, n_frames, 'like', batch_cf.data);
    end
    data_das(:, 1, 1, idx) = batch_das.data;
    data_cf(:, 1, 1, idx)  = batch_cf.data;
end
b_das.data = data_das;
b_cf.data  = data_cf;
end

function set_data(channel_data, data)
channel_data.data = data;
end
