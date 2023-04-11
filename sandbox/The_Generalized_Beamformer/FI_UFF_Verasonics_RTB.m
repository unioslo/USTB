%% Reading FI data from an UFF file recorded from a Verasonics Scanner
%
% In this example we show how to read channel data from a
% UFF (Ultrasound File Format) file recorded with a Verasonics scanner.
% You will need an internet connection to download data.
%
% _by Ole Marius Hoel Rindal <olemarius@olemarius.net>
%   and Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>
%
%   $Last updated: 2017/10/06$

%% Checking the file is in the path
%
% To read data from a UFF file the first we need is, you guessed it, a UFF
% file. We check if it is on the current path and download it from the USTB
% websever.

clear all; close all;

% data location
url='http://ustb.no/datasets/';      % if not found downloaded from here
filename='L7_FI_IUS2023.uff';

% checks if the data is in your data path, and downloads it otherwise.
% The defaults data path is under USTB's folder, but you can change this
% by setting an environment variable with setenv(DATA_PATH,'the_path_you_want_to_use');
tools.download(filename, url, data_path);   

%% Reading data
%
% Let's first check if we are lucky and the file allready contains
% beamformed_data that we can display.
display=true;
content = uff.index([data_path filesep filename],'/',display);


%% Channel data
% If it doesn't have any beamformed data at least it should have some
% channel_data. So let's read that.

channel_data=uff.read_object([data_path filesep filename],'/channel_data');
%%
D = abs(min(channel_data.probe.x)-max(channel_data.probe.x));
step = D/channel_data.N_waves;
% for w = 1:channel_data.N_waves
%     channel_data.sequence(w).origin.x = step.*w 
% end

%%  
%
% And then do the normal routine of defining the scan,
x_axis=zeros(channel_data.N_waves,1);
for n=1:channel_data.N_waves
    x_axis(n)=channel_data.sequence(n).source.x;
end
z_axis=linspace(5e-3,50e-3,512*2).';
scan=uff.linear_scan('x_axis',x_axis,'z_axis',z_axis);

%%
%
% setting up and running the pipeline
mid=midprocess.das();
mid.dimension = dimension.both();

mid.channel_data=channel_data;
mid.scan=scan;

mid.transmit_apodization.window=uff.window.scanline;

mid.receive_apodization.window=uff.window.none;
mid.receive_apodization.f_number=1.7;

b_data=mid.go();

%% Display image
%
% And finally display the image.
b_data.plot([],'Beamformed image');


%% Retrospective beamforming
MLA = 4;

