function [GCNR, v1_binary, v2_binary, c_binary] = contrast_calc_insilico(img_cell,name_cell, xsc, zsc, das_handle, dyn, storefolder,c_area, v1_area,v2_area)
% function to calculate contrast for simulated images with .
% the user draws three ellipses on the first image 
% (the first two for the walls and the last for the chamber) and the function
% would then calculate the contrasrt between the first two and the last
% region for all images

% img_cell: the three images; DAS, CF, CF_2d (input the scanconverted and hist-matched images)

if nargin < 5
    dyn = 60;
end
if nargin < 6
    storefolder = './';
end

if nargin < 6
    storefolder = './';
end

figure(das_handle); %choose the CF2d image to mark the regions on

if nargin < 7
    %c_area = drawellipse();
    c_area = drawrectangle();
end

if nargin < 8
    %v1_area = drawellipse();
    v1_area = drawrectangle();
end

if nargin < 9
    %v2_area = drawellipse();
    v2_area = drawrectangle();
end


v1_binary = v1_area.createMask();
v2_binary = v2_area.createMask();
c_binary = c_area.createMask();

v1_Boundaries = bwboundaries(v1_binary);
v2_Boundaries = bwboundaries(v2_binary);
c_Boundaries = bwboundaries(c_binary);

v1_xy = v1_Boundaries{1};
v2_xy = v2_Boundaries{1};
c_xy = c_Boundaries{1};

hold on 
plot(xsc(c_xy(:,2))*1000,zsc(c_xy(:,1))*1000, 'r', 'LineWidth', 1)
plot(xsc(v1_xy(:,2))*1000,zsc(v1_xy(:,1))*1000, 'g', 'LineWidth', 1)
plot(xsc(v2_xy(:,2))*1000,zsc(v2_xy(:,1))*1000, 'g', 'LineWidth', 1)

set(findall(gcf,'-property','FontSize'),'FontSize',16)

v1_mask = img_cell;
v2_mask = img_cell;
c_mask = img_cell;

hist_fig = figure();
for ii = 1:numel(img_cell)
    v1_mask{ii}(~v1_binary) = 0;
    v2_mask{ii}(~v2_binary) = 0;
    c_mask{ii}(~c_binary) = 0;
    bins=linspace(-120,0,256);
    [p_noise,~] = hist(img_cell{ii}(c_binary),bins);
    [p_signal,~] = hist(img_cell{ii}(v1_binary | v2_binary),bins);
    
    figure(hist_fig);
    subplot(numel(img_cell),1,ii)
    plot(bins, p_noise./sum(p_noise),'Color', '#D95319','LineWidth', 2)
    hold on
    plot(bins, p_signal./sum(p_signal),'Color', '#0072BD','LineWidth', 2);
    xlim([-80,0]);
    hold off
    OVL = min(p_noise./sum(p_noise), p_signal./sum(p_signal));
    GCNR{ii} = 1 - sum(OVL);
    legend('Speckle','Background','Location','eastoutside');
    ylabel('')


    f = figure();
    imagesc(xsc*1000, zsc*1000, img_cell{ii})
    colormap gray
    clim([-dyn 0])
    axis image
    colorbar
    hold on
    xlabel('x[mm]')
    ylabel('z[mm]')
    xlim([-20,20]);
    t = text(mean(xsc)*1000,0,sprintf('gCNR = %0.2f',GCNR{ii}),...
        'Color', 'white', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');
    set(findall(gcf,'-property','FontSize'),'FontSize',15)
    t.FontSize = 15;

    plot(xsc(c_xy(:,2))*1000,zsc(c_xy(:,1))*1000, 'Color','#D95319', 'LineWidth', 2)
    plot(xsc(v1_xy(:,2))*1000,zsc(v1_xy(:,1))*1000, 'Color','#0072BD', 'LineWidth', 2)
    plot(xsc(v2_xy(:,2))*1000,zsc(v2_xy(:,1))*1000, 'Color','#0072BD', 'LineWidth', 2)

    c_area.Visible = 'off';
    v1_area.Visible = 'off';
    v2_area.Visible = 'off';
    hold off
    %title(name_cell{ii});
    % savefig(f,[storefolder,'gCNR_',name_cell{ii},'.fig']);
    % saveas(f,[storefolder,'gCNR_',name_cell{ii},'.png']);
end
figure(hist_fig);
fontsize(hist_fig,14,'points');
xlabel('dB','FontSize',14);
% savefig(hist_fig,[storefolder,'gCNR_histograms_',name_cell{ii},'.fig']);
% saveas(hist_fig,[storefolder,'gCNR_histograms_',name_cell{ii},'.png']);
end