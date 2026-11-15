function [channel_data, scan, ground_truth] = insilico_load_chunk(cfg, chunk_i)
%INSILICO_LOAD_CHUNK  Read one 1000-frame chunk of the PALA in silico flow
%   RF data and return it as USTB objects.
%
%   [channel_data, scan, ground_truth] = insilico_load_chunk(cfg, chunk_i)
%
%   channel_data  uff.channel_data, IQ, [samples x channels x waves x frames]
%   scan          uff.linear_scan on the native lambda x lambda PALA grid
%   ground_truth  [N x 4 x frames] true bubble positions [x y z .] in metres,
%                 NaN where a slot is empty
%
%   The conversion is the one in examples/ulm/OPULM_data_preparation_flow.m,
%   but done in memory so that the full 20-chunk dataset does not have to be
%   written to a UFF file first. The data must be downloaded and unpacked
%   into cfg.insilico.pala_path (see the README in this folder).

pala = cfg.insilico.pala_path;
rf_file = fullfile(pala, 'RF', sprintf('PALA_InSilicoFlow_RF%03d.mat', chunk_i));
assert(exist(rf_file, 'file') == 2, ...
    'Missing %s. Download and unpack PALA_data_InSilicoFlow_RF.zip, see README.', rf_file);

S = load(fullfile(pala, 'PALA_InSilicoFlow_sequence.mat'), ...
    'P', 'PData', 'Trans', 'TX', 'Receive', 'Resource', 'TW');
P = S.P;
D = load(rf_file, 'RFdata', 'ListPos');

% Verasonics structures -> uff.channel_data, one block of frames at a time
device = verasonics();
device.Trans    = S.Trans;
device.Receive  = S.Receive;
device.Resource = S.Resource;
device.TW       = S.TW;
device.TX       = S.TX(1, 1:P.numTx);
device.number_of_frames      = P.BlocSize;
device.number_of_superframes = P.numBloc;
device.angles = arrayfun(@(tx) tx.Steer(1), device.TX);

for block_i = 1:P.numBloc
    frames = (block_i-1)*P.BlocSize + (1:P.BlocSize);
    device.RcvData = {D.RFdata(:, :, frames)};
    block = device.create_cpw_channeldata();
    if block_i == 1
        channel_data = block;
        data = zeros([size(block.data, 1:3) P.BlocSize*P.numBloc], 'single');
    end
    data(:, :, :, frames) = single(block.data);
end

% Verasonics BS100BW sampling -> IQ (Appendix A of Bjorn's MSc thesis)
channel_data.data = data(1:2:end-1, :, :, :) - 1j*data(2:2:end, :, :, :);
channel_data.sampling_frequency   = channel_data.sampling_frequency/2;
channel_data.modulation_frequency = channel_data.sampling_frequency;

% Pixel grid of the PALA sequence, in metres
lambda = channel_data.lambda;
scan = uff.linear_scan();
scan.x_axis = (S.PData.Origin(1) + (0:S.PData.Size(2)-1).'*S.PData.PDelta(1))*lambda;
scan.z_axis = (S.PData.Origin(3) + (0:S.PData.Size(1)-1).'*S.PData.PDelta(3))*lambda;

% True positions are stored in wavelengths
ground_truth = D.ListPos;
ground_truth(:, 1:3, :) = ground_truth(:, 1:3, :)*lambda;
end
