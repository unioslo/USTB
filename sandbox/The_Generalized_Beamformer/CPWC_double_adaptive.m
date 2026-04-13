%% Getting channel data
%
clear all;
close all;


%% Choose adaptive algoritm
MINIMUM_VARIANCE = true;
PHASE_COHERENCE_FACTOR = false;
SHORT_LAG_SPATIAL_COHERENCE = false;

% data location
url = tools.zenodo_dataset_files_base();

filename='PICMUS_numerical_calib_v2.uff'; data_label = 'CPWC';
%filename='FieldII_STAI_dynamic_range.uff';
%filename='L7_FI_IUS2018.uff'; data_label = 'RTB';
%filename='P4_2v_DW134847.uff'; data_label = 'DW';

% checks if the data is in your data path, and downloads it otherwise.
% The defaults data path is under USTB's folder, but you can change this
% by setting an environment variable with setenv(DATA_PATH,'the_path_you_want_to_use');
tools.download(filename, url, data_path);   

%filename = [data_path() filesep '']; 
channel_data = uff.channel_data();
channel_data.read([data_path,filesep,filename],'/channel_data');


%%
if strcmp(data_label,'RTB')
    MLA = 4;
    scan=uff.linear_scan('x_axis',linspace(channel_data.sequence(1).source.x,channel_data.sequence(end).source.x,channel_data.N_waves.*MLA).', 'z_axis', linspace(10e-3,50e-3,256).');
