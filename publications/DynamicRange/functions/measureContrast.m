function [CR_signal, CR_signal_dagger, CR_image, CNR_signal, CNR_image] = measureContrast(sta_image,image,xc_nonecho,zc_nonecho,r_nonecho,r_speckle_inner,r_speckle_outer,f_filename)
%% MEASURECONTRAST   
% Non echo Cyst contrast

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
idx_cyst = (points < (r_nonecho*10^-3)^2);%ROI inside cyst
idx_speckle_outer =  (((positions(:,:,1)-xc_speckle*10^-3).^2) + (positions(:,:,2)-zc_speckle*10^-3).^2 < (r_speckle_outer*10^-3)^2); %ROI speckle
idx_speckle_inner =  (((positions(:,:,1)-xc_speckle*10^-3).^2) + (positions(:,:,2)-zc_speckle*10^-3).^2 < (r_speckle_inner*10^-3)^2); %ROI speckle
idx_speckle_outer(idx_speckle_inner) = 0;
idx_speckle = idx_speckle_outer;

%% Plot image indicating ROIs

f1 = figure(1111);clf;
imagesc(sta_image.scan.x_axis*1e3,sta_image.scan.z_axis*1e3,image.all{1});
colormap gray; caxis([-60 0]); axis image; xlabel('x [mm]');ylabel('z [mm]');
axi = gca;
set(gca,'FontSize',14)
viscircles(axi,[xc_nonecho,zc_nonecho],r_nonecho,'EdgeColor','r','EnhanceVisibility',0);
viscircles(axi,[xc_nonecho,zc_nonecho],r_speckle_inner,'EdgeColor','y','EnhanceVisibility',0);
viscircles(axi,[xc_nonecho,zc_nonecho],r_speckle_outer,'EdgeColor','y','EnhanceVisibility',0);
if nargin == 8
    set(gca,'FontSize',15)
    saveas(f1,f_filename,'eps2c');
end

%%

%%
for i = 1:length(image.all)
    u_ROI_signal(i) = mean( abs(image.all_signal{i}(idx_cyst)).^2 );
    u_B_signal(i) = mean( abs(image.all_signal{i}(idx_speckle)).^2 );
    
    sigma_ROI_signal(i) = std(abs(image.all_signal{i}(idx_cyst)).^2);
    sigma_B_signal(i)  = std(abs(image.all_signal{i}(idx_speckle)).^2);
    
    u_ROI_image(i) = mean( image.all{i}(idx_cyst) );
    u_B_image(i) = mean( image.all{i}(idx_speckle) );
    
    sigma_ROI_image(i) = std( image.all{i}(idx_cyst) );
    sigma_B_image(i)  = std( image.all{i}(idx_speckle) );
    
    %Current definition on the manuscript
    CR_signal(i) =  u_ROI_signal(i) / u_B_signal(i);
    CR_signal_dagger(i) = (u_ROI_signal(i) - u_B_signal(i)) / sqrt(u_ROI_signal(i)^2+u_B_signal(i)^2);

    CR_image(i) = abs(u_ROI_image(i) - u_B_image(i));
    
    CNR_signal(i) = abs(u_ROI_signal(i) - u_B_signal(i)) / sqrt((sigma_ROI_signal(i)^2 + sigma_B_signal(i)^2));
    CNR_image(i) = abs(u_ROI_image(i) - u_B_image(i)) / sqrt((sigma_ROI_image(i)^2 + sigma_B_image(i)^2));
    
    if 0
        figure(654+i)
        subplot(221);
        imagesc(abs(image.all_signal{i}.*idx_cyst));
        title([image.tags{i},' signal ROI']);caxis([0 0.001]);colorbar;
        subplot(222);
        imagesc(abs(image.all_signal{i}.*idx_speckle));
        title([image.tags{i},' signal B']);caxis([0 1]);colorbar;
        subplot(223);
        imagesc((image.all{i}.*idx_cyst));
        title([image.tags{i},' image ROI']);caxis([-60 0]);colorbar;
        subplot(224);
        imagesc((image.all{i}.*idx_speckle));
        title([image.tags{i},' image B']);caxis([-60 0]);colorbar;
    end
end

if 0
    %%
    f9 = figure
    subplot(411);
    bar(u_ROI_signal)
    set(gca,'XTick',linspace(1,length(image.tags),length(image.tags)))
    set(gca,'XTickLabel',image.tags)
    ylabel('u ROI signal');
    
    subplot(412);
    bar(u_B_signal)
    set(gca,'XTick',linspace(1,length(image.tags),length(image.tags)))
    set(gca,'XTickLabel',image.tags)
    ylabel('u B signal');
    
    subplot(413);
    bar(u_ROI_image)
    set(gca,'XTick',linspace(1,length(image.tags),length(image.tags)))
    set(gca,'XTickLabel',image.tags)
    ylabel('u ROI image');
    
    subplot(414);
    bar(u_B_image)
    set(gca,'XTick',linspace(1,length(image.tags),length(image.tags)))
    set(gca,'XTickLabel',image.tags)
    ylabel('u B image');
 %%   
    f9 = figure;
    subplot(411);
    bar(sigma_ROI_signal)
    set(gca,'XTick',linspace(1,length(image.tags),length(image.tags)))
    set(gca,'XTickLabel',image.tags)
    ylabel('sigma ROI signal');
    
    subplot(412);
    bar(sigma_B_signal)
    set(gca,'XTick',linspace(1,length(image.tags),length(image.tags)))
    set(gca,'XTickLabel',image.tags)
    ylabel('sigma B signal');
    
    subplot(413);
    bar(sigma_ROI_image)
    set(gca,'XTick',linspace(1,length(image.tags),length(image.tags)))
    set(gca,'XTickLabel',image.tags)
    ylabel('sigma ROI image');
    
    subplot(414);
    bar(sigma_B_image)
    set(gca,'XTick',linspace(1,length(image.tags),length(image.tags)))
    set(gca,'XTickLabel',image.tags)
    ylabel('sigma B image');
    
end

end

