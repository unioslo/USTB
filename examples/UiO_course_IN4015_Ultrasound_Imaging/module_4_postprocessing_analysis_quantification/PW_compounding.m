%% Coherent and incoherent compounding
%
%   See the README.md in the current folder
%   module_4_postprocessing_analysis_quantification.
%
%   Author: Ole Marius Hoel Rindal <olemarius@olemarius.net>
%   Update 05.10.2022

clear all;
close all;

%% Getting the data
% We define the local path and the url where the data is stored

% data location
url='http://ustb.no/datasets/';      % if not found data will be downloaded from here
filename='PICMUS_experiment_resolution_distortion.uff';
filename='PICMUS_simulation_contrast_speckle.uff';

% checks if the data is in your data path, and downloads it otherwise.
% The defaults data path is under USTB's folder, but you can change this
% by setting an environment variable with setenv(DATA_PATH,'the_path_you_want_to_use');
tools.download(filename, url, data_path);

%% Loading channel data
channel_data=uff.read_object([data_path filesep filename],'/channel_data');

%% Defining an appropriate scan
scan=uff.linear_scan()
scan.x_axis = linspace(channel_data.probe.x(1),channel_data.probe.x(end),512)';
scan.z_axis = linspace(5e-3,50e-3,512)';

%% Set up the delay-and-sum beamforming using the midprocess
das = midprocess.das()
das.scan = scan;
das.channel_data = channel_data;
das.dimension = dimension.receive();
das.receive_apodization.window = uff.window.tukey50;
das.receive_apodization.f_number = 1.7;
das.transmit_apodization.window = uff.window.none;
b_data_all = das.go()

%% Finally, we will plot the individual plane wave images using the built in
% plot function in USTB
b_data_all.plot([],['Individual PW images'],[],[],[],[],[],'dark')

%% Exercise part I
% Now, in this exercise you are going to explore coherent and incoherent
% compounding of the individual plane wave images. See section 1.7.3 and
% 1.7.4 the compendium "Software Beamforming in Medical Ultrasound Imaging"
% Note: the weight w is 1 in both cases here.

% First, let us get all the individual plane wave images in one matrix. The
% "none" argument means that we get the beamformed but complex data. Thus
% the data before envelope detection and log compression.
image_matrix = b_data_all.get_image('none');

% Let us verify that the size of the matrix is 512x512x75 since the number
% of x-pixels is 512, the number of z-axis is 512 and the number of
% transmits, thus individual plane waves are 75
size(image_matrix)

scan.N_x_axis
scan.N_z_axis
channel_data.N_waves

%% Let us define some empty variables to contain the values you calculate
single_image = zeros(scan.N_x_axis,scan.N_z_axis);
coherent_compounding = zeros(scan.N_x_axis,scan.N_z_axis);
incoherent_compounding = zeros(scan.N_x_axis,scan.N_z_axis);
mix_compounding = zeros(scan.N_x_axis,scan.N_z_axis);

% Extract single image
single_image = db(abs(image_matrix(:,:,37)./max(max(image_matrix(:,:,37)))));

% Create coherent compounded image
coherent_compounding;           % <---- Implement coherent compounding here

% Create incoherent compounded image
incoherent_compounding;         % <---- Implement incoherent compounding here

%% Verify your implementation of coherent and incoherent compounding
% Using changing the dimension to "both" to get coherent compounding
das.dimension = dimension.both()
b_data_coherent = das.go();
b_data_coherent.plot([],['USTB Coherent Compounding using midprocess'])

% Alternatively one can use the coherent compounding postprocess object
cc = postprocess.coherent_compounding();
cc.input = b_data_all;
b_data_coherent = cc.go();
b_data_coherent.plot([],['USTB Coherent Compounding using postprocess'])
coherent_compounding_USTB = b_data_coherent.get_image();

% Using the postprocess incoherent_compunding
ic = postprocess.incoherent_compounding()
ic.input = b_data_all;
b_data_incoherent = ic.go()
b_data_incoherent.plot([],['USTB Incoherent Compounding'])
incoherent_compounding_USTB = b_data_incoherent.get_image();

