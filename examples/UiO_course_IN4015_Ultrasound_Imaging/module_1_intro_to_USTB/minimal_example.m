url='http://ustb.no/datasets/';                  %Download and read dataset
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
b_data = mid.go();toc();                         
b_data.plot([],['Human Heart'],[],[],[],[],[],'dark');    % Display 
% Exercise Module 1: Add your name to the title above so that it says
% "Human Heart by Your Name" and add the image your report.