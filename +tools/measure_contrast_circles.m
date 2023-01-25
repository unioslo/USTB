function [CR CNR GCNR CR_LC] = measure_contrast_circles(b_data, xc_nonecho, zc_nonecho, xc_echo, zc_echo, r, plot_flag, title_text, file_tag)
if nargin < 7
    plot_flag = 0;
end

if nargin < 8
    title_text = 'ROIs indicated';
end

%% Get region
xc_speckle = xc_nonecho;
zc_speckle = zc_nonecho;
if isa(b_data.scan,'uff.sector_scan')||isa(b_data.scan,'uff.sector_scan_na')
    positions = reshape(b_data.scan.xyz,b_data.scan.N_depth_axis,b_data.scan.N_azimuth_axis,3);
else
    positions = reshape(b_data.scan.xyz,b_data.scan.N_z_axis,b_data.scan.N_x_axis,3);
end
points = ((positions(:,:,1)-xc_nonecho).^2) + (positions(:,:,3)-zc_nonecho).^2;
idx_cyst = (points < (r)^2);                     %ROI inside cyst
points = ((positions(:,:,1)-xc_echo).^2) + (positions(:,:,3)-zc_echo).^2;
idx_speckle = (points < (r)^2);       

%%
if plot_flag
    b_data.plot([],['Plot with regions indicated'],[],[],[],[],['m'],'dark')
    caxis([-60 0]);
    axi = gca;
    viscircles(axi,[xc_nonecho,zc_nonecho],r,'EdgeColor','r');
    viscircles(axi,[xc_echo,zc_echo],r,'EdgeColor','b');
end

%%
img_signal = b_data.get_image('none');
%%
for f = 1:b_data.N_frames
    img_signal_current = img_signal(:,:,f);

    % Estimate the mean and the background of all images and calculate the CR
    mean_background = mean(abs(img_signal_current(idx_speckle(:))).^2)
    mean_ROI = mean(abs(img_signal_current(idx_cyst(:))).^2)
    
    % Calculate CR
    CR(f) = 10*log10(mean_ROI/mean_background)

    % Calculate CNR
    sigma_background = std( abs(img_signal_current(idx_speckle(:))).^2 );
    sigma_ROI = std( abs(img_signal_current(idx_cyst(:))).^2 );
    
    CNR(f) = abs(mean_ROI - mean_background) / sqrt(sigma_ROI^2 + sigma_background^2)

    % Calculate gCNR
    x=linspace(min(db(abs(img_signal_current(img_signal_current>eps)))),max(db(abs(img_signal_current(:)))),100);
    [pdf_i]=hist(db(abs(img_signal_current(idx_cyst(:)))),x);
    [pdf_o]=hist(db(abs(img_signal_current(idx_speckle(:)))),x);

    OVL =sum(min([pdf_i./sum(pdf_i); pdf_o./sum(pdf_o)]));
    MSR  = 1 - OVL/2;
    GCNR(f) = 1 - OVL;
    
    if plot_flag
        %% Plot probability density function
        figure()
        plot(x,pdf_i./sum(pdf_i),'r-', 'linewidth',2); hold on; grid on;
        plot(x,pdf_o./sum(pdf_o),'b-', 'linewidth',2);
        hh=area(x,min([pdf_i./sum(pdf_i); pdf_o./sum(pdf_o)]), 'LineStyle','none');
        hh.FaceColor = [0.6 0.6 0.6];
        xlabel('||s||');
        ylabel('Probability');
        legend('p_i','p_o','OVL');
        title(['gCNR from frame = ',num2str(f)])
        set(gca,'FontSize', 14);
    end
end
end

