scan=uff.linear_scan('x_axis',linspace(-20e-3,20e-3,1024).', 'z_axis', linspace(6e-3,52.5e-3,2048).');

b_data_t = uff.beamformed_data();
b_data_t.scan = scan;

%%

mask_x_speckle_with_cyst = logical(b_data_t.scan.x_axis > -15.5e-3) & logical(b_data_t.scan.x_axis < 4.5e-3);
mask_z_speckle_with_cyst = logical(b_data_t.scan.z_axis > 9e-3) & logical(b_data_t.scan.z_axis < 26.5e-3);

mask_x_gradient_lateral= logical(b_data_t.scan.x_axis > -20e-3) & logical(b_data_t.scan.x_axis < 20e-3);
mask_z_gradient_lateral = logical(b_data_t.scan.z_axis > 39e-3) & logical(b_data_t.scan.z_axis < 49e-3);

mask_x_gradient_axial = logical(b_data_t.scan.x_axis > 14e-3) & logical(b_data_t.scan.x_axis < 19e-3);
mask_z_gradient_axial = logical(b_data_t.scan.z_axis > 9e-3) & logical(b_data_t.scan.z_axis < 39e-3);

db_fall_per_mm = 1.8;
theory_lateral_gradient_amp= -(40*db_fall_per_mm)*(b_data_t.scan.x_axis(mask_x_gradient_lateral)+20e-3)/40e-3;
z_pos = (b_data_t.scan.z_axis(mask_z_gradient_axial)-min(b_data_t.scan.z_axis(mask_z_gradient_axial)));
z_pos = z_pos./max(z_pos);
theory_axial_gradient_amp= -(35*db_fall_per_mm)*z_pos;

mask_x_box_15_12 = logical(b_data_t.scan.x_axis > -13e-3) & logical(b_data_t.scan.x_axis < -10.5e-3);
mask_x_box_12_10 = logical(b_data_t.scan.x_axis > -10.5e-3) & logical(b_data_t.scan.x_axis < -8e-3);
mask_x_box_5_25 = logical(b_data_t.scan.x_axis > -3e-3) & logical(b_data_t.scan.x_axis < -0.5e-3);
mask_x_box_25_0 = logical(b_data_t.scan.x_axis > -0.5e-3) & logical(b_data_t.scan.x_axis < 2e-3);
mask_z_box = logical(b_data_t.scan.z_axis > 27.5e-3) & logical(b_data_t.scan.z_axis < 32.5e-3);


% Create masks to mask out the ROI of the cyst and the background.
for p = 1:length(b_data_t.scan.z_axis)
    positions(p,:,1) = b_data_t.scan.x_axis;
end
for p = 1:length(b_data_t.scan.x_axis)
    positions(:,p,2) = b_data_t.scan.z_axis;
end

% Coordinates for cyst
xc_cyst = -5.5*10^-3;
zc_cyst = 17.5*10^-3;
r_cyst = 4.25*10^-3;
points = ((positions(:,:,1)-xc_cyst).^2) + (positions(:,:,2)-zc_cyst).^2;
idx_cyst = (points < (r_cyst)^2);                     %ROI inside cyst

% Coordinates for PSF
xc_psf = -5.5*10^-3;
zc_psf_1 = 7*10^-3;
zc_psf_2 = 35*10^-3;
r_psf = 0.25*10^-3;

points = ((positions(:,:,1)-xc_psf).^2) + (positions(:,:,2)-zc_psf_1).^2;
idx_psf_1 = (points < (r_psf)^2);                     %ROI inside cyst
points = ((positions(:,:,1)-xc_psf).^2) + (positions(:,:,2)-zc_psf_2).^2;
idx_psf_2 = (points < (r_psf)^2);                     %ROI inside cyst

theoretical_image = ones(b_data_t.scan.N_z_axis,b_data_t.scan.N_x_axis)*-1000;
theoretical_image(mask_z_speckle_with_cyst,mask_x_speckle_with_cyst) = -10;
theoretical_image(mask_z_gradient_lateral,mask_x_gradient_lateral) = repmat(theory_lateral_gradient_amp',[size(b_data_t.scan.z_axis(mask_z_gradient_lateral)),1]);
theoretical_image(mask_z_gradient_axial,mask_x_gradient_axial) = repmat(theory_axial_gradient_amp,[1,size(b_data_t.scan.x_axis(mask_x_gradient_axial))]);
theoretical_image(mask_z_box,mask_x_box_15_12) = 0;
theoretical_image(mask_z_box,mask_x_box_12_10) = -15;
theoretical_image(mask_z_box,mask_x_box_5_25) = 0;
theoretical_image(mask_z_box,mask_x_box_25_0) = -35;
theoretical_image(idx_cyst(:)) = -1000;
theoretical_image(idx_psf_1(:)) = 0;
theoretical_image(idx_psf_2(:)) = 0;


imagesc(theoretical_image)
caxis([-60 0])
colorbar

% Make it signal strength not dB
theoretical_image_non_db = 10.^(theoretical_image/20);


b_data_t.data = theoretical_image_non_db(:);
b_data_t.plot([],[],60)

axi = gca;
xc_nonecho = -5.5;
zc_nonecho = 17.5;
r_nonecho = 3.5;
r_speckle_inner = 5;
r_speckle_outer = 8;
viscircles(axi,[xc_nonecho,zc_nonecho],r_nonecho,'EdgeColor','r','EnhanceVisibility',0);
viscircles(axi,[xc_nonecho,zc_nonecho],r_speckle_inner,'EdgeColor','b','EnhanceVisibility',0);
viscircles(axi,[xc_nonecho,zc_nonecho],r_speckle_outer,'EdgeColor','b','EnhanceVisibility',0);

%%

theory_img = b_data_t.get_image('none');  % Compensation weighting
theory_img = db(abs(theory_img./max(theory_img(:))));                 % Normalize on max
f1 = figure(1);clf;
imagesc(b_data_t.scan.x_axis*1000,b_data_t.scan.z_axis*1000,theory_img);
colormap gray;caxis([-60 0]);axis image;xlabel('x [mm]');ylabel('z [mm]');
set(gca,'FontSize',15);
axi = gca;
xc_nonecho = -5.5;
zc_nonecho = 17.5;
r_nonecho = 3.5;
r_speckle_inner = 5;
r_speckle_outer = 8;
viscircles(axi,[xc_nonecho,zc_nonecho],r_nonecho,'EdgeColor','r','EnhanceVisibility',0);
viscircles(axi,[xc_nonecho,zc_nonecho],r_speckle_inner,'EdgeColor','b','EnhanceVisibility',0);
viscircles(axi,[xc_nonecho,zc_nonecho],r_speckle_outer,'EdgeColor','b','EnhanceVisibility',0);

saveas(f1,[ustb_path,filesep,'publications/DynamicRage/figures/simulation_v2/theoretical_v2'],'eps2c')
saveas(f1,[ustb_path,filesep,'publications/DynamicRage/figures/simulation_v2/theoretical_v2'],'png')
%axis([-17 2 33 42]);
%saveas(f1,[ustb_path,filesep,'publications/DynamicRage/figures/simulation/theoretical_zoomed'],'eps2c')
