%% Computation of a FI dataset with Field II using a 2D array and beamforming with USTB
%
% authors:  Ole Marius Hoel Rindal <olemarius@olemarius.net>
%
% Last updated: 12.11.2017
clear all;
close all;

save_folder = '2D_array_STAI_simulation'
N_transmit = 3;
%%
channel_data = uff.channel_data();
channel_data.read([save_folder,'/channel_data_tx_',num2str(1)],'/channel_data')

for n=1:N_transmit
    channel_data_temp = uff.channel_data();
    channel_data_temp.read([save_folder,'/channel_data_tx_',num2str(n)],'/channel_data')
    channel_data.sequence(n) = channel_data_temp.sequence;
    channel_data.data(:,:,n) = channel_data_temp.data;
end

%% Create Sector scan
scan = uff.linear_scan();
scan.x_axis = linspace(-35/1000,35/1000,256)';
scan.z_axis = linspace(40/1000,90/1000,256)';
scan.y =  0.*ones(size(scan.y))*channel_data.probe.y(1);%-5/1000;

%% BEAMFORMER
mid=midprocess.das();
mid.channel_data=channel_data;
mid.dimension = dimension.both()
mid.scan=scan;
mid.spherical_transmit_delay_model = spherical_transmit_delay_model.spherical;
mid.receive_apodization.window=uff.window.hamming;
mid.receive_apodization.f_number=1.5;
mid.transmit_apodization.window=uff.window.none;
mid.transmit_apodization.f_number=3;

% Delay the data
f = figure()
b_data_3D_RTB = mid.go();
b_data_3D_RTB.plot(f);
saveas(f,'test_image.png')

%% Visualize apodization
b_data_tx_apod = uff.beamformed_data(b_data_3D_RTB)
b_data_tx_apod.data = mid.transmit_apodization.data;

%% Test with 3D scan
scan_3D_linear = uff.linear_scan_3D;
scan_3D_linear.x_axis = linspace(-10/1000,10/1000,25)';
scan_3D_linear.y_axis = linspace(-10/1000,10/1000,25)';
scan_3D_linear.z_axis = linspace(0/1000,110/1000,256)';
scan_3D_linear.plot()

%%
scan_3D_sector = uff.sector_scan_3D;
scan_3D_sector.azimuth_axis = deg2rad(linspace(-30,30,32))';
scan_3D_sector.elevation_axis = deg2rad(linspace(-30,30,32))';
scan_3D_sector.depth_axis = linspace(0/1000,110/1000,256)';
scan_3D_sector.plot()

%%
mid.scan = scan_3D_linear;
mid.dimension = dimension.both();
b_data_3D_linear = mid.go()
img_3D_linear = reshape(b_data_3D_linear.data,scan_3D_linear.N_z_axis,scan_3D_linear.N_x_axis,scan_3D_linear.N_y_axis);
img_3D_linear = img_3D_linear./max(img_3D_linear(:));

%%
mid.scan = scan_3D_sector;
mid.dimension = dimension.both();
b_data_3D_sector = mid.go()

%%
img_3D_sector= reshape(b_data_3D_sector.data,scan_3D_sector.N_depth_axis,scan_3D_sector.N_azimuth_axis,scan_3D_sector.N_elevation_axis);
img_3D_sector = img_3D_sector./max(img_3D_sector(:));

%%

x_cube_spher = reshape(b_data_3D_sector.scan.x,b_data_3D_sector.scan.N_depth_axis,b_data_3D_sector.scan.N_azimuth_axis,b_data_3D_sector.scan.N_elevation_axis);
y_cube_spher = reshape(b_data_3D_sector.scan.y,b_data_3D_sector.scan.N_depth_axis,b_data_3D_sector.scan.N_azimuth_axis,b_data_3D_sector.scan.N_elevation_axis);
z_cube_spher = reshape(b_data_3D_sector.scan.z,b_data_3D_sector.scan.N_depth_axis,b_data_3D_sector.scan.N_azimuth_axis,b_data_3D_sector.scan.N_elevation_axis);
% 
x_cube_cart = reshape(b_data_3D_linear.scan.x,b_data_3D_linear.scan.N_z_axis,b_data_3D_linear.scan.N_x_axis,b_data_3D_linear.scan.N_y_axis);
y_cube_cart = reshape(b_data_3D_linear.scan.y,b_data_3D_linear.scan.N_z_axis,b_data_3D_linear.scan.N_x_axis,b_data_3D_linear.scan.N_y_axis);
z_cube_cart = reshape(b_data_3D_linear.scan.z,b_data_3D_linear.scan.N_z_axis,b_data_3D_linear.scan.N_x_axis,b_data_3D_linear.scan.N_y_axis);

%% Plot 3D plot
f = figure(90);clf;hold all;
idx_x = 20;
idx_y = 20;
idx_z = 200;
surface(squeeze(x_cube_cart(:,:,idx_x)),squeeze(y_cube_cart(:,:,idx_x)),squeeze(z_cube_cart (:,:,idx_x)),db(abs(squeeze(img_3D_linear(:,:,idx_x)./max(max(img_3D_linear(:)))))));
surface(squeeze(x_cube_cart(:,idx_y,:)),squeeze(y_cube_cart(:,idx_y,:)),squeeze(z_cube_cart (:,idx_y,:)),db(abs(squeeze(img_3D_linear(:,idx_y,:)./max(max(img_3D_linear(:)))))));
%alpha 0.5
%surface(squeeze(z_cube_spher(idx_z,:,:)),squeeze(z_cube_spher(idx_z,:,:)),squeeze(z_cube_spher (idx_z,:,:)),db(abs(squeeze(img_3D_linear(idx_z,:,:)./max(max(img_3D_linear(:)))))));
surface(squeeze(x_cube_spher(:,idx_y,:)),squeeze(y_cube_spher(:,idx_y,:)),squeeze(z_cube_spher (:,idx_y,:)),db(abs(squeeze(img_3D_sector(:,idx_y,:)./max(max(img_3D_sector(:)))))));
axis image; title('3D','Color','white');
xlabel('x [mm]');ylabel('y [mm]');zlabel('z [mm]');
shading('flat');colormap gray; clim([-60 0]);view(40,0)
set(gca,'YColor','white','XColor','white','ZColor','white','Color','k');
set(gcf,'color','black'); set(gca,'Color','k')
f_handle = gcf;set(gca,'ZDir','reverse')
f_handle.InvertHardcopy = 'off';

%% Plot 3D plot
f = figure(91);clf;hold all;
idx_x = size(y_cube_spher,3)/2;
idx_y = size(y_cube_spher,2)/2;
idx_z = 200;
surface(squeeze(x_cube_spher(:,idx_y,:)),squeeze(y_cube_spher(:,idx_y,:)),squeeze(z_cube_spher (:,idx_y,:)),db(abs(squeeze(img_3D_sector(:,idx_y,:)./max(max(img_3D_sector(:)))))));
surface(squeeze(x_cube_spher(:,:,idx_x)),squeeze(y_cube_spher(:,:,idx_x)),squeeze(z_cube_spher (:,:,idx_x)),db(abs(squeeze(img_3D_sector(:,:,idx_x)./max(max(img_3D_sector(:)))))));
axis image; title('3D','Color','white');
xlabel('x [mm]');ylabel('y [mm]');zlabel('z [mm]');
shading('flat');colormap gray; clim([-60 0]);view(40,0)
set(gca,'YColor','white','XColor','white','ZColor','white','Color','k');
set(gcf,'color','black'); set(gca,'Color','k')
f_handle = gcf;set(gca,'ZDir','reverse')
f_handle.InvertHardcopy = 'off';