%% Exercise Part II: Comparing your implementation to the USTB implementation
% Now, you need to plot and verify that your implementation is similar to
% the images obtained with the USTB. You can do this in a similar matter to
% how you compared your implementation of beamforming in module 3.
% NB! Due to small numerical differences you can accept a small numerical
% difference between the images and tolerate a pixel difference of
% e.g. abs(img_1_dB - img_2_dB) < 10^-4

%% Compare your implementation of coherent compounding to the USTB

%% Compare your implementation of incoherent compounding to the USTB

%% Exercise Part III : Implement a mix of coherent and incoherent compounding
% We can also do something inbetween full coherent and incoherent
% compounding. We can for example split the low quality images into two parts,
% and sum the different halfs coherently, before summing those two images
% incoherently. If you for example split the transmit angles into two as:

angles_first_sum = 1:channel_data.N_waves/2;
angles_second_sum = round(channel_data.N_waves/2)+1:channel_data.N_waves;

% And then sum the plane wave images resulting from the angles_first_sum
% coherently but separately, and then angles_second_sum coherently but separately.
% Before they both are combined incoherently. Thus you have done mix
% compounding. You can put the results in the mix_compounding variable:

mix_compounding; % <---- Implement coherent compounding here. You might need more than one line


figure()
subplot(221)
imagesc(scan.x_axis*1000, scan.z_axis*1000, single_image)
colormap gray; axis image;colorbar; caxis([-60 0])
title('Single transmit');
subplot(222)
imagesc(scan.x_axis*1000, scan.z_axis*1000, coherent_compounding)
colormap gray; axis image;colorbar; caxis([-60 0])
title('Coherent Compounding')
subplot(223)
imagesc(scan.x_axis*1000, scan.z_axis*1000, incoherent_compounding)
colormap gray; axis image;colorbar;  caxis([-60 0])
title('Incoherent Compounding')
subplot(224)
imagesc(scan.x_axis*1000, scan.z_axis*1000, mix_compounding)
colormap gray; axis image;colorbar;  caxis([-60 0])
title('Mix Compounding')
    
%% Exercise Part IV : Compare the resoluting resolution from coherent, incoherent and mix compounding
% Below, we provide the code to plot the lateral line, the line along the
% x-axis, through the point scatter at 19 mm. Often resolution is measured
% as the Full Width Half Maximum (FWHM) equal to the width at -6 dB.
% Improved resolution means smaller width of the point scatter.
% Discuss how the different compounding strategies influenced the resolution
% of this point scatter.
%
% You need to make sure you are running this on the resolution dataset
if contains(filename,'resolution')
    line = 156;
    
    figure();hold all;
    plot(scan.x_axis*1000,single_image(line,:),'LineWidth',2,'DisplayName','Single Transmit Image');hold on;
    plot(scan.x_axis*1000,coherent_compounding(line,:),'LineWidth',2,'DisplayName','Coherent Compounding');hold on;
    plot(scan.x_axis*1000,incoherent_compounding(line,:),'LineWidth',2,'DisplayName','Incoherent Compounding');
    plot(scan.x_axis*1000,mix_compounding(line,:),'LineWidth',2,'DisplayName','Mix Compounding');
    plot(scan.x_axis*1000,ones(1,scan.N_x_axis)*-6,'r--','LineWidth',2,'DisplayName','- 6dB (FWHM)')
    xlim([-3 3]);ylim([-40 0])
    legend;
    xlabel('x [mm]'); ylabel('Amplitude [dB]')
    title(['Lateral line through point scatterer at ',num2str(scan.z_axis(line)*1000,2),' mm']);
    
end

%% Exercise Part V : Measure the contrast
% Measure the contrast of the resulting images using the contrast ratio (CR)
% and the contrast-to-noise ratio (CNR). You should measure the contrast of the
% single plane wave image and the three different compounding techniques and discuss the results.
% The implementation to measure the CR is allready provided, but you have to calculate the CNR.
%
% You need to make sure that you are running this on the contrast dataset.

