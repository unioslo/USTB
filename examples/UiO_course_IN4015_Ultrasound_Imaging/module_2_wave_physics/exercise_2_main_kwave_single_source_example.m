% Receive beamforming on k-wave single source exampler
%
% See the README.md in the current folder module_2_wave_physics
% 
% Author: Ole Marius Hoel Rindal
clearvars;
clear all;
close all;

% =========================================================================
% Run K-wave SIMULATION
% =========================================================================
% Set up some parameters
                       % Define how many receive sensors with lambda/2 spacing 
number_of_sensors = 4; % <------- CHANGE NUMBER OF ELEMENTS HERE 
dynamic_range = 40; % How many decibels to display in image
%transmit_signal = 'sinus';
transmit_signal = 'gaussian_pulse';

[channel_data, kgrid] = run_kwave_simulation(number_of_sensors,transmit_signal)

%%  
% Reconstructing an image of the single source using the USTB.

% Create scan UFF object to define the set of pixels we want to beamform
scan = uff.linear_scan();
scan.x_axis = linspace(kgrid.x_vec(1),kgrid.x_vec(end),1024)';
scan.z_axis = linspace(0,30e-3,1024)';

% Perform the beamforming using the DAS midprocess object
das = midprocess.das();
das.channel_data = channel_data;
das.scan = scan;
b_data = das.go()

% Visualise the image
f = figure(9)
b_data.plot(f,['Beamformed image using USTB'],[dynamic_range])

%% Part I : Your own receive beamforming
% Now, your assignment is to implement a receive beamformer. However, most
% of the code is allready written, so you simply have to get the receive
% delay correct (thus update the line that says <------ UPDATE THIS LINE)
% and your image should be similar to the one resulting from the USTB.

% Allow me to extract the variables you need
x_element_position = channel_data.probe.x; %The x-position of the elements
z_element_position = channel_data.probe.z; %The z-position of the elements

