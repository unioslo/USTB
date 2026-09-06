function [CR,CR_alt,CR_alt_2,f1] = measure_contrast_experimental_dra(sta_image,image,xc_nonecho,zc_nonecho,r_nonecho,r_speckle_inner,r_speckle_outer,xc_alt,zc_alt,r_speckle,xc_alt_2,zc_alt_2,r_alt_2,f_filename)

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
idx_cyst = (points < (r_nonecho*10^-3)^2);                    
points = ((positions(:,:,1)-xc_alt*10^-3).^2) + (positions(:,:,2)-zc_alt*10^-3).^2;
idx_speckle_alt = (points < (r_alt_2*10^-3)^2);  
points = ((positions(:,:,1)-xc_alt_2*10^-3).^2) + (positions(:,:,2)-zc_alt_2*10^-3).^2;
idx_speckle_alt_2 = (points < (r_speckle*10^-3)^2);  
idx_speckle_outer =  (((positions(:,:,1)-xc_speckle*10^-3).^2) + (positions(:,:,2)-zc_speckle*10^-3).^2 < (r_speckle_outer*10^-3)^2); %ROI speckle
idx_speckle_inner =  (((positions(:,:,1)-xc_speckle*10^-3).^2) + (positions(:,:,2)-zc_speckle*10^-3).^2 < (r_speckle_inner*10^-3)^2); %ROI speckle
idx_speckle_outer(idx_speckle_inner) = 0;
idx_speckle = idx_speckle_outer;

%%

f1 = figure(1111); %#ok<*FIGLEG>
clf(f1);
set(f1, 'Position', [100, 100, 300, 300]);
if strcmp(tools.headless_publish_figure_visible(), 'on')
    set(f1, 'Visible', 'on');
elseif ~usejava('desktop')
    set(f1, 'Visible', 'off');
end
imagesc(sta_image.scan.x_axis*1e3,sta_image.scan.z_axis*1e3,image.all{1});
colormap gray; caxis([-60 0]); axis image; xlabel('x [mm]');ylabel('y [mm]');
%colorbar
axi = gca;
ipt_viscircles(axi, [xc_nonecho, zc_nonecho], r_nonecho, 'EdgeColor', 'r', 'EnhanceVisibility', 0);
ipt_viscircles(axi, [xc_nonecho, zc_nonecho], r_speckle_inner, 'EdgeColor', [1 1 1], 'EnhanceVisibility', 0);
ipt_viscircles(axi, [xc_nonecho, zc_nonecho], r_speckle_outer, 'EdgeColor', [1 1 1], 'EnhanceVisibility', 0);
ipt_viscircles(axi, [xc_alt, zc_alt], r_alt_2, 'EdgeColor', 'y', 'EnhanceVisibility', 0);
ipt_viscircles(axi, [xc_alt_2, zc_alt_2], r_speckle, 'EdgeColor', 'g', 'EnhanceVisibility', 0.5);

text(xc_nonecho-0.7,zc_nonecho,'1','FontSize',18,'FontWeight','bold','Color','r');
text(xc_nonecho+5.15,zc_nonecho,'2','FontSize',18,'FontWeight','bold','Color','w');
text(xc_nonecho-7.5,zc_nonecho,'3','FontSize',18,'FontWeight','bold','Color','g');
text(xc_alt-1,zc_alt,'4','FontSize',18,'FontWeight','bold','Color','y');
set(axi,'FontSize',12);

drawnow;
tools.publish_snap_now_figure(f1);

if nargin == 14
    saveas(f1,f_filename,'eps2c');
end

for i = 1:length(image.all)
    CR(i) = abs(mean(image.all{i}(idx_cyst))-mean(image.all{i}(idx_speckle)));
    CR_alt(i) = abs(mean(image.all{i}(idx_cyst))-mean(image.all{i}(idx_speckle_alt)));
    CR_alt_2(i) = abs(mean(image.all{i}(idx_cyst))-mean(image.all{i}(idx_speckle_alt_2)));
end

end

function ipt_viscircles(ax, ctr, radius_mm, varargin)
%IPT_VISCIRCLES  Image Processing Toolbox viscircles, or polyline fallback (CI / publish).

if exist('viscircles', 'file') == 2 %#ok<EXIST>
    viscircles(ax, ctr, radius_mm, varargin{:});
    return
end

theta = linspace(0, 2 * pi, 81);
xe = ctr(1) + radius_mm * cos(theta);
ye = ctr(2) + radius_mm * sin(theta);
ec = [1 0 0];
k = 1;
while k <= numel(varargin)
    if strcmp(varargin{k}, 'EdgeColor') && k + 1 <= numel(varargin)
        ec = varargin{k + 1};
        k = k + 2;
    elseif strcmp(varargin{k}, 'EnhanceVisibility') && k + 1 <= numel(varargin)
        k = k + 2;
    else
        k = k + 1;
    end
end
if ischar(ec) || isstring(ec)
    switch char(ec)
        case 'r'
            ec = [1 0 0];
        case 'y'
            ec = [1 1 0];
        case 'g'
            ec = [0 1 0];
        otherwise
            ec = [1 0 0];
    end
end
hold(ax, 'on');
plot(ax, xe, ye, 'Color', ec, 'LineWidth', 1.5);

end

