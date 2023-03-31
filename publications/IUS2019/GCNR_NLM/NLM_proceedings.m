clear all;
close all;

%% Download data
url='https://nyhirse.medisin.ntnu.no/ustb/data/gcnr/';   % if not found data will be downloaded from here
filename='insilico_20.uff';
tools.download(filename, url, data_path);   

%% Load data
mix = uff.channel_data();
mix.read([data_path filesep filename],'/mix');
channel_SNR = h5read([data_path filesep filename],'/channel_SNR');

%% Scan
sca=uff.linear_scan('x_axis',linspace(-6e-3,6e-3,256).','z_axis', linspace(14e-3,26e-3,256).');

%% Regions

% cyst geometry -> this should go in the uff
x0=0e-3;                
z0=20e-3; 
r=3e-3;                 

% stand off distance <- based on aperture size
M = 55;                             % aperture size
aperture = M * mix.probe.pitch;     % active aperture
F = z0 / aperture;                  % F-number
r_off = round(1.2 * mix.lambda * F, 5); % stand-off distance (rounded to 0.01 mm) 

% boundaries
ri=r-r_off;
ro=r+r_off;
rO=sqrt(ri^2+ro^2);
Ai=pi*ri^2;
Ao=pi*rO^2-pi*ro^2;
d=sqrt((sca.x-x0).^2+(sca.z-z0).^2);

% masks
mask_i=d<ri;
mask_o=(d>ro)&(d<rO);

%% Prepare beamforming
pipe=pipeline();
pipe.scan=sca;
pipe.channel_data = mix;

pipe.transmit_apodization.window=uff.window.flat;
pipe.transmit_apodization.f_number = 1;
pipe.transmit_apodization.minimum_aperture = M*mix.probe.pitch;
pipe.transmit_apodization.maximum_aperture = M*mix.probe.pitch;

pipe.receive_apodization.window=uff.window.flat;
pipe.receive_apodization.f_number = 1;
pipe.receive_apodization.minimum_aperture = M*mix.probe.pitch;
pipe.receive_apodization.maximum_aperture = M*mix.probe.pitch;

das=midprocess.das();

%% DAS Delay-And-Sum

% beamform
das.dimension = dimension.both;
b_das = pipe.go({ das });

%%
b_das.plot([],['DAS'],50);
%%
[C, CNR, Pmax, GCNR]=contrast_NLM(M, channel_SNR, b_das, mask_o, mask_i, 'DAS',1);

%% 
n = 13;
img = abs(reshape(b_das.data(:,1,1,n),[b_das.scan.N_z_axis b_das.scan.N_x_axis]));
f = figure;
imagesc(b_das.scan.x_axis*1e3,b_das.scan.z_axis*1e3, 20*log10(img./max(img(:)))); colormap gray; axis equal tight; colorbar;
caxis([-50 0])
set(gca,'FontSize', 20);
xlabel('x[mm]');
ylabel('z[mm]');
%title(sprintf("%s %0.2f dB", 'DAS', 10*log10(channel_SNR(n))));
viscircles([x0, z0]*1000,ri*1000,'LineWidth',3);
viscircles([x0, z0]*1000,ro*1000,'LineWidth',3,'Color','blue');
viscircles([x0, z0]*1000,rO*1000,'LineWidth',3,'Color','blue');

pi*ri*1000^2
pi*(rO*1000)^2-pi*(ro*1000)^2
saveas(f,[ustb_path,filesep,'publications',filesep,'IUS2019/GCNR_NLM/Figures/das_circles'],'eps2c')

%% Non Local Means Filtering
nlm = postprocess.non_local_means_filtering();
% %nlm.flag = 'rician';
nlm.rs = [30 30 1];
nlm.rc = [30 30 1];
nlm.ps = 4;
nlm.sigma = 80;
nlm.input = b_das;
%%
b_das_nlm = nlm.go();

%%
[C, CNR, Pmax, GCNR] = contrast_NLM(M, channel_SNR, b_das_nlm, mask_o, mask_i, 'NLM',1);

%% RUN AVERAGE FILTERING
img_db = b_das.get_image();
clip_at=0;
dynamic_range=60;
for i = 1:20
    %img=uint16((2^16-1)*min(max((img_db(:,:,i)+dynamic_range)./(clip_at+dynamic_range),0),1));
    %B = imgaussfilt(A)
    img_filtered(:,:,i) = double(imfilter(img_db(:,:,i),fspecial('average',30),'replicate'));
    %img_filtered(:,:,i) = double(imgaussfilt(A)(img_db(:,:,i),fspecial('average',30),'replicate'));
    img_filtered(:,:,i) = img_filtered(:,:,i)-max(max(img_filtered(:,:,i)));
    img_filtered(:,:,i) = 10.^(img_filtered(:,:,i)/20);
end

b_mode_average_filt = uff.beamformed_data(b_das); % ToDo: instead we should copy everything but the data