scan_RTB = uff.linear_scan('x_axis',linspace(x_axis(1),x_axis(end),length(x_axis)*MLA)','z_axis',z_axis);

mid_RTB=midprocess.das();
mid_RTB.dimension = dimension.receive();

mid_RTB.channel_data=channel_data;
mid_RTB.scan=scan_RTB;
% We are using the hybrid transmit delay model. See the reference below:
% Rindal, O. M. H., Rodriguez-Molares, A., & Austeng, A. (2018). A simple , artifact-free , virtual source model. 
% IEEE International Ultrasonics Symposium, IUS, 1–4. 
mid_RTB.spherical_transmit_delay_model = spherical_transmit_delay_model.hybrid;
mid_RTB.transmit_apodization.window=uff.window.tukey25;
mid_RTB.transmit_apodization.f_number = 2;
mid_RTB.transmit_apodization.MLA = MLA;
mid_RTB.transmit_apodization.MLA_overlap = MLA;
mid_RTB.transmit_apodization.minimum_aperture = [3.0000e-03 3.0000e-03];

mid_RTB.receive_apodization.window=uff.window.boxcar;
mid_RTB.receive_apodization.f_number=1.7;
b_data_RTB=mid_RTB.go();

%%

b_data_RTB.plot([])
b_data_RTB.frame_rate = 20;
%%

% %%
% tx_apod = mid_RTB.transmit_apodization.data;
% 
% %%
% weighting = 1./sum(tx_apod,2);
% 
% b_data_RTB_compensated = uff.beamformed_data(b_data_RTB);
% b_data_RTB_compensated.data = b_data_RTB.data .* weighting;
% b_data_RTB_compensated.plot([],'RTB image using virtual source model TX weighted');
% 
% %%
% mid_RTB.dimension = dimension.receive();
% b_data_RTB_transmit = mid_RTB.go();
% 
% %% Illustrate t0 compensation
% selected_tx = 20;
% single_tx_images = b_data_RTB_transmit.get_image();
% transmit_delays = channel_data.sequence(selected_tx).delay_values;
% transmit_delays(50:end) = transmit_delays(49);
% 
% figure(8);clf;
% subplot(5,1,1)
% plot(transmit_delays*10^6,'HandleVisibility','off','LineWidth',2);hold on;
% plot(channel_data.sequence(selected_tx).delay_values*10^6,'HandleVisibility','off','LineWidth',2)
% plot(49,transmit_delays(49)*10^6,'o','DisplayName','Conventional t_0','LineWidth',2);hold on;
% plot(64,channel_data.sequence(selected_tx).delay_values(end/2)*10^6,'o','DisplayName','Generalized t_0','LineWidth',2)
% xlim([1 128]);xlabel('Elements');
% xlabel('Elements');ylabel(["Delay [ms]"]);title('Tx Wavefront');
% legend
% ylim([-7 3])
% set(gca,'FontSize',13)
% subplot(5,1,[2:5])
% imagesc(scan.x_axis*1000,scan.z_axis*1000,single_tx_images(:,:,selected_tx))
% axis image;colormap gray;caxis([-70 0])
% xlabel(['x [mm]']);ylabel(['z [mm]']);%colorbar
% title('Single Focused Transmission');
% set(gcf,'Position',[605 197 484 781])
% set(gca,'FontSize',15)
% %%
% %%
% f = gcf;
% saveas(f,'Figures/FI_RTB.png');
% %% Run the REFOCUS preprocess
% addpath C:/Repositories/USTB_addons/
% 
% refocus = preprocess.refocus()
% refocus.input = channel_data;
% channel_data_STAI = refocus.go()
% 
% %%
% demod = preprocess.fast_demodulation()
% demod.input = channel_data_STAI
% demod.plot_on = true;  
% channel_data_STAI_demod = demod.go();
% 
% %%
% das = midprocess.das();
% das.scan = scan;
% das.channel_data=channel_data_STAI_demod;
% das.transmit_apodization.window=uff.window.tukey50;
% das.transmit_apodization.f_number = 4;
% das.receive_apodization.window=uff.window.tukey50;
% das.receive_apodization.f_number = 1;
% das.dimension = dimension.both;
% b_data_REFOCUS = das.go()
% %%
% b_data_REFOCUS.plot([],['REFOCUS from '],[],[],[],[],[],'dark')
% 
% %%
% channel_data_single_tx = uff.channel_data(channel_data);
% channel_data_single_tx.data = channel_data.data(:,:,selected_tx);
% channel_data_single_tx.sequence = channel_data.sequence(selected_tx);
% %channel_data_single_tx.sequence.apodization_values(32:128) = 0;
% 
% refocus = preprocess.refocus()
% refocus.input = channel_data_single_tx;
% channel_data_STAI_single_tx = refocus.go()
% 
% %%
% demod = preprocess.fast_demodulation()
% demod.input = channel_data_STAI_single_tx
% channel_data_STAI_demod_single_tx = demod.go();
% %%
% das.dimension = dimension.receive;
% das.transmit_apodization.window=uff.window.tukey50;
% das.transmit_apodization.f_number = 4;
% das.channel_data = channel_data_STAI_demod_single_tx
% das.receive_apodization.window=uff.window.tukey50;
% das.receive_apodization.f_number = 1;
% b_data_REFOCUS = das.go()
% %%
% b_data_REFOCUS.plot([],['REFOCUS from '],[],[],[],[],[],'dark')
% 
