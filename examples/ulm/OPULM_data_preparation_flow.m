%% Overview
% As the data provided by OPULM is not in a UFF file format, it must be
% downloaded as is, and converted separately.
%
% The datasets covered in this example set is the InSilico flow simulation
% and InVivo rat brain data. Only these sets are covered, as they are the
% only datasets in OPULM with raw RF channel data available. The
% insilico PSF, invivo mouse tumor, invivo rat brain bolus, and invivo rat
% kidney are only available in post-beamformed IQ data.
%
% This scripts shows the conversion of the InSilicoFlow dataset. For the
% InVivo rat brain set, see the other OPULM data preparation example:
% ustb/examples/ulm/OPULM_data_preparation_ratbrain.m

% %% InSilico Flow
% The insilico flow data consists of two parts, the ground truth and the
% raw RF data, which is downloaded separately. Unfortunately, the metadata
% is only available bundled with the IQ data, as well as the ULM
% experiments and statistics output of the PALA paper, making the otherwise
% ~9MB metadata file 4.4GB instead...
% The downloaded files are only used temporarely to create a combined UFF
% file, after which, the other files can be deleted. The automatic deletion
% of these files is commented out, so the script is safe to execute in its
% entirety.

%% Step 1: Download and unpack both datasets
% The datasets are found at the following URLs:
%
% - InSilico Flow RF data (4.5GB): 
% https://zenodo.org/records/4343435/files/PALA_data_InSilicoFlow_RF.zip
%
% - InSilico Flow Metadata + Ground Truth (4.4GB):
% https://zenodo.org/records/4343435/files/PALA_data_InSilicoFlow.zip

local_path = [ustb_path(),'/data/']; 
url='https://zenodo.org/records/4343435/files/';     

% RF data
fprintf("Downloading PALA InSilicoFlow RF data...\n");
tools.download('PALA_data_InSilicoFlow_RF.zip', url, local_path);
% Unpack zip
fprintf("Unpacking PALA InSilicoFlow RF data....");
unzip([local_path 'PALA_data_InSilicoFlow_RF.zip'], local_path )
fprintf("Done!\n");

% Metadata              
tools.download('PALA_data_InSilicoFlow_RF.zip', url, local_path);
% Unpack zip
fprintf("Unpacking PALA InSilicoFlow metadata....");
unzip([local_path 'PALA_data_InSilicoFlow.zip'], local_path )
fprintf("Done!\n");

%% Step 2: Initial data loading
% With the data unpacked, its ready to be loaded and converted to a UFF.
% The PALA_data_InSilicoFlow/RF folder contains a segmented dataset split 
% into 20 chunks with 1000 frames of RF data per chunk totaling 20k frames. 
% The variable below controls how many chunks to combine to a final UFF. 
% Default is set to 20, which includes the full dataset.
data_path = [local_path 'PALA_data_InSilicoFlow/'];
N_chunks = 20;

% Load the PALA metadata
load([data_path filesep 'PALA_InSilicoFlow_sequence.mat'], ...
    'P', 'PData', 'Trans', 'TX', 'Receive', 'Resource', 'TW');

% Use the Verasonics module to convert the PALA data to UFF
device = verasonics();

TX = TX(1,1:3);
device.Trans = Trans;
device.Receive = Receive;
device.Resource = Resource;
device.number_of_frames = P.BlocSize;
device.number_of_superframes = P.numBloc;
device.TW = TW;
device.TX = TX;

angles = [0,0,0];
for tx_i = 1:P.numTx
    angles(tx_i) = TX(tx_i).Steer(1);
end
device.angles = angles;

%% Step 3: Convert and combine Chunks
% Last step is to convert each chunk of RF data to UFF data blocks with
% correct conversions of units. Each chunk writes to the same UFF
% file, and it can grow quickly. This means a concatination of frames in 
% time might end up too large for some systems. It is, therefor, segmented 
% into smaller chunks at the root of the UFF, following the same chunks as
% the files:
% InSilicoFlow.uff/
%   /scan
%   /1/channel_data
%   /2/channel_data
%   ...
%   /20/channel_data
% 
% Loading data thus means you need to specify the chunk before channel_data
% during a uff.read_object. For example:
% uff.read_object([local_path 'InSilicoFlow.uff'], '/1/channel_data')

% Each chunk contains 1000 frames, organized into 10 blocks per chunk, 
% at 100 frames per block.
% Iterate over each chunk and block
pbar = waitbar(0, "");
tot_loads = N_chunks*P.numBloc;

for chunk_i = 1:N_chunks
    % Load each chunk file
    load([data_path filesep 'RF' filesep 'PALA_InSilicoFlow_RF' num2str(chunk_i,'%03.0f') '.mat'], 'RFdata');
    block_ii = 0;
    for block_i = 1:P.BlocSize:(P.BlocSize*P.numBloc)
        block_ii = block_ii + 1;
        x = (chunk_i-1)*P.numBloc + block_ii;
        waitbar(x/tot_loads, pbar, strjoin(["Loading block" block_ii "of chunk" chunk_i]));
        
        % Index correct block of RFdata
        device.RcvData = {RFdata(:,:,block_i:(block_i+P.BlocSize-1))};
        
        if block_i == 1
            ch_data = device.create_cpw_channeldata();
        else    
            ch_data.data = cat(4, ch_data.data, device.create_cpw_channeldata().data);
        end
    end

    % Convert BS100BW -> IQ
    % This conversion is explained in detail Appendix A of
    % Simon A. Bjørn's Master's thesis (UiO DUO Archive):
    % http://hdl.handle.net.ezproxy.uio.no/10852/120821
    RF = single(ch_data.data);
    ch_data.data = RF(1:2:end-1,:,:,:) - 1j * RF(2:2:end,:,:,:);
    
    ch_data.sampling_frequency = ch_data.sampling_frequency / 2;
    ch_data.modulation_frequency = ch_data.sampling_frequency;

    waitbar(x/tot_loads, pbar, strjoin(["Writing data from chunk" chunk_i "to UFF..."]));
    uff.write_object([local_path filesep 'InSilicoFlow.uff'], ch_data, 'channel_data', ['/' num2str(chunk_i)]);
end
close(pbar)

%% Step 4: Construct a linear scan
% A UFF scan class should be provided to unify the spatial domain for all
% use og the dataset. This is computed as a combination of the PixelData
% struct from the metadata

% Spatial axes in wavelengths
lmb_x = PData.Origin(1)+(0:PData.Size(2)-1).' .* PData.PDelta(1);
lmb_z = PData.Origin(3) + (0:PData.Size(1)-1).' .* PData.PDelta(3);

scan = uff.linear_scan();
scan.x_axis = lmb_x * ch_data.lambda;
scan.z_axis = lmb_z * ch_data.lambda;
uff.write_object([local_path 'InSilicoFlow.uff'], scan, 'scan', '/');

%% Step 5: Create ground truth data
% Lastly, the ground truth data can be loaded and converted to the same
% spatial region, following the same pixel to world space mapping as the
% scan.

% Scan region at ULM resolution is 10x larger
lmb_x_ulm = PData.Origin(1)+(0:PData.Size(2)*10).' .* PData.PDelta(1)/10;
lmb_z_ulm = PData.Origin(3)+(0:PData.Size(1)*10).' .* PData.PDelta(3)/10;
gt_x_axis = lmb_x_ulm * ch_data.lambda;
gt_z_axis = lmb_z_ulm * ch_data.lambda;

% Ground truth ULM image with perfect track reconstruction
targetImage = load([data_path 'PALA_InSilicoFlow_v3_config.mat'], 'MatOut').MatOut;

% The true particle positions per chunk exists in the RF data as well,
% so they must be concatinated as well:

targetPositions = [];
for chunk_i = 1:N_chunks
    % Load each chunk file
    load([data_path filesep 'RF' filesep 'PALA_InSilicoFlow_RF' num2str(chunk_i,'%03.0f') '.mat'], 'ListPos');
    
    % ListPos is in x,y,z,frame_idx, with x,y,z in wavelengths and must be
    % converted to meters.
    ListPos(:,1:3,:) = ListPos(:,1:3,:) .* ch_data.lambda;
    
    % Concatinate on frame dimension
    targetPositions = cat(3, targetPositions, ListPos);
end

% Save 
save([local_path 'InSilicoFlow_GroundTruth.mat'], "targetImage", "gt_x_axis", "gt_z_axis", "targetPositions")

%% Step 5: Clean up
% With the finilization of InSilicoFlow.uff, the temporary files, IQ
% data and RF data can be deleted. This part is commented out, in case
% something went wrong, or you want to have a look at the data your self.
% Uncomment the following lines to delete Non-converted data.

% % Delete unpacked data
% delete(data_path);
% % Delete downloaded InSilicoFlow metadata
% delete([local_path 'PALA_data_InSilicoFlow.zip']);
% % Delete downloaded InSilicoFlow RF data
% delete([local_path 'PALA_data_InSilicoFlow_RF.zip'])

clearvars;
fprintf("Finieshed prepearing InSilicoFlow data from OPULM.\n");
