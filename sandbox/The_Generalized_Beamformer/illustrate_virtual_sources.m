
%% Checking the file is in the path
% data location
url = tools.zenodo_dataset_files_base();
% if not found data will be downloaded from here

filename_DW='L7_DW_IUS2023.uff';selected_tx = 1;tag = 'DW';
tools.download(filename_DW, url, data_path);
channel_data_DW=uff.read_object([data_path filesep filename_DW],'/channel_data');
channel_data_DW.N_frames = 1;

filename_STA='L7_STA_IUS2023.uff';selected_tx = 128;tag = 'STA';
channel_data_STA=uff.read_object([data_path filesep filename_STA],'/channel_data');
channel_data_STA.N_frames = 1;


%%
filename_PW ='L7_CPWC_IUS2023.uff';selected_tx = 1;tag = 'PW';
channel_data_PW=uff.read_object([data_path filesep filename_PW],'/channel_data');
channel_data_PW.N_frames = 1;
%%
% filename_FI='L7_FI_IUS2023.uff';selected_tx = 128;tag = 'FI';
% channel_data_FI=uff.read_object([data_path filesep filename_FI],'/channel_data');
% channel_data_FI.N_frames = 1;

%%

figure()
fig_handle = channel_data_DW.probe.plot();
for n = [1 7 15]
    fig_handle=channel_data_DW.sequence(n).source.plot(fig_handle);
    %set(fig_handle,'Color','b')
end
%%

for n = [1 64 128];
    fig_handle=channel_data_STA.sequence(n).source.plot(fig_handle);
end


for n = [1 7 15];
    fig_handle=channel_data_PW.sequence(n).source.plot(fig_handle);
end

quiver3(0,0,0,0,0,25,'off','Color','r','LineWidth',2)
text(1,0,25/2,num2str('T'),'Color','r','FontSize',15)

quiver3(0,0,25,-5,0,-25,'off','Color','k','LineWidth',2)
text(-4,0,25/2,num2str('R'),'Color','k','FontSize',15)
text(1,0,25,num2str('(x,y,z)'),'Color','k','FontSize',15)

%% Mock plot of FI until I have a new dataset
x = [channel_data_STA.probe.x(1) channel_data_STA.probe.x(64) channel_data_STA.probe.x(128)]
z = [30/1000 30/1000 30/1000]
y = [0 0 0]
for n = 1:3
    plot3(x*1e3,y*1e3,z*1e3,'mx','Linewidth',3,'MarkerSize',15); grid on; axis equal;
    xlabel('x[mm]'); ylabel('y[mm]'); zlabel('z[mm]');
    set(gca,'ZDir','Reverse');
    set(gca,'fontsize',14);
end

scan_linear = uff.linear_scan();
scan_linear.x_axis = linspace(channel_data_STA.probe.x(1),channel_data_STA.probe.x(end),32)';
scan_linear.z_axis = linspace(5/1000,60/1000,32)';
scan_linear.plot(fig_handle);


zlim([-20 50])
view([-23,21])
set(gcf,'Position',[322 50 940 946])

mkdir('Figures/illustrations/')
saveas(fig_handle,'Figures/illustrations/geometry.png')
saveas(fig_handle,'Figures/illustrations/geometry.eps','eps2c')


%%

fig_handle = channel_data_STA.probe.plot()
scan_linear = uff.linear_scan();
scan_linear.x_axis = linspace(channel_data_STA.probe.x(1),channel_data_STA.probe.x(end),32)';
scan_linear.z_axis = linspace(5/1000,60/1000,32)';
scan_linear.plot(fig_handle);
saveas(fig_handle,'Figures/illustrations/linear_scan.png')
saveas(fig_handle,'Figures/illustrations/linear_scan.eps','eps2c')
%%

figure();
fig_handle = channel_data_STA.probe.plot();
scan_sector = uff.sector_scan();
scan_sector.depth_axis =  linspace(5/1000,120/1000,32)';
scan_sector.azimuth_axis =  deg2rad(linspace(-30,30,32))';
scan_sector.plot(fig_handle);
saveas(fig_handle,'Figures/illustrations/sector_scan.png')
saveas(fig_handle,'Figures/illustrations/sector_scan.eps','eps2c')

%%
%%
figure();clf;
probe_2D = uff.matrix_array();
probe_2D.pitch_x = channel_data_STA.lambda;
probe_2D.pitch_y = channel_data_STA.lambda;
probe_2D.N_x = 128;
probe_2D.N_y = 128;
probe_2D.plot();
fig_handle = probe_2D.plot();
scan_linear_3D = uff.linear_scan_3D();
scan_linear_3D.x_axis = linspace(channel_data_STA.probe.x(1),channel_data_STA.probe.x(end),16)';
scan_linear_3D.y_axis = linspace(channel_data_STA.probe.x(1),channel_data_STA.probe.x(end),16)';
scan_linear_3D.z_axis = linspace(5/1000,60/1000,16)';
scan_linear_3D.plot(fig_handle);
saveas(fig_handle,'Figures/illustrations/linear_scan_3D.png')
saveas(fig_handle,'Figures/illustrations/linear_scan_3D.eps','eps2c')

%%
fig_handle = probe_2D.plot();
scan_sector = uff.sector_scan_3D();
scan_sector.depth_axis =  linspace(5/1000,120/1000,16)';
scan_sector.azimuth_axis =  deg2rad(linspace(-30,30,16))';
scan_sector.elevation_axis =  deg2rad(linspace(-30,30,16))';
scan_sector.plot(fig_handle);
saveas(fig_handle,'Figures/illustrations/sector_scan_3D.png')
saveas(fig_handle,'Figures/illustrations/sector_scan_3D.eps','eps2c')

% 
% scan=uff.linear_scan();
% scan.x_axis = linspace(channel_data.probe.x(1),channel_data.probe.x(end),512).';
% scan.z_axis = linspace(3e-3,50e-3,512).';
% scan.plot();
% title('Linear Scan');
% %saveas(gcf,'''Figures/linear_scan.png')