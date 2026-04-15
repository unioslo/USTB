clear all;
close all;

url = tools.zenodo_dataset_files_base();
local_path = [ustb_path(),'/data/']; 
filename='Verasonics_P2-4_parasternal_long_small.uff';end_depth = 110e-3;
filename='P4_FI_121444_45mm_focus.uff';end_depth = 70e-3;
tools.download(filename, url, local_path);
channel_data = uff.read_object([local_path, filename],'/channel_data');
channel_data.N_frames = 1;
mkdir('Figures/FI_phased/')
MLA = 1;

% Fixing the anoing bug
for tx = 1:channel_data.N_waves
    channel_data.sequence(tx).origin.x = 0;
end

depth_axis=linspace(5e-3,end_depth,1024).';                % Define image scan
azimuth_axis=linspace(channel_data.sequence(1).source.azimuth,...
    channel_data.sequence(end).source.azimuth,channel_data.N_waves*MLA)';
scan=uff.sector_scan('azimuth_axis',azimuth_axis,'depth_axis',depth_axis);

%%
mid=midprocess.das();tic();                                % Beamform image
mid.channel_data=channel_data;
mid.dimension = dimension.transmit();
mid.scan=scan;
mid.pw_margin = 5e-3;
mid.transmit_apodization.window=uff.window.scanline;
mid.transmit_apodization.MLA = MLA;
mid.transmit_apodization.MLA_overlap = 0;
mid.receive_apodization.window=uff.window.hamming;
mid.receive_apodization.f_number = 0.5;
b_data_delayed_scanline = mid.go();     

%% RTB
mid.dimension = dimension.transmit();
mid.transmit_apodization.window = uff.window.hamming;
mid.transmit_apodization.f_number = 3;
mid.transmit_apodization.minimum_aperture = 2e-3;
b_data_delayed_RTB = mid.go();     


%% Coherence Factor
cf = postprocess.coherence_factor();
cf.input = b_data_delayed_scanline;
cf.go()
b_data_CF_scanline = cf.CF;

cf.input = b_data_delayed_RTB;
cf.go();
b_data_CF_RTB = cf.CF;
%%
f = figure();
b_data_CF_scanline.plot(f,['CF scanline'],[],'none',[],[],[],'dark'); colormap default;
saveas(f,'Figures/FI_phased/CF_scanline.png');
f = figure();
b_data_CF_RTB.plot(f,['CF RTB'],[],'none',[],[],[],'dark'); colormap default;
saveas(f,'Figures/FI_phased/CF_RTB.png');

b_data_compare = uff.beamformed_data(b_data_CF_scanline);
b_data_compare.data(:,:,1,1) = b_data_CF_scanline.data;
b_data_compare.data(:,:,1,2) = b_data_CF_RTB.data;
b_data_compare.plot([],['1 = CF scanline, 2 = CF RTB, 3 = RTB'],[],['none'],[],[],[],'dark');colormap default;
b_data_compare.frame_rate = 1;
b_data_compare.save_as_gif(['Figures/FI_phased/compare_CF.gif']);