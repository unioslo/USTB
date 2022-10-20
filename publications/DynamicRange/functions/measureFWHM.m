function [fwhm] = measureFWHM(sta_image,image,z_depth,x_start,x_stop)
%PLOTLATERALLINE Plot lateral line from all images saved in image struct
%   
[dummy,line_points_1] = min(abs(sta_image.scan.z_axis-z_depth*10^-3))
[dummy,x_start_idx] = min(abs(sta_image.scan.x_axis-x_start*10^-3))
[dummy,x_stop_idx] = min(abs(sta_image.scan.x_axis-x_stop*10^-3))
x_samples_points = [x_start_idx x_stop_idx];


figure;clf;hold all;
for i = 1:length(image.all)
    fwhm(i) = Compute_6dB_Resolution(sta_image.scan.x_axis(x_samples_points(1):x_samples_points(2))*1e3,image.all{i}(line_points_1,x_samples_points(1):x_samples_points(2))-max(image.all{i}(line_points_1,x_samples_points(1):x_samples_points(2))),1,1,1);
    %fwhm = plot(sta_image.scan.x_axis*1e3,,'LineWidth',2,'DisplayName',image.tags{i})
end
end