b_mode_average_filt.data = reshape(img_filtered,sca.N_x_axis*sca.N_z_axis,1,1,b_das.N_frames);
%%
[C, CNR, Pmax, GCNR]=contrast_NLM(M, channel_SNR, b_mode_average_filt, mask_o, mask_i, 'Average');


%% CF : Coherence Factor Weighted Image

% beamform
das.dimension = dimension.transmit;
cf = postprocess.coherence_factor();
cf.dimension = dimension.receive;
cf_anechoic = pipe.go({ das cf });


%% evaluate contrast
[C, CNR, Pmax, GCNR]=contrast_NLM(M, channel_SNR, cf_anechoic, mask_o, mask_i, 'CF');


%% PCF : Phase Coherence Factor Weighted Image
das.dimension = dimension.transmit;
pcf = postprocess.phase_coherence_factor();
pcf.center_frequency = 5e6;
pcf.dimension = dimension.receive;
pcf.gamma=1;
pipe.channel_data=mix;
pcf_anechoic = pipe.go({ das pcf });

%%
% evaluate contrast
[C, CNR, Pmax, GCNR]=contrast_NLM(M, channel_SNR, pcf_anechoic, mask_o, mask_i, 'PCF');



%% GCF
% beamform
das.dimension = dimension.transmit;
gcf = postprocess.generalized_coherence_factor;
gcf.dimension = dimension.receive;
gcf.M0=4;
pipe.channel_data=mix;
gcf_anechoic = pipe.go({ das gcf });

% evaluate contrast
[C, CNR, Pmax, GCNR]=contrast_NLM(M, channel_SNR, gcf.GCF, mask_o, mask_i, 'GCF');

%% GCF
% beamform
das.dimension = dimension.transmit;
gcf_2 = postprocess.generalized_coherence_factor;
gcf_2.dimension = dimension.receive;
gcf_2.M0=2;
pipe.channel_data=mix;
gcf_anechoic_2 = pipe.go({ das gcf_2 });

% evaluate contrast
[C, CNR, Pmax, GCNR]=contrast_NLM(M, channel_SNR, gcf_2.GCF, mask_o, mask_i, 'GCF_2');




%% SLSC using M elements (hacking the SLSC postprocess)

% important that we use only M elements, centered around the abscissa of the pixel. 
% Changing that will alter the SNR ratio.
das.dimension = dimension.transmit;
b_data_tx = pipe.go({das});

%%
% Set up the SLSC postprocess
slsc = postprocess.short_lag_spatial_coherence();
slsc.receive_apodization = das.receive_apodization;
slsc.dimension = dimension.receive;
slsc.channel_data = mix;
slsc.maxM = 14;
slsc.input = b_data_tx;
slsc.K_in_lambda = 1;

Q = slsc.maxM./M;

% Pick out the M channels that contains data, thus only the M elemetns
% centered around the abscissa of the pixel. This is taken care of by the
% apodization so we can just pick up the element signals that are larger than 0.

% Data buffers
aux_data = zeros(b_data_tx.scan.N_z_axis*b_data_tx.scan.N_x_axis,1,1,mix.N_frames);
aux_data_clamped = zeros(b_data_tx.scan.N_z_axis*b_data_tx.scan.N_x_axis,1,1,mix.N_frames);
data_cube_M_elements = complex(zeros(b_data_tx.scan.N_z_axis,b_data_tx.scan.N_x_axis,M,1));
for f = 1:mix.N_frames
    % Reshape the beamformed data as a cube (Z,X,Elements)
    data_cube = reshape(b_data_tx.data(:,:,1,f),sca.N_z_axis,sca.N_x_axis,mix.N_channels);
    for x = 1: b_data_tx.scan.N_x_axis
        sum_over_z = abs(sum(squeeze(data_cube(:,x,:)),1));
        elements_with_data = sum_over_z>0;
        data_cube_M_elements(:,x,:) = data_cube(:,x,elements_with_data);
    end
    
    % Call the actual implementation of the SLSC calculations, but using
    % the cube which has only M elements
    [image,slsc_values] = slsc.short_lag_spatial_coherence_implementation(data_cube_M_elements);
    image(image<0) = 0; % Set negative coherence values to zero
    
    slsc_img = squeeze(sum(slsc_values(:,:,:),2));
    slsc_img = slsc_img./max(slsc_img(:)); %According to previous publications
    
    % Make one clamped version
    slsc_img_clamped = slsc_img;
    slsc_img_clamped(slsc_img_clamped < 0 ) = 0;
    aux_data_clamped(:,1,1,f) = slsc_img_clamped(:);
    
    % In the other we  can shift the negative coherence to something
    % positive.
    slsc_img = slsc_img + abs(min(slsc_img(:)));
    aux_data(:,1,1,f) = slsc_img(:);
end

% Put the resulting SLSC images in a beamformed data
b_slsc_M_shifted = uff.beamformed_data();
b_slsc_M_shifted.scan = sca;
b_slsc_M_shifted.data = aux_data;

