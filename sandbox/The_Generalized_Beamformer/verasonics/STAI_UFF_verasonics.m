%% Process the experimental data
% For the publication Rindal, O. M. H., Austeng, A., Fatemi, A., 
% & Rodriguez-Molares, A. (2019). The effect of dynamic range alterations
% in the estimation of contrast. Submitted to IEEE Transactions on Ultrasonics,
% Ferroelectrics, and Frequency Control.
%
% Author: Ole Marius Hoel Rindal <olemarius@olemarius.net> 05.06.18
% updated for revised version of manuscript 07.03.19

clear all;
close all;

%%
filename = ['L7_STA_points.uff'];
channel_data=uff.read_object([data_path filesep filename],'/channel_data');
url='http://ustb.no/datasets/';      % if not found downloaded from here

% checks if the data is in your data path, and downloads it otherwise.
% The defaults data path is under USTB's folder, but you can change this
% by setting an environment variable with setenv(DATA_PATH,'the_path_you_want_to_use');
%tools.download(filename, url, data_path);   

%% Scan
scan=uff.linear_scan();
scan.x_axis = linspace(channel_data.probe.x(1),channel_data.probe.x(end),512).';
scan.z_axis = linspace(3e-3,50e-3,512).';

%% Beamformer
mid = midprocess.das();
mid.channel_data=channel_data;
mid.scan=scan;
mid.dimension = dimension.receive();

mid.receive_apodization.window=uff.window.boxcar;
mid.receive_apodization.f_number=1.75;

mid.transmit_apodization.window=uff.window.none;
mid.transmit_apodization.f_number=1.75;

b_data_tx = mid.go();

%% Calculate weights to get uniform FOV. See example
% http://www.ustb.no/examples/uniform-fov-in-field-ii-simulations/
[weights,array_gain_compensation,geo_spreading_compensation] = ...
                                           tools.uniform_fov_weighting(mid);
                
%% Put the weights in a b_data struct to be able to save them later
b_data_weights = uff.beamformed_data();                                       
b_data_weights.scan = scan;
b_data_weights.data = weights(:);

%% DELAY AND SUM
das=postprocess.coherent_compounding();
das.input = b_data_tx;
b_data_das = das.go();
img = b_data_tx.get_image;
single_tx = 20;
f = figure;
subplot(5,1,1);hold on;
active_elements = zeros(1,128);
active_elements(single_tx) = 1;
%plot(transmit_delays*10^6,'HandleVisibility','off');hold on;
%plot(channel_data.sequence(single_tx).delay_values*10^6,'HandleVisibility','off')
plot(active_elements,'*')
%plot(single_tx,1,'*')
%plot(49,transmit_delays(49)*10^6,'o','DisplayName','Conventional t_0');hold on;
%plot(64,channel_data.sequence(single_tx).delay_values(end/2)*10^6,'o','DisplayName','Generalized t_0')
xlim([1 128]);xlabel('Elements');
xlabel('Elements');;title('Transmitting Element');%ylabel(["Active Elements"])
%legend
%ylim([-8 3])
set(gca,'FontSize',14)
subplot(5,1,[2:5])
imagesc(b_data_das.scan.x_axis*1000,b_data_das.scan.z_axis*1000,img(:,:,single_tx));
colormap gray;caxis([-70 0]);axis image;title('Single Element STAI Image');xlabel('x [mm]');ylabel('z [mm]');
set(gca,'FontSize',15);
set(gcf,'Position',[605 197 484 781])
%%
saveas(f,'Figures/STAI.png')
