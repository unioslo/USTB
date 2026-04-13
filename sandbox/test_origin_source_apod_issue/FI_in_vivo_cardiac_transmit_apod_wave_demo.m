url = tools.zenodo_dataset_files_base();
local_path = [ustb_path(),'/data/']; 
filename='Verasonics_P2-4_parasternal_long_small.uff';
tools.download(filename, url, local_path);
channel_data = uff.read_object([local_path, filename],'/channel_data');

% NB! If you have trouble downloading the data using the download tool you can 
% download the data directly from https://ustb.no/datasets/Verasonics_P2-4_parasternal_long_small.uff
% Delete the corrupt file with the same filename and move the downloaded data
% to the "data/" folder in the USTB repository and rerun the example.

depth_axis=linspace(0e-3,110e-3,1024).';                % Define image scan
azimuth_axis=linspace(channel_data.sequence(1).source.azimuth,...
    channel_data.sequence(end).source.azimuth,channel_data.N_waves)';
scan=uff.sector_scan('azimuth_axis',azimuth_axis,'depth_axis',depth_axis);

mid=midprocess.das();tic();                                % Beamform image
mid.channel_data=channel_data;
mid.dimension = dimension.both();
mid.scan=scan;
mid.transmit_apodization.window=uff.window.scanline;
mid.receive_apodization.window=uff.window.none;
b_data_scanline = mid.go();                        
b_data_scanline.plot([],['Cardiac Scanline Tx Wave apod'],[],[],[],[],[],'dark');    % Display 
%%
mid.dimension = dimension.receive();
b_data_scanline_single_tx = mid.go();                     
b_data_scanline_single_tx.plot([],['Cardiac Scanline Tx Wave apod'],[],[],[],[],[],'dark');    % Display 

%% MLA
mid.dimension = dimension.receive();
mid.transmit_apodization.window = uff.window.scanline;
mid.transmit_apodization.MLA = 1;
mid.transmit_apodization.MLA_overlap = 4;
b_data_MLA = mid.go()
b_data_MLA.plot([],['Cardiac Scanline Tx Wave apod'],[],[],[],[],[],'dark');    % Display 

%% RTB
mid.dimension = dimension.receive();
mid.transmit_apodization.window = uff.window.tukey25;
mid.transmit_apodization.f_number = 4;
mid.transmit_apodization.MLA = 1;
mid.transmit_apodization.MLA_overlap = 4;
b_data_RTB = mid.go()
b_data_RTB.plot([],['Cardiac Scanline Tx Wave apod'],[],[],[],[],[],'dark');    % Display 