b_slsc_M_clamped = uff.beamformed_data();
b_slsc_M_clamped.scan = sca;
b_slsc_M_clamped.data = aux_data_clamped;

[C, CNR, Pmax, GCNR]=contrast_NLM(M, channel_SNR, b_slsc_M_clamped, mask_o, mask_i, 'SLSC');
%%

%%
% Set up the SLSC postprocess
slsc = postprocess.short_lag_spatial_coherence();
slsc.receive_apodization = das.receive_apodization;
slsc.dimension = dimension.receive;
slsc.channel_data = mix;
slsc.maxM = 14;
slsc.input = b_data_tx;
slsc.K_in_lambda = 0.1;

Q = slsc.maxM./M

% Pick out the M channels that contains data, thus only the M elemetns
% centered around the abscissa of the pixel. This is taken care of by the
% apodization so we can just pick up the element signals that are larger than 0.

% Data buffers
aux_data = zeros(b_data_tx.scan.N_z_axis*b_data_tx.scan.N_x_axis,1,1,mix.N_frames);
aux_data_clamped = zeros(b_data_tx.scan.N_z_axis*b_data_tx.scan.N_x_axis,1,1,mix.N_frames);
data_cube_M_elements = complex(zeros(b_data_tx.scan.N_z_axis,b_data_tx.scan.N_x_axis,M,1));
for f = 1:mix.N_frames
    f
    % Reshape the beamformed data as a cube (Z,X,Elements)
    data_cube = reshape(b_data_tx.data(:,:,1,f),sca.N_z_axis,sca.N_x_axis,mix.N_channels);
    for x = 1: b_data_tx.scan.N_x_axis
        sum_over_z = abs(sum(squeeze(data_cube(:,x,:)),1));
        elements_with_data = sum_over_z>0;
        data_cube_M_elements(:,x,:) = data_cube(:,x,elements_with_data);
    end
    
    % Call the actual implementation of the SLSC calculations, but using
    % the cube which has only M elements
    [image,slsc_values] = slsc.short_lag_spatial_coherence_implementation(data_cube_M_elements);
    image(image<0) = 0; % Set negative coherence values to zero
    
    slsc_img = squeeze(sum(slsc_values(:,:,:),2));
    slsc_img = slsc_img./max(slsc_img(:)); %According to previous publications
    
    % Make one clamped version
    slsc_img_clamped = slsc_img;
    slsc_img_clamped(slsc_img_clamped < 0 ) = 0;
    aux_data_clamped(:,1,1,f) = slsc_img_clamped(:);
    
    % In the other we  can shift the negative coherence to something
    % positive.
    slsc_img = slsc_img + abs(min(slsc_img(:)));
    aux_data(:,1,1,f) = slsc_img(:);
end

% Put the resulting SLSC images in a beamformed data
b_slsc_M_shifted = uff.beamformed_data();
b_slsc_M_shifted.scan = sca;
b_slsc_M_shifted.data = aux_data;

b_slsc_M_clamped = uff.beamformed_data();
b_slsc_M_clamped.scan = sca;
b_slsc_M_clamped.data = aux_data_clamped;

[C, CNR, Pmax, GCNR]=contrast_NLM(M, channel_SNR, b_slsc_M_clamped, mask_o, mask_i, 'SLSC_2');

%% Evaluate resolution on edge of cyst

img_DAS = b_das.get_image();
img_DAS = img_DAS(:,:,end);
img_NLM = b_das_nlm.get_image();
img_NLM = img_NLM(:,:,end);
img_AF = db(img_filtered(:,:,end)./max(max(img_filtered(:,:,end))));


%img_filtered


figure(12);clf;
subplot(221)
imagesc(sca.x_axis*1000,sca.z_axis*1000,img_NLM)
axis image; colormap gray;
caxis([-50 0]);
subplot(222)
imagesc(sca.x_axis*1000,sca.z_axis*1000, img_AF)
axis image; colormap gray;
caxis([-50 0]);
f = figure(13);clf;
subplot(2,2,[3 4]);hold on;
%plot(sca.x_axis*1000,img_DAS(end/2,:),'LineWidth',2)
plot(sca.x_axis*1000,img_NLM(end/2,:),'LineWidth',2)
plot(sca.x_axis*1000,img_AF(end/2,:),'LineWidth',2)
plot([-3 -3],[-30 0],'LineWidth',2,'Linestyle','--','Color',[0 0 0])
plot([3 3],[-30 0],'LineWidth',2,'Linestyle','--','Color',[0 0 0])
xlabel('x [mm]');ylabel('Amplitude [dB]');
legend('NLM','SA','Cyst edges');
ylim([-30 0])
%title(['Lateral line through cyst at SNR = ',num2str(10*log10(channel_SNR(end)))]);
%%
set(gca,'FontSize',15);

%%
saveas(f,[ustb_path,filesep,'Publications',filesep,'IUS2019',filesep,'GCNR_NLM',filesep,'Figures/edges.eps'],'eps2c')

