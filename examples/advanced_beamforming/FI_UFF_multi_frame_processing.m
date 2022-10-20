% Script demonstrating a strategy to reduce the memory during multi frame
% processing

clear all;close all;
url = ['https://drive.google.com/uc?export=download' ...
    '&id=19OyvPCP4qUiTECFpUe8r3r_Ys2281j0N'];  % if not found download from here
% Choose dataset
name = 'Verasonics_P2-4_apical_four_chamber_subject_1.uff';
% Create full filepath
file = fullfile(data_path(), name);
% check if the file is available in the local path or downloads otherwise
tools.download(file, url)
% read the data
channel_data = uff.read_object(file,'/channel_data');
scan = uff.read_object(file,'/scan');

%%
% Print info about the dataset. Remeber that if you want to use this dataset
% you have to reference this article!
channel_data.print_authorship

%% Create the images of the heart.
depth_axis=linspace(0e-3,130e-3,512).';
azimuth_axis=zeros(channel_data.N_waves,1);
for n=1:channel_data.N_waves
    azimuth_axis(n) = channel_data.sequence(n).source.azimuth;
end

scan=uff.sector_scan('azimuth_axis',azimuth_axis,'depth_axis',depth_axis);

mid=midprocess.das();
mid.dimension = dimension.transmit;

mid.channel_data=channel_data;
mid.scan=scan;

mid.transmit_apodization.window=uff.window.scanline;
mid.receive_apodization.window=uff.window.none;


channel_data_temp = uff.channel_data(channel_data);
frames_per_process = 5;
first = true;

for c = 1:floor(channel_data.N_frames/frames_per_process)
    fprintf('Running processing cycle %d of %d \n',c,floor(channel_data.N_frames/frames_per_process))
    channel_data_temp.data = channel_data.data(:,:,:,(c-1)*frames_per_process+1:c*frames_per_process);
    
    % This will result in a beamformed_data object with the delayed and not
    % summed channel data.
    mid.channel_data = channel_data_temp;
    b_data = mid.go();
    
    % DAS image
    das = postprocess.coherent_compounding();
    das.input = b_data;
    das_data = das.go();
    
    % CF image
    CF = postprocess.coherence_factor();
    CF.receive_apodization = mid.receive_apodization;
    CF.dimension = dimension.receive;
    CF.input = b_data;
    cf_data = CF.go();
    
    if first
        first = false;
        das_data_all = uff.beamformed_data(das_data);
        cf_data_all = uff.beamformed_data(cf_data);
    else
        das_data_all.data = cat(4,das_data_all.data,das_data.data);
        cf_data_all.data = cat(4,cf_data_all.data,cf_data.data);
    end
end

%% Plot the two images
das_data_all.plot(3,['DAS']);
cf_data_all.plot(4,['CF']);