x_pixels = reshape(scan.x, scan.N_x_axis, scan.N_z_axis); %The x position of the pixels
z_pixels = reshape(scan.z', scan.N_x_axis, scan.N_z_axis); %The z position of the pixels

ch_data = hilbert(channel_data.data); %The raw channel data in analytical form

% Empty variables of correct dimension of variables you need to calculate
receive_delay = zeros(scan.N_x_axis,scan.N_z_axis,channel_data.N_elements);
delayed_data = zeros(scan.N_x_axis,scan.N_z_axis,channel_data.N_elements);
img = zeros(scan.N_x_axis,scan.N_z_axis);

for rx = 1:channel_data.N_elements
    % See equation (2) in Grythe, or equation (1.15) in Rindal (remember to convert (1.15) to seconds).
    receive_delay(:,:,rx) = -inf; % <------- UPDATE THIS LINE
    delayed_data(:,:,rx) = interp1(channel_data.time,ch_data(:,rx),receive_delay(:,:,rx),'linear',0);
    img = img + delayed_data(:,:,rx);
end

%% Plotting the image from the USTB and the resulting images from your beamformer
figure(10)
b_data.plot(subplot(121),['USTB image'],[dynamic_range])
subplot(122)
imagesc(scan.x_axis*1000,scan.z_axis*1000,db(abs(img./max(img(:)))))
xlabel('x [mm]');ylabel('z [mm]')
colormap gray; caxis([-dynamic_range 0])
colorbar; axis image;
title('Your image');
set(gca,'fontsize',14);

%% Part III: Visualize the channel data before and after delay for point scatter
% First of all, this plot is much better if you use e.g. 16 elements use the 
% *gausian_pulse* as the signal transmitted so make sure you use this towards the top of the script.
% Look for "<------- CHANGE NUMBER OF ELEMENTS HERE"
% 
% Your task here is to use the plot above to find the location of the point
% scatter. Use the cursor in the plot and find the maximum, and simply set
% the correct value in the variables below for the x and z locatino of the
% scatterer, also known as the point spread function (PSF).
%
% Describe what you see in the resulting figure and interpret the results.

psf_x_loc = 0/1000; % Find the x-location of the point scatter in m <------- UPDATE THIS LINE
psf_z_loc = 0/1000; % FInd the z-location of the point scatter in m <------- UPDATE THIS LINE

[~,scatter_pos_indx_x] = min(abs(scan.x_axis-psf_x_loc))
[~,scatter_pos_indx_z] = min(abs(scan.z_axis-psf_z_loc))

figure(11);clf;
subplot(231)
imagesc(1:channel_data.N_elements,channel_data.time*channel_data.sound_speed*1000,real(channel_data.data));hold on;
ylim([0 max(channel_data.time*channel_data.sound_speed*1000)])
plot(squeeze(receive_delay(scatter_pos_indx_z,scatter_pos_indx_x,:)*channel_data.sound_speed*1000),'r','LineWidth',2)
legend('Delay');
ylabel('Depth [mm]');xlabel('Element');
title('Received channel data before delay');
colormap default
subplot(234)
imagesc(1:channel_data.N_elements,scan.z_axis*1000,squeeze(real(delayed_data(:,end/2,:))));
ylabel('z [mm]');xlabel('Element');
title('Received channel data after delay');
colormap default

for e = 1:channel_data.N_elements
   ax{1} = subplot(232); hold on;
   element_data = channel_data.data(:,e)./max(channel_data.data(:,e))/2; %Normalized to max 0.5
   plot(channel_data.time*channel_data.sound_speed*1000,element_data+e);hold all;
   ylabel('Element');xlabel('Depth [mm]')
   xlim([0 max(channel_data.time*channel_data.sound_speed*1000)])
   ylim([0 channel_data.N_elements+1])
   title('Received channel data before delay');
   
   ax{2} = subplot(235); hold on;
   element_data = squeeze(real(delayed_data(:,end/2,e)))./max(squeeze(real(delayed_data(:,end/2,e))))/2; %Normalized to max 0.5
   plot(scan.z_axis*1000,element_data+e);hold all;
   ylabel('Element');xlabel('Depth [mm]')
   ylim([0 channel_data.N_elements+1])
   title('Received channel data after delay');
end
 
ax{3} = subplot(2,3,[3,6]);hold all;
plot(channel_data.time*channel_data.sound_speed*1000,sum(channel_data.data,2),'LineWidth',2,'DisplayName','Sum of undelayed data');
plot(scan.z_axis*1000,sum(squeeze(real(delayed_data(:,end/2,:))),2),'LineWidth',2,'DisplayName','Sum of delayed data');
xlim([0 max(channel_data.time*channel_data.sound_speed*1000)])
ylabel('Amplitude');xlabel('Depth [mm]');legend show
title('Combined channel data');

for a = 1:length(ax)
    set(ax{a},'YDir','reverse');
    set(ax{a},'XDir','reverse');
    camroll(ax{a},90)
end

%% Part IV: More indepth analysis of the partial and final results
% The next plot is displaying the spatial value of the x-value and z-value of the
% coordinates of the pixels.
figure(12);clf
subplot(211)
imagesc(scan.x_axis*1000,scan.z_axis*1000,x_pixels);title('x-pixels');
xlabel('x [mm]');ylabel('z [mm]');axis image; colormap default
subplot(212)
imagesc(scan.x_axis*1000,scan.z_axis*1000,z_pixels);title('z-pixels');
xlabel('x [mm]');ylabel('z [mm]');axis image; colormap default

%%
% Plot the delayed signal from each individual sensor. What is different
% between these images and the final image?
figure(13);clf;
for i = 1:number_of_sensors
    if number_of_sensors == 16
        subplot(number_of_sensors/4,number_of_sensors/4,i)
    elseif number_of_sensors == 4
        subplot(number_of_sensors/2,number_of_sensors/2,i)
    else
       warning('This plot looks best with 4 or 16 sensors :)');
       subplot(number_of_sensors/2,number_of_sensors/2,i)
    end
    imagesc(scan.x_axis*1000,scan.z_axis*1000,real(delayed_data(:,:,i)));
    xlabel('x [mm]');ylabel('z [mm]');
    title(['Delayed signal from sensor ',num2str(i)])
end


%%
% Plot the image before and after envelope detection
%
figure(14);clf
subplot(121)
imagesc(scan.x_axis*1000,scan.z_axis*1000,sum(real(delayed_data),3))
xlabel('x [mm]');ylabel('z [mm]'); title('Image of the signal before envelope detection');
axis image
subplot(122)
imagesc(scan.x_axis*1000,scan.z_axis*1000,db(abs(img./max(img(:)))))
xlabel('x [mm]');ylabel('z [mm]'); title('Image of the signal after envelope detection');
colormap gray; caxis([-dynamic_range 0])
axis image
