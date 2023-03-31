function [meanLines,z_axis] = getMeanAxialLines(sta_image,image,z_start,z_stop,x_start,x_stop)
%getMeanAxialLines Plot lateral line from all images saved in image struct
%   

% Mask out the top gradient part of the image
mask=reshape(sta_image.scan.z>z_start*10^-3&sta_image.scan.z<z_stop*10^-3,[length(sta_image.scan.z_axis) length(sta_image.scan.x_axis)])...
     &reshape(sta_image.scan.x>x_start*10^-3&sta_image.scan.x<x_stop*10^-3,[length(sta_image.scan.z_axis) length(sta_image.scan.x_axis)]);
    
figure(1211);
imagesc(sta_image.scan.x_axis*1e3,sta_image.scan.z_axis*1e3,mask.*image.all{1});
%%%%
% Find the x min and max index in the image from the gradient mask, top
z_min_top = rem(min(find(mask==1)),length(sta_image.scan.z_axis));
z_max_top = rem(max(find(mask==1)),length(sta_image.scan.z_axis));

temp = find(mask(z_min_top,:)==1);
x_min = temp(1);
x_max = temp(end);
%%
for i = 1:length(image.all)
    meanLines.all{i} = mean(image.all{i}(z_min_top:z_max_top,x_min:x_max),2);
end

z_axis = linspace(z_start,z_stop,length(meanLines.all{1}));
end