elseif strcmp(data_label,'DW')
    depth_axis=linspace(20e-3,90e-3,512).';
    angles_axis = linspace(deg2rad(-40),deg2rad(40),128);
    scan=uff.sector_scan('azimuth_axis',angles_axis.','depth_axis',depth_axis);
else
    scan=uff.linear_scan('x_axis',linspace(-20e-3,20e-3,512).', 'z_axis', linspace(10e-3,50e-3,256).');
    %scan=uff.linear_scan('x_axis',linspace(0e-3,15e-3,256).', 'z_axis', linspace(23e-3,27e-3,256).');
end

% pipeline
pipe = pipeline();

pipe.channel_data=channel_data;
pipe.scan=scan;

pipe.transmit_apodization.probe = channel_data.probe;
pipe.transmit_apodization.sequence = channel_data.sequence;
pipe.transmit_apodization.focus= scan;
pipe.transmit_apodization.window=uff.window.boxcar;
pipe.transmit_apodization.minimum_aperture = [3.07000e-03 3.07000e-03];
pipe.transmit_apodization.f_number=1.75;

pipe.receive_apodization.probe = channel_data.probe;
pipe.receive_apodization.focus= scan;
pipe.receive_apodization.window=uff.window.tukey75;
pipe.receive_apodization.f_number=1.0;

% By calling these we do the calculation of the apodization here
% and thus not affecting the timing later on.
%pipe.transmit_apodization.data;
%pipe.receive_apodization.data;

das=midprocess.das();
%das.pw_margin = 1e-3;
%%

adapt_rx = postprocess.capon_minimum_variance();
adapt_rx.dimension = dimension.receive;
adapt_rx.scan = scan;
adapt_rx.channel_data = channel_data;
adapt_rx.K_in_lambda = 1.5;
adapt_rx.L_elements = round(channel_data.probe.N/2);
adapt_rx.regCoef = 1/100;

adapt_tx = postprocess.capon_minimum_variance();
adapt_tx.dimension = dimension.transmit;
adapt_tx.scan = scan;
adapt_tx.channel_data = channel_data;
adapt_tx.K_in_lambda = 1.5;
adapt_tx.L_elements = channel_data.probe.N/2;
adapt_tx.regCoef = 1/100;

compression = 'log';
adapt_label = 'MV'
dynamic_range = 60;




%% DAS on RX -> DAS on Tx : Conventional
das.dimension = dimension.both;
%das.code = code.matlab
% Reset the hash so that everything is recalculated
%das.reset_hash();

pipe.transmit_apodization.probe = channel_data.probe;
pipe.transmit_apodization.sequence = channel_data.sequence;
pipe.transmit_apodization.focus= scan;
pipe.transmit_apodization.window=uff.window.boxcar;
pipe.transmit_apodization.f_number=1.75;

tic()
img{1} = pipe.go({das});
if strcmp(data_label,'RTB')
     img{1}.data = img{1}.data.*1./sum(pipe.transmit_apodization.data,2);
end
time{1}  = toc()
label{1} = ['DASonRX->DASonTX'];

img{1}.plot()
%% Adapt on Rx -> DAS on Tx
das.dimension = dimension.none;
pipe.transmit_apodization.window=uff.window.none;


tic()
b_data_temp = pipe.go({das adapt_rx});

%%
das_tx=postprocess.coherent_compounding();
das_tx.dimension = dimension.transmit;
das_tx.input = b_data_temp;

pipe.transmit_apodization.probe = channel_data.probe;
pipe.transmit_apodization.sequence = channel_data.sequence;
pipe.transmit_apodization.focus= scan;
pipe.transmit_apodization.window=uff.window.hamming;
pipe.transmit_apodization.f_number=2.0;
das_tx.transmit_apodization = pipe.transmit_apodization

img{2} = das_tx.go()

time{2}  = toc();
label{2} = [adapt_label,'onRX->DASonTX'];

img{2}.plot()

%% DAS on Rx -> Adapt on Tx
das.dimension = dimension.receive;

das.transmit_apodization.probe = channel_data.probe;
das.transmit_apodization.sequence = channel_data.sequence;
das.transmit_apodization.focus= scan;
das.transmit_apodization.window=uff.window.none;
das.transmit_apodization.f_number=2.0;


adapt_tx.L_elements = floor(channel_data.N_waves/3);
adapt_tx.regCoef = 1/100;
pipe.transmit_apodization.window=uff.window.none;

% Reset the hash so that everything is recalculated
%das.reset_hash();

tic()
img{3} = pipe.go({das adapt_tx});
time{3}  = toc()
label{3} = ['DASonRX->',adapt_label,'onTX'];


%% Adapt on Rx -> Adapt on Tx : Double adaptive
das.dimension = dimension.none;

if MINIMUM_VARIANCE
    adapt_tx.L_elements = floor(channel_data.N_waves/3);
    adapt_tx.regCoef = 1/100;
    %pipe.transmit_apodization.window=uff.window.none;
end

% Reset the hash so that everything is recalculated
%das.reset_hash();
%adapt_rx.reset_hash();
%adapt_tx.reset_hash();

tic();
img{4} = pipe.go({das adapt_rx adapt_tx});
time{4}  = toc()

label{4} = [adapt_label,'onRX->',adapt_label,'onTX'];

%% DAS on TX -> Adapt on RX
das.dimension = dimension.transmit;

%pipe.receive_apodization.plot




if MINIMUM_VARIANCE
    %adapt_rx.L_elements = 
    %adapt_rx.regCoef = 1/100;

    adapt_rx = postprocess.capon_minimum_variance();
    adapt_rx.dimension = dimension.receive;
    adapt_rx.scan = scan;
    adapt_rx.channel_data = channel_data;
    adapt_rx.K_in_lambda = 2;
    adapt_rx.L_elements = floor(channel_data.probe.N_elements/2); %floor(channel_data.probe.N_elements/2);% 
    adapt_rx.regCoef = 1/100;

end
    

tic()
img{5} = pipe.go({das adapt_rx});
if strcmp(data_label,'RTB')
     img{5}.data = img{5}.data.*1./sum(pipe.transmit_apodization.data,2);
end
time{5} = toc()
label{5} = ['DASonTX->',adapt_label, 'onRX'];
%%
img{1}.plot([],'DAS')
img{2}.plot([],'MV*S')
img{5}.plot([],'MV')

%%



img{5}.plot(figure(123),label{5},dynamic_range,compression);



%% Plot Figure
figure(3);
img{1}.plot(subplot(321),label{1},dynamic_range,compression)
ax(1) = gca;
img{2}.plot(subplot(322),label{2},dynamic_range,compression)
ax(2) = gca;
img{3}.plot(subplot(323),label{3},dynamic_range,compression);
ax(3) = gca;
img{4}.plot(subplot(324),label{4},dynamic_range,compression);
ax(4) = gca;
img{5}.plot(subplot(325),label{5},dynamic_range,compression);
ax(5) = gca;
linkaxes(ax);
subplot(3,2,[6]);
bar([time{:}]/60)
xticklabels(label)
ylabel('Computation time (m)');
set(gca,'FontSize',14);
set(gcf,'Position',[29 33 1109 715]);

%%

%% Plot Figure - Workaround for MATLAB R2025+
figure(3); clf;

for i = 1:5
    ax(i) = subplot(3,2,i);
    img_data = img{i}.get_image(compression);
    imagesc(img{i}.scan.x_axis*1e3, img{i}.scan.z_axis*1e3, img_data);
    colormap(ax(i), 'gray'); 
    caxis([-dynamic_range 0]); 
    axis image;
    colorbar;
    xlabel('x [mm]'); ylabel('z [mm]');
    title(label{i});
    set(gca, 'YDir', 'reverse');
end

linkaxes(ax);

subplot(3,2,6);
bar([time{:}]/60)
xticklabels(label)
ylabel('Computation time (m)');
set(gca,'FontSize',14);
set(gcf,'Position',[29 33 1109 715]);

%%
folder_path = ['figures'];
mkdir(folder_path)

b_data_compare = uff.beamformed_data(img{1})
b_data_compare.data(:,1,1,1) = img{1}.data;
close all;
for i = 1:length(img)
    b_data_compare.data(:,1,1,i) = img{i}.data./max(img{i}.data);
    f = figure(i);clf;
    imagesc(scan.x_axis*1000,scan.z_axis*1000,img{i}.get_image(compression));
    colormap gray; caxis([-dynamic_range 0]);axis image;
    xlabel('x [mm]');ylabel('y [mm]');
    set(gca,'FontSize',14)
    img{i}.plot(f,[],dynamic_range,compression)
    saveas(f,[folder_path,filesep,strrep(label{i}, '->', '_')],'eps2c')
    axis([0 10 20 28]);
    saveas(f,[folder_path,filesep,strrep(label{i}, '->', '_'),'_zoomed'],'eps2c')
end

%%
b_data_compare.plot()
%%
running_time_in_m = [time{:}]/60;
f99 = figure(100);clf;
%subplot(1,2,1);
bar([time{:}]/60)

labels_latex{1} = ['$b^{\overline{T_{x DAS}}~\overline{R_{x DAS}}}$'];
labels_latex{2} = ['$b^{\overline{T_{x DAS}}~\overline{R_{x MV}}}$'];
labels_latex{3} = ['$b^{\overline{T_{x MV}}~\overline{R_{x DAS}}}$'];
labels_latex{4} = ['$b^{\overline{T_{x MV}}~\overline{R_{x MV}}}$'];
labels_latex{5} = ['$b^{\overline{R_{x MV}}~\overline{T_{x DAS}}}$'];

ylim([0 max(running_time_in_m)+1]);
ylabel('Computation time (m)');
set(gca,'FontSize',18);
x_pos = [1 2 3 4 5];
text(x_pos,running_time_in_m,num2str(running_time_in_m(:),'%.2f'),'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',18)
set(gca, 'XTickLabel', labels_latex, 'TickLabelInterpreter', 'latex','FontSize',24);
set(gcf,'Position',[250 344 781 447]);grid on
saveas(f99,[folder_path,filesep,'adaptive_timing'],'eps2c')

%%
i = 5
figure;
imagesc(img{i}.get_image(compression));
%%
figure;hold all;
for i = [1,2,5]%:5
    i
    img_matrix = img{i}.get_image(compression);
    plot(img{i}.scan.x_axis*10^3,img_matrix(104,:))
    xlim([1 20]);ylim([-40 -5])
end

%%
addpath publications\TUFFC\Rodriguez-Molares_et_al_Generalized_Contrast_to_Noise_ratio\

x0=-5e-3;
z0=25e-3;
r=4e-3;
skip=6.5e-3;
skip_z=4e-3;

% stand off distance <- based on aperture size
r_off = 0.5e-3;                     % overwrite to handle larger pulse duration

% boundaries
ri=r-r_off;
Ai=pi*ri^2;
d=sqrt((scan.x-x0).^2+(scan.z-z0).^2);
l=sqrt(Ai);


% masks
mask_i=d<ri;
mask_o= ((scan.x>(x0+skip-l/2)).*(scan.x<(x0+skip+l/2)).*(scan.z>(z0+skip_z-l/2)).*(scan.z<(z0+skip_z+l/2)))>0;

sum(mask_i)
sum(mask_o)

figure;
subplot(2,3,1)
imagesc(scan.x_axis*1e3, scan.z_axis*1e3, reshape(mask_i,[scan.N_z_axis scan.N_x_axis] )); axis image;
subplot(2,3,2)
imagesc(scan.x_axis*1e3, scan.z_axis*1e3, reshape(mask_o,[scan.N_z_axis scan.N_x_axis] )); axis image;
subplot(2,3,3)
imagesc(scan.x_axis*1e3, scan.z_axis*1e3, img{5}.get_image(compression).*reshape(mask_i,[scan.N_z_axis scan.N_x_axis] )); axis image; colormap gray
subplot(2,3,4)
imagesc(scan.x_axis*1e3, scan.z_axis*1e3, img{5}.get_image(compression).*reshape(mask_o,[scan.N_z_axis scan.N_x_axis] )); axis image; colormap gray
subplot(2,3,5)
imagesc(scan.x_axis*1e3, scan.z_axis*1e3, img{5}.get_image(compression)); axis image; colormap gray

%[GCNR CE CNRE] = inVivoGCNR(img{5}, mask_o, mask_i,'MV')

%%
%% gCNR Comparison
% Define ROI positions
xc_cyst = -8e-3;       % cyst center x [m]
zc_cyst = 24.25e-3;      % cyst center z [m]
xc_speckle = -1e-3;    % speckle center x [m]
zc_speckle = 29.5e-3;   % speckle center z [m]
radius = 4e-3;      % radius [m]

% Measure gCNR for all beamformers
GCNR = zeros(1, 5);
for i = [1 5]
    [~, ~, GCNR(i)] = tools.measure_contrast_circles(img{i}, xc_cyst, zc_cyst, xc_speckle, zc_speckle, radius, 0);
end

% Plot image with ROIs indicated
figure;
% Show reference image (e.g., DAS)
img_data = img{1}.get_image('log');
imagesc(img{1}.scan.x_axis*1e3, img{1}.scan.z_axis*1e3, img_data);
colormap gray; 
caxis([-dynamic_range 0]); 
axis image;
xlabel('x [mm]'); ylabel('z [mm]');
title('ROI locations for contrast estimation');
set(gca, 'FontSize', 14);
hold on;
% Alternative using viscircles (requires Image Processing Toolbox)
hold on;
viscircles([xc_cyst*1e3, zc_cyst*1e3], radius*1e3, 'EdgeColor', 'r', 'LineWidth', 2);
viscircles([xc_speckle*1e3, zc_speckle*1e3], radius*1e3, 'EdgeColor', 'b', 'LineWidth', 2);
hold off;

% Display results
fprintf('\n=== gCNR Comparison ===\n');
for i = 1:5
    fprintf('%-30s gCNR = %.3f\n', label{i}, GCNR(i));
end

% Bar plot
figure;
bar(GCNR);
xticklabels(label);
xtickangle(45);
ylabel('gCNR');
title('Generalized Contrast-to-Noise Ratio Comparison');
ylim([0 1]);
set(gca, 'FontSize', 14);
grid on;

% Add values on top of bars
text(1:5, GCNR, num2str(GCNR', '%.3f'), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 12);

%%
%% Measure 6dB Resolution (FWHM)
% Add the path to the resolution function
addpath([ustb_path, filesep, 'publications', filesep, 'IUS2020', filesep, ...
    'Rindal_et_al_Resolution_Measured_as_Separability_Compared_to_FWHM']);

% Define point target location (adjust for your PICMUS data!)
z_target = 26.15e-3;  % target depth in meters - ADJUST THIS!

% Find the z-index of the point target
[~, z_idx] = min(abs(scan.z_axis - z_target));

% Measure FWHM for all 5 beamformers with plots
f_res = figure(200); clf;
clear res;
for m = [1 5]
    % Get lateral profile at target depth (in dB)
    img_dB = img{m}.get_image('log');
    lateral = img_dB(z_idx, :);
    
    % Calculate 6dB resolution with plot
    [res(m)] = calculate_6dB_resolution(scan.x_axis*1e3, lateral, 1, 200, m);
    
    ylim(gca, [-40 0]);
    xlim(gca, [5 7]);  % adjust range as needed
    title(label{m}, 'Interpreter', 'none');
    set(gca, 'FontSize', 11);
end

% Bar plot summary
subplot(2, 5, 6:10);
bar(1:5, res);
ylabel('FWHM [mm]');
xticks(1:5);
xticklabels(label);
xtickangle(45);
set(gca, 'FontSize', 12);
title('6dB Lateral Resolution Comparison');
grid on;

% Add values on top of bars
text(1:5, res, num2str(res', '%.2f'), 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'bottom', 'FontSize', 11);

set(gcf, 'Position', [50 100 1200 500]);

% Save figure
saveas(f_res, [folder_path, filesep, 'FWHM_resolution'], 'eps2c');
saveas(f_res, [folder_path, filesep, 'FWHM_resolution'], 'png');

% Display results in command window
fprintf('\n=== 6dB Lateral Resolution (FWHM) ===\n');
fprintf('%-30s FWHM [mm]\n', 'Method');
fprintf('%s\n', repmat('-', 1, 45));
for i = 1:5
    fprintf('%-30s %.3f\n', label{i}, res(i));
end