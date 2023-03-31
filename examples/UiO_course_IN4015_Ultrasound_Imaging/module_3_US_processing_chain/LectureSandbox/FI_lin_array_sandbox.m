%% Linear array  % Linear Scan
channel_data = uff.channel_data()
channel_data.read([data_path,filesep,'L7_FI_IUS2018.uff'],'/channel_data')


scan = uff.linear_scan()                            % Define UFF scan object
scan.x_axis = linspace(channel_data.probe.x(1),...  % Create x-axis
    channel_data.probe.x(end),channel_data.N_waves)';
scan.z_axis = linspace(5/1000,50/1000,512)';        % Create z-axis

mid=midprocess.das();tic();                                % Beamform image
mid.channel_data=channel_data;
mid.dimension = dimension.both();
mid.scan=scan;
mid.transmit_apodization.window=uff.window.scanline;
mid.receive_apodization.window=uff.window.none;
b_data = mid.go();toc();                         
b_data.plot([],[''],[],[],[],[],[],'dark');            % Display

%%
f = figure(12);clf
subplot(121)
imagesc(scan.x_axis*1000,scan.z_axis*1000,reshape(scan.x,scan.N_z_axis,scan.N_x_axis)*1000); 
title('x-pixels');
xlabel('x [mm]');ylabel('z [mm]');axis image; colormap default; colorbar
subplot(122)
imagesc(scan.x_axis*1000,scan.z_axis*1000,reshape(scan.z,scan.N_z_axis,scan.N_x_axis)*1000);title('z-pixels');
xlabel('x [mm]');ylabel('z [mm]');axis image; colormap default; colorbar
saveas(f,'examples/UiO_course_IN4015_Ultrasound_Imaging/module_3_US_processing_chain/Figures/pixels.png')

scan.plot()
f = gcf;
saveas(f,'examples/UiO_course_IN4015_Ultrasound_Imaging/module_3_US_processing_chain/Figures/scan.png')

%% Simple receive apodization
clear mid.receive_apodization
mid.receive_apodization.window=uff.window.boxcar;
mid.receive_apodization.f_number = 1.7;
%mid.receive_apodization.minimum_aperture = channel_data.probe.N*channel_data.probe.pitch;
%mid.receive_apodization.maximum_aperture = channel_data.probe.N*channel_data.probe.pitch;
mid.receive_apodization.data;
apod_data = reshape(mid.receive_apodization.data,scan.N_z_axis,scan.N_x_axis,channel_data.N_elements);
f = figure(88);clf;
subplot(121)
imagesc(1:128,scan.z_axis*1000,squeeze(apod_data(:,end/2,:)))
xlabel('Element');ylabel('z [mm]');colormap default; colorbar
subplot(122)
depth_pixel = 300;
plot(squeeze(apod_data(depth_pixel,end/2,:)),'LineWidth',2);hold on;
ylabel('Weight');xlabel('Element');title(['Apod at z = ',num2str(scan.z_axis(depth_pixel)*1000,'%.0f'),' [mm]']);
set(gca,'FontSize',15)


D = (channel_data.probe.pitch*channel_data.probe.N_elements)*1000
f_number = (40/1000)/(channel_data.probe.pitch*channel_data.probe.N_elements)
(channel_data.probe.pitch*channel_data.probe.N_elements)*1000*1.7


%saveas(f,'examples/UiO_course_IN4015_Ultrasound_Imaging/module_3_US_processing_chain/Figures/apod_expanding_linear.png')

%%

b_data_boxcar_expanding = mid.go();toc();                         
b_data.plot([],['1'],[],[],[],[],[],'dark');            % Display


%%

b_data_compare = uff.beamformed_data(b_data);
b_data_compare.data(:,2) = b_data_boxcar_expanding.data;
f = figure()
b_data_compare.plot(f,['1 = Full Hamming, 2 = Expanding Hamming'])
b_data_compare.save_as_gif('examples/UiO_course_IN4015_Ultrasound_Imaging/module_3_US_processing_chain/Figures/boxcar_vs_expanding_linear.gif');
%% Phased array % Sector Scan
channel_data = uff.read_object([data_path,filesep ,'FieldII_P4_point_scatterers.uff'],'/channel_data');

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
mid.receive_apodization.window=uff.window.boxcar;
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
D = (channel_data.probe.pitch*channel_data.probe.N_elements)*1000
f_number = (40/1000)/(channel_data.probe.pitch*channel_data.probe.N_elements)

%%
b_data_hamming_expanding = mid.go();toc();                         
b_data.plot([],['Point Scatters'],[],[],[],[],[],'dark');            % Display


%%

b_data_compare = uff.beamformed_data(b_data_hamming);
b_data_compare.data(:,2) = b_data_hamming_expanding.data;
f = figure()
b_data_compare.plot(f,['1 = Full Hamming, 2 = Expanding Hamming'])
b_data_compare.save_as_gif('examples/UiO_course_IN4015_Ultrasound_Imaging/module_3_US_processing_chain/Figures/hamming_vs_expanding.gif');