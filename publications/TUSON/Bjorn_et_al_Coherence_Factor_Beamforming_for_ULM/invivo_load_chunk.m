function [channel_data, scan] = invivo_load_chunk(cfg, chunk_i)
%INVIVO_LOAD_CHUNK  Read one 800-frame chunk of the PALA in vivo rat-brain
%   RF data and return it as USTB objects.
%
%   [channel_data, scan] = invivo_load_chunk(cfg, chunk_i)
%
%   channel_data  uff.channel_data, IQ, [samples x channels x waves x frames]
%   scan          uff.linear_scan on the PALA rat-brain grid (lambda/2)
%
%   The conversion is the one in examples/ulm/OPLUM_data_preparation_RatBrain.m,
%   but done in memory, since the full 250-chunk sequence is too large to
%   keep as one UFF file. RF_xxx.hdf5 and param.mat must be downloaded from
%   Zenodo record 7883227 (see the README in this folder).

rf_file = fullfile(cfg.invivo.rf_path, sprintf('RF_%03d.hdf5', chunk_i));
assert(exist(rf_file, 'file') == 2, 'Missing %s, see README.', rf_file);
S = load(cfg.invivo.param_file);
param = S.param;
n_elements = S.Trans.numelements;

% One plane wave per steering angle
angles = param.Angles;
for tx_i = 1:param.numRcv
    z_pos = -60;
    TX(1, tx_i) = struct('waveform', 1, ...
        'Origin', [z_pos*tan(angles(tx_i)), 0, z_pos], ...
        'Steer', [angles(tx_i), 0], ...
        'Apod', ones(n_elements, 1), ...
        'Delay', zeros(n_elements, 1)); %#ok<AGROW>
end

device = verasonics();
device.Trans   = S.Trans;
device.TW      = S.transmit_waveform;
device.TX      = TX;
device.angles  = angles;
device.Receive = S.receive;
param.speedOfSound = param.SpeedOfSound;
device.Resource = struct('Parameters', param, ...
    'RcvBuffer', struct('numFrames', param.BlocSize));
device.RcvData = {h5read(rf_file, '/rf/rf')};
channel_data = device.create_cpw_channeldata_RatBrain();

% Verasonics BS100BW sampling -> IQ (Appendix A of Bjorn's MSc thesis)
rf = single(channel_data.data);
channel_data.data = rf(1:2:end-1, :, :, :) - 1j*rf(2:2:end, :, :, :);
channel_data.sampling_frequency   = channel_data.sampling_frequency/2;
channel_data.modulation_frequency = channel_data.sampling_frequency;

% Pixel grid of the PALA sequence, in metres
lambda = channel_data.lambda;
pd = S.PixelData;
scan = uff.linear_scan();
scan.x_axis = (pd.Origin(1) + (0:pd.Size(2)-1).'*pd.PDelta(1))*lambda;
scan.z_axis = (pd.Origin(3) + (0:pd.Size(1)-1).'*pd.PDelta(3))*lambda;
end
