function [image_corrected, correcting_coeff] = calibrateImage_on_theoretical(sta_image,image,z_start,z_stop,x_start,x_stop,order,gradient,colors)
%CALIBRATEIMAGE Summary of this function goes here
%   Detailed explanation goes here


[meanLines,x_axis] = getMeanLateralLines(sta_image,image,z_start,z_stop,x_start,x_stop);
theory = linspace(0,-abs(x_start-x_stop)*gradient,length(x_axis));

for i = 1:length(image.all)
    regresion_coeff{i} = polyfit(x_axis,meanLines.all{i},order);
    regression_top{i} = polyval(regresion_coeff{i},x_axis);
end

for i = 1:length(image.all)
    warning off
    correcting_coeff{i} = polyfit(regression_top{i},max(regression_top{i})+theory,order);
    warning on
end

if order == 3
    for i = 1:length(image.all)
        image_corrected.all{i} = image.all{i}.^3*correcting_coeff{i}(1) + image.all{i}.^2*correcting_coeff{i}(2) + image.all{i}*correcting_coeff{i}(3) + correcting_coeff{i}(4);
        image_corrected.all_signal{i} = 10.^(image_corrected.all{i}./20);
    end
   
elseif order == 2
    for i = 1:length(image.all)
        image_corrected.all{i} = image.all{i}.^2*correcting_coeff{i}(1) + image.all{i}*correcting_coeff{i}(2) + correcting_coeff{i}(3);
        image_corrected.all_signal{i} = 10.^(image_corrected.all{i}./20);
    end
    
elseif order == 4
    for i = 1:length(image.all)
        image_corrected.all{i} = image.all{i}.^4*correcting_coeff{i}(1) + image.all{i}.^3*correcting_coeff{i}(2) + image.all{i}.^2*correcting_coeff{i}(3) + image.all{i}*correcting_coeff{i}(4)+ correcting_coeff{i}(5);
        image_corrected.all_signal{i} = 10.^(image_corrected.all{i}./20);
    end
end

image_corrected.tags = image.tags;

%Get the mean calibrated lines;
[meanLines_full,x_axis] = getMeanLateralLines(sta_image,image_corrected,z_start,z_stop,x_start,x_stop);
[meanLines_full_calibrated,x_axis] = getMeanLateralLines(sta_image,image_corrected,z_start,z_stop,x_start,x_stop);

%%
for i = 1:length(meanLines.all)
   error_values(i) = sum(abs(meanLines_full.all{1}-meanLines_full_calibrated.all{i})); 
end

%%
figure; hold all;
for i = 1:length(regression_top)
    subplot(211);hold all
    plot(meanLines.all{i},'DisplayName',image.tags{i})
    ax(1) = gca;
    subplot(212);hold all
    plot(regression_top{i},'DisplayName',image.tags{i});
    ax(2) = gca;
end
linkaxes(ax);
legend show

%% All images 
for i = 1:length(regression_top)
    f10 = figure;clf; 
    plot(x_axis,max(regression_top{i})+theory,'k--'); hold on; grid on;
    plot(x_axis,meanLines.all{i},'linewidth',2);
    plot(x_axis,regression_top{i});
    plot(x_axis,meanLines_full_calibrated.all{i},'linewidth',2);
    xlabel('x [mm]')
    ylabel('Intensity [dB]')
    legend('Theory','Measure','Fit','Calibrated')
    title(image.tags{i});
    xlim([-20 20])
    ylim([-150 0])
end



end

