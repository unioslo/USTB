
%channel_data = uff.read_object([data_path,filesep ,'FieldII_P4_point_scatterers.uff'],'/channel_data');

%channel_data = uff.read_object([data_path,filesep ,'Verasonics_P2-4_parasternal_long_small.uff'],'/channel_data');

channel_data = uff.read_object([data_path,filesep ,'Verasonics_P2-4_parasternal_long_subject_1.uff'],'/channel_data');


%%
%channel_data.N_frames = 1;
depth_axis=linspace(0e-3,110e-3,1024).';                               % Define UFF scan object
azimuth_axis=linspace(channel_data.sequence(1).source.azimuth,...      % Define azimuth axis
    channel_data.sequence(end).source.azimuth,channel_data.N_waves)';
scan=uff.sector_scan('azimuth_axis',azimuth_axis,'depth_axis',depth_axis); % Define depth axis

mid=midprocess.das();tic();                                % Beamform image
mid.channel_data=channel_data;
mid.dimension = dimension.both();
mid.scan=scan;
mid.transmit_apodization.window=uff.window.scanline;
mid.receive_apodization.window=uff.window.hamming;
mid.receive_apodization.f_number=1.7
%%
b_data = mid.go();toc();                         
b_data.plot([],['Human Heart'],[],[],[],[],[],'dark');            % Display


%%
L = 64;
f = figure();hold on;
plot(hamming(L),'LineWidth',2,'DisplayName','Hamming');
plot(tukeywin(L),'LineWidth',2,'DisplayName','Tukey');
plot(boxcar(L),'LineWidth',2,'DisplayName','Boxcar');
legend show
xlabel('Elements');
ylabel('Weight');
%%
saveas(f,'examples/UiO_course_IN4015_Ultrasound_Imaging/module_3_US_processing_chain/Figures/apod_window.png')
%%
f = figure()
subplot(121)
x_matrix=reshape(scan.x,[scan(1).N_depth_axis scan(1).N_azimuth_axis]);
z_matrix=reshape(scan.z,[scan(1).N_depth_axis scan(1).N_azimuth_axis ]);
%h.all_images = reshape(envelope,[scan.N_depth_axis scan.N_azimuth_axis Nrx*Ntx*Nframes]);
h.image_handle = pcolor(x_matrix*1000,z_matrix*1000,x_matrix*1000); colorbar
title('x-pixels');
xlabel('x [mm]');ylabel('z [mm]');axis image; colormap default; colorbar
shading('flat');
set(gca,'fontsize',14);
set(gca,'YDir','reverse');
axis(gca,'tight','equal');
subplot(122)
x_matrix=reshape(scan.x,[scan(1).N_depth_axis scan(1).N_azimuth_axis]);
z_matrix=reshape(scan.z,[scan(1).N_depth_axis scan(1).N_azimuth_axis ]);
%h.all_images = reshape(envelope,[scan.N_depth_axis scan.N_azimuth_axis Nrx*Ntx*Nframes]);
h.image_handle = pcolor(x_matrix*1000,z_matrix*1000,z_matrix*1000); colorbar
xlabel('x [mm]');ylabel('z [mm]');axis image; colormap default; colorbar
title('z-pixels');
shading('flat');
set(gca,'fontsize',14);
set(gca,'YDir','reverse');
axis(gca,'tight','equal');
%%
saveas(f,'examples/UiO_course_IN4015_Ultrasound_Imaging/module_3_US_processing_chain/Figures/sector_scan_pixels.png')

%%


scan.plot()
f = gcf;
saveas(f,'examples/UiO_course_IN4015_Ultrasound_Imaging/module_3_US_processing_chain/Figures/sector_scan.png')

%%
f = figure(12);clf
subplot(121)
imagesc(rad2deg(scan.azimuth_axis),scan.depth_axis*1000,x_matrix*1000); 
title('x-pixels');
xlabel('azimuth [degrees]');ylabel('z [mm]'); colormap default; colorbar
subplot(122)
imagesc(rad2deg(scan.azimuth_axis),scan.depth_axis*1000,z_matrix*1000); 
title('z-pixels');
xlabel('azimuth [degrees]');ylabel('z [mm]'); colormap default; colorbar
saveas(f,'examples/UiO_course_IN4015_Ultrasound_Imaging/module_3_US_processing_chain/Figures/sector_scan_pixels_beamspace.png')

%%
clear mid.receive_apodization
mid.receive_apodization.window=uff.window.hamming;
mid.receive_apodization.f_number = 2;
%mid.receive_apodization.minimum_aperture = channel_data.probe.N*channel_data.probe.pitch;
mid.receive_apodization.maximum_aperture = channel_data.probe.N*channel_data.probe.pitch*4;
mid.receive_apodization.data;
apod_data = reshape(mid.receive_apodization.data,scan.N_depth_axis,scan.N_azimuth_axis,channel_data.N_elements);
f = figure(88);clf;
subplot(121)
imagesc(1:128,scan.depth_axis*1000,squeeze(apod_data(:,end/2,:)))
xlabel('Element');ylabel('z [mm]');colormap default; colorbar
set(gca,'FontSize',15)
subplot(122)
depth_pixel = 400;
plot(squeeze(apod_data(depth_pixel,end/2,:)),'LineWidth',2);hold on;
ylabel('Weight');xlabel('Element');title(['Apod at z = ',num2str(scan.depth_axis(depth_pixel)*1000,'%.0f'),' [mm]']);
set(gca,'FontSize',15)
saveas(f,'examples/UiO_course_IN4015_Ultrasound_Imaging/module_3_US_processing_chain/Figures/sector_scan_apod_hamming_expanding.png')
%%
b_data_hamming_expanding = mid.go();toc();                         
b_data.plot([],['Point Scatters'],[],[],[],[],[],'dark');            % Display


