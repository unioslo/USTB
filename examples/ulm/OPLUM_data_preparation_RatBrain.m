%% Step 1: Downloading and unpacking the dataset
local_path = [ustb_path(),'/data/']; 
base_url = 'https://zenodo.org/records/7883227/files/';

%%
% Downloading metadata param.mat
param_url = [base_url 'param.mat?download=1'];
param_file = [local_path 'param.mat'];
if ~exist(param_file, 'file')
    fprintf("Downloading metadata param.mat...\n");
    websave(param_file, param_url);
end

% Downloading first 25 RF files
RF_file = [local_path 'RF_001_to_025.zip'];
if ~exist([local_path filesep 'RF'], 'dir')
    if ~exist(RF_file, 'file')
        fprintf("Downloading in vivo rat brain data...\n");
        RF_url = [base_url 'RF_001_to_025.zip?download=1'];
        websave(RF_file, RF_url);
    end
    fprintf("Unpacking in vivo rat brain data...\n");
    unzip(RF_file, local_path);
end
fprintf("Done!\n");

%% Step 2: Initial data loading
% Downloaded rat data needs to be converted to UFF
% We have 250 files, each containing 800 frames of RF data

% Loading metadata
load([local_path filesep 'param.mat']);
N_chunks = 1; % N_chunks = 25

% Create TX structure
TX = struct( ...
    'waveform', 1, ...
    'Origin', [0,0,0], ...
    'Steer', [0,0,0], ...
    'Apod', ones(1,Trans.numelements), ...
    'Delay', zeros(1,Trans.numelements));

angles = param.Angles;

for tx_i = 1:param.numRcv
    z_pos = -60;
    x_pos = z_pos*tan(angles(tx_i));

    TX(1,tx_i) = struct('waveform', 1, ...
        'Origin', [x_pos,0,z_pos], ...
        'Steer', [angles(tx_i),0], ...
        'Apod', ones(1,Trans.numelements)', ...
        'Delay', zeros(1,Trans.numelements)');
end

% Using Verasonics module to convert PALA data to UFF
device = verasonics();

device.Trans = Trans;
device.TW = transmit_waveform;
device.TX = TX;
device.angles = angles;
device.Receive = receive;

param.speedOfSound = param.SpeedOfSound;
device.Resource = struct( ...
    'Parameters', param, ...
    'RcvBuffer', struct( ...
        'numFrames', param.BlocSize) ...
    );


%% Step 3: Converting chunks
% InVivoRatBrain.uff/
%   /scan
%   /1/channel_data
%   /2/channel_data
%   ...
%   /20/channel_data
% 

uff_filename = [local_path filesep 'InVivoRatBrain.uff'];
if exist(uff_filename, 'file')
    delete(uff_filename);
end

for chunk_i = 1:N_chunks
    if N_chunks > 1

        tools.workbar(chunk_i / N_chunks, strjoin(["Loading chunks... [" chunk_i  "/" N_chunks "]"], ''));
    end
    filename = strjoin(["RF_" num2str(chunk_i, '%03d') ".hdf5"], '');
    data = h5read(fullfile([local_path filesep 'RF'], filename), '/rf/rf');
    
    % Pass chunk to device and create channel data object
    device.RcvData = {data};
    ch_data = device.create_cpw_channeldata_RatBrain();

    RF = single(ch_data.data);
    ch_data.data = RF(1:2:end-1,:,:,:) - 1j * RF(2:2:end,:,:,:); 
    ch_data.sampling_frequency = ch_data.sampling_frequency / 2; 
    ch_data.modulation_frequency = ch_data.sampling_frequency; 


    uff.write_object(uff_filename, ch_data, 'channel_data', ['/' num2str(chunk_i)]);
end

tools.workbar(1);
disp("Done!")


%% Step 5: Construct a linear scan
% Recreate the spatial axes exactly as defined in the in vivo sequence
% Spatial axes in wavelengths
lmb_x = PixelData.Origin(1) + (0:PixelData.Size(2)-1).' .* PixelData.PDelta(1);
lmb_z = PixelData.Origin(3) + (0:PixelData.Size(1)-1).' .* PixelData.PDelta(3);

scan_obj = uff.linear_scan();
scan_obj.x_axis = lmb_x * ch_data.lambda; 
scan_obj.z_axis = lmb_z * ch_data.lambda;

% Write scan grid to the root of the UFF file
uff.write_object(uff_filename, scan_obj, 'scan', '/');

fprintf('Successfully saved Rat Brain UFF file');