if contains(filename,'contrast')
    xc_ROI = -0;
    zc_ROI = 30;
    r_ROI = 3;
    r_background_inner = 5;
    r_background_outer = 7.5;
    
    
    % Create masks to mask out the ROI of the cyst and the background.
    for p = 1:length(scan.z_axis)
        positions(p,:,1) = scan.x_axis;
    end
    
    for p = 1:length(scan.x_axis)
        positions(:,p,2) = scan.z_axis;
    end
    points = ((positions(:,:,1)-xc_ROI*10^-3).^2) + (positions(:,:,2)-zc_ROI*10^-3).^2;
    idx_ROI = (points < (r_ROI*10^-3)^2);
    idx_background_outer =  (((positions(:,:,1)-xc_ROI*10^-3).^2) + (positions(:,:,2)-zc_ROI*10^-3).^2 < (r_background_outer*10^-3)^2); %ROI speckle
    idx_background_inner =  (((positions(:,:,1)-xc_ROI*10^-3).^2) + (positions(:,:,2)-zc_ROI*10^-3).^2 < (r_background_inner*10^-3)^2); %ROI speckle
    idx_background_outer(idx_background_inner) = 0;
    idx_background = idx_background_outer;
    
    
    % Display the mask and the images with the mask applied of the background
    % and ROI.
    figure;
    subplot(221)
    imagesc(scan.x_axis*1000, scan.z_axis*1000, idx_background)
    axis image; xlabel('x [mm]'); ylabel('z [mm]'); title('Background region')
    subplot(222)
    imagesc(scan.x_axis*1000, scan.z_axis*1000, idx_background.*single_image)
    colormap gray; caxis([-60 0]); axis image; xlabel('x [mm]'); ylabel('z [mm]'); title('Background image values')
    subplot(223)
    imagesc(scan.x_axis*1000, scan.z_axis*1000, idx_ROI)
    axis image; axis image; xlabel('x [mm]'); ylabel('z [mm]'); title('ROI region')
    subplot(224)
    imagesc(scan.x_axis*1000, scan.z_axis*1000, idx_ROI.*single_image)
    colormap gray; caxis([-60 0]); axis image; xlabel('x [mm]'); ylabel('z [mm]'); title('ROI image values')
    
    % We need to extract the signal before log compression and envelope detection
    % To make sure we get the signal I have used the USTB results, but feel
    % free to exchange with your solution and add your mixed compounding
    
    % First, let's get the images as one vector to easier "look up" the
    % region of background and ROI
    single_image_signal = image_matrix(:,:,37);
    single_image_signal = single_image_signal(:);
    coherent_compounding_signal = b_data_coherent.data;
    incoherent_compounding_signal = b_data_incoherent.data;
    %mix_compounding_signal = mix_compounding_signal(:);
    
    % Estimate the mean and the background of all images
    mean_background_single = mean(abs(single_image_signal(idx_background(:))).^2)
    mean_ROI_single = mean(abs(single_image_signal(idx_ROI(:))).^2)

    mean_background_coherent = mean(abs(coherent_compounding_signal(idx_background(:))).^2)
    mean_ROI_coherent = mean(abs(coherent_compounding_signal(idx_ROI(:))).^2)
    
    mean_background_incoherent = mean(abs(incoherent_compounding_signal(idx_background(:))).^2)
    mean_ROI_incoherent = mean(abs(incoherent_compounding_signal(idx_ROI(:))).^2)
    
    %mean_background_mix = mean(abs(mix_compounding_signal(idx_background(:))).^2)
    %mean_ROI_mix = mean(abs(mix_compounding_signal(idx_ROI(:))).^2)
    
    % Calculate Contrast Ratio
    CR_single = 10*log10(mean_ROI_single/mean_background_single)
    CR_coherent = 10*log10(mean_ROI_coherent/mean_background_coherent)
    CR_incoherent = 10*log10(mean_ROI_incoherent/mean_background_incoherent)
    %CR_mix = 10*log10(mean_ROI_mix/mean_background_mix)

    figure
    bar([CR_single CR_coherent CR_incoherent])% CR_mix])
    set(gca, 'YDir','reverse')
    xticklabels({'Single Image','Coherent Compounded','Incoherent Compounding'})%, 'Mix Compounding'})
    ylabel('CR [dB]')
    
    
    % You need to calculate the CNR
    
    
end