%%

b_data_compare = uff.beamformed_data(b_data_hamming);
b_data_compare.data(:,2) = b_data_hamming_expanding.data;
f = figure()
b_data_compare.plot(f,['1 = Full Hamming, 2 = Expanding Hamming'])
b_data_compare.save_as_gif('examples/UiO_course_IN4015_Ultrasound_Imaging/module_3_US_processing_chain/Figures/hamming_vs_expanding.gif');


%% Figures for the display

img = b_data.get_image('none');

f = figure;hold on;
plot(scan.depth_axis*1000,real(img(:,50))./max(real(img(:,50))),'DisplayName','The Signal')
plot(scan.depth_axis*1000,abs(img(:,50))./max(abs(img(:,50))),'LineWidth',2,'DisplayName','The Envelope')
axis tight;
xlabel('Depth [mm]');
ylabel('Normalized Amplitude')
%camroll(-90)
legend show
%%
saveas(f,'examples/UiO_course_IN4015_Ultrasound_Imaging/module_3_US_processing_chain/Figures/signal_envelope_zoom.png');


%%
f = figure
imagesc(rad2deg(scan.azimuth_axis),scan.depth_axis*1000,abs(img)./max(abs(img(:))));
colorbar
xlabel('Azimuth axis');
ylabel('Depth axis');
colormap gray
caxis([0 0.5])
title('Raw image of envelope');
saveas(f,'examples/UiO_course_IN4015_Ultrasound_Imaging/module_3_US_processing_chain/Figures/raw_envelope_image_caxis.png');


%% Display logaritmic compression
input = linspace(0,1,1024)

f = figure
plot(input,20*log10(input),'Linewidth',2)
xlabel('Input signal (Linear Scale)');
ylabel('Output signal (dB Scale)')
title('Logaritmic compression');


saveas(f,'examples/UiO_course_IN4015_Ultrasound_Imaging/module_3_US_processing_chain/Figures/logaritmic_compression.png');

%%
img = b_data.get_image('none');

f = figure;hold on;
subplot(121);hold on;
plot(scan.depth_axis*1000,real(img(:,50))./max(real(img(:,50))),'DisplayName','The Signal')
plot(scan.depth_axis*1000,abs(img(:,50))./max(abs(img(:,50))),'LineWidth',2,'DisplayName','The Envelope')
axis tight;
xlabel('Depth [mm]');
ylabel('Normalized Amplitude')
legend show
ax(1) = gca;
subplot(122)
%plot(scan.depth_axis*1000,real(img(:,50))./max(real(img(:,50))),'DisplayName','The Signal')
plot(scan.depth_axis*1000,db(abs(img(:,50))./max(abs(img(:,50)))),'LineWidth',2,'DisplayName','20*log10(envelope)')
axis tight;
xlabel('Depth [mm]');
ylabel('Normalized Amplitude')
legend show
ax(2) = gca;
linkaxes('x',ax)
%%
saveas(f,'examples/UiO_course_IN4015_Ultrasound_Imaging/module_3_US_processing_chain/Figures/logaritmic_compression_single_line.png');


%%

f = figure
subplot(121)
imagesc(rad2deg(scan.azimuth_axis),scan.depth_axis*1000,abs(img)./max(abs(img(:))));
colorbar
xlabel('Azimuth axis');
ylabel('Depth axis');
colormap gray
title('Raw image of envelope');
subplot(122)
imagesc(rad2deg(scan.azimuth_axis),scan.depth_axis*1000,db(abs(img)./max(abs(img(:)))));
colorbar
xlabel('Azimuth axis');
ylabel('Depth axis');
colormap gray
title('Image after log-compression');
%%
saveas(f,'examples/UiO_course_IN4015_Ultrasound_Imaging/module_3_US_processing_chain/Figures/raw_envelope_and_log_compression_img.png');


%%
f = figure
subplot(122)
imagesc(rad2deg(scan.azimuth_axis),scan.depth_axis*1000,db(abs(img)./max(abs(img(:)))));
colorbar
colormap gray
xlabel('Azimuth axis');
ylabel('Depth axis');
caxis([-60 0])
%%
title('Dynamic Range = [0,-60]')
saveas(f,'examples/UiO_course_IN4015_Ultrasound_Imaging/module_3_US_processing_chain/Figures/dynamic_range.png');

%%


%%
             
b_data.plot([],['Human Heart'],[],[],[],[],[],'dark');            % Display
caxis([-60 0]-20)

b_data.save_as_gif('examples/UiO_course_IN4015_Ultrasound_Imaging/module_3_US_processing_chain/Figures/heart_some_gain.gif');
