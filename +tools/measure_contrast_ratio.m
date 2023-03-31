function [CR C] = measure_contrast_ratio(sta_image,image,xc_nonecho,zc_nonecho,r_nonecho,r_speckle_inner,r_speckle_outer,f_filename,plot_flag)
if nargin < 9
    plot_flag = 0;
end

%% Non echo Cyst contrast

xc_speckle = xc_nonecho;
zc_speckle = zc_nonecho;

% Create masks to mask out the ROI of the cyst and the background.
for p = 1:length(sta_image.scan.z_axis)
    positions(p,:,1) = sta_image.scan.x_axis;
end

for p = 1:length(sta_image.scan.x_axis)
    positions(:,p,2) = sta_image.scan.z_axis;
end


points = ((positions(:,:,1)-xc_nonecho*10^-3).^2) + (positions(:,:,2)-zc_nonecho*10^-3).^2;
idx_cyst = (points < (r_nonecho*10^-3)^2);                     %ROI inside cyst
idx_speckle_outer =  (((positions(:,:,1)-xc_speckle*10^-3).^2) + (positions(:,:,2)-zc_speckle*10^-3).^2 < (r_speckle_outer*10^-3)^2); %ROI speckle
idx_speckle_inner =  (((positions(:,:,1)-xc_speckle*10^-3).^2) + (positions(:,:,2)-zc_speckle*10^-3).^2 < (r_speckle_inner*10^-3)^2); %ROI speckle
idx_speckle_outer(idx_speckle_inner) = 0;% & idx_speckle_inner;
idx_speckle = idx_speckle_outer;

%%

f1 = figure(1111);clf;
set(f1,'Position',[100,100,300,300]);
if sum(sum(imag(image.all{1}))) > 0 %Someone have sent in the "signal"
    imagesc(sta_image.scan.x_axis*1e3,sta_image.scan.z_axis*1e3,db(abs(image.all{1}./max(max(image.all{1})))));
else
    imagesc(sta_image.scan.x_axis*1e3,sta_image.scan.z_axis*1e3,image.all{1});
end
colormap gray; caxis([-60 0]); axis image; xlabel('x [mm]');ylabel('z [mm]');
title('Image indicating regions used to measure contrast');
axi = gca;
viscircles(axi,[xc_nonecho,zc_nonecho],r_nonecho,'EdgeColor','r');
viscircles(axi,[xc_nonecho,zc_nonecho],r_speckle_inner,'EdgeColor','y');
viscircles(axi,[xc_nonecho,zc_nonecho],r_speckle_outer,'EdgeColor','y');

if nargin == 8
    saveas(f1,f_filename,'eps2c');
end

for i = 1:length(image.all)
    CR(i) = abs(mean(image.all{i}(idx_cyst))-mean(image.all{i}(idx_speckle))); %The difference of the mean of dBvalues
    
    Si = mean(abs(image.all{i}(idx_cyst)));
    So = mean(abs(image.all{i}(idx_speckle)));
    
    C(i) = 20*log10( Si / So);

    if plot_flag
        figure;
        subplot(211);
        imagesc(abs(image.all{i}).*idx_cyst)
        caxis([0 1]);
        colorbar
        title(image.tags{i});
        subplot(212);
        imagesc(abs(image.all{i}).*idx_speckle)
        caxis([0 1])
        colorbar;
    else
end

end

