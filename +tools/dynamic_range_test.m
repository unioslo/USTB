function [drt] = dynamic_range_test(channel_data,b_data,title_txt)
%% The Dynamic Range Test
% The dynamic range test (DRT) was introduced in Rindal, O. M. H., Austeng, A., Fatemi, A., 
% & Rodriguez-Molares, A. (2019). The effect of dynamic range alterations
% in the estimation of contrast. Submitted to IEEE Transactions on Ultrasonics,
% Ferroelectrics, and Frequency Control. We encourage you to use it, and
% provide here the data sets and code to run it. You have to reference the
% publication above when using the test.
% This script runs the DRT on the DAS (delay-and-sum), CF (coherence
% factor) and MV (minimum variance) beamformer.
%
% Defining the DRT:
% To investigate wether a beamforming method is alternating the dynamic
% range, we have introduced a dynamic range test.
% This test uses the gradients  in  the  simulated  or the  experimental dataset.
% The dynamic range test (DRT) is defined as
%                   DRT=∆/∆_0
% where ∆ denotes the gradient of a given beamforming method, estimated via
% linear regression, and ∆_0 denotes the theoretical gradient, as fixed in
% the simulated and experimental data. DRT measures  how  many  dB  the  
% output  dynamic  range  deviate sfrom the theoretical, for each dB of the
% input dynamic range. 
% 
% For the simulated dataset we have both an axial and a lateral gradient  
% and the DRT  can  be  estimated  for  both.  For  simplicity, the reported DRT 
% value will be the average of the DRT in theaxial  and  lateral  direction.  
% For  the  experimental  dataset  DRT is estimated in the lateral gradient.
%
% @input channel_data : channel data object 
%        b_data       : beamformed data object with the image created by
%                       the beamformer under test
%        title_txt    : title to be used in the plot

if strcmp(channel_data.name,'v5 Simulated dynamic range phantom. Created with Field II. See the reference for details')
    z_start = 40;
    z_stop = 48.5;
    x_start = -14;
    x_stop = 14;
    gradient = -1.8;% db/mm
    do_axial = 2; %If we want to estimate the axial as well, run this twice.
    sub_fig_setup = [1 3];
elseif strcmp(channel_data.name,'v2 Experimental dynamic range phantom. Recorded on a Verasonics Vantage 256 with a L11 probe. See the reference for details')
    z_start = 40;
    z_stop = 48.5;
    x_start = -14;
    x_stop = 14;
    gradient = -1.8;
    do_axial = 1;
    sub_fig_setup = [1 2];
else
    error('The dynamic range test is only defined for the simulated dynamic range phantom, and the experimental one. See the example.');
end

f = figure(); hold all;
for i = 1:do_axial
    % Mask out the gradients
    % Mask out the top gradient part of the image
    mask=reshape(b_data.scan.z>z_start*10^-3&b_data.scan.z<z_stop*10^-3,[length(b_data.scan.z_axis) length(b_data.scan.x_axis)])...
        &reshape(b_data.scan.x>x_start*10^-3&b_data.scan.x<x_stop*10^-3,[length(b_data.scan.z_axis) length(b_data.scan.x_axis)]);
    
    % Find the x min and max index in the image from the gradient mask, top
    z_min = rem(min(find(mask==1)),length(b_data.scan.z_axis));
    z_max = rem(max(find(mask==1)),length(b_data.scan.z_axis));
    
    temp = find(mask(z_min,:)==1);
    x_min = temp(1);
    x_max = temp(end);
    
    img = b_data.get_image();
    mean_line = mean(img(z_min:z_max,x_min:x_max),i);
    mean_line = mean_line-max(mean_line(:)); %Normalize to have the gradient start at 0
    
    if i == 1 %Then we are estimating the lateral
        theory_line = (gradient*(b_data.scan.x_axis(x_min:x_max)-x_start*10^-3))*10^3;
        sub_fig_index_1 = [1];
        sub_fig_index_2 = [2];
    else % we are estimating the axial
        theory_line = (gradient*(b_data.scan.z_axis(z_min:z_max)-z_start*10^-3))*10^3;
        sub_fig_index_1 = [1];
        sub_fig_index_2 = [2];
    end
    
    %Estimate the gradient using linear regression
    regresion_coeff = polyfit(theory_line,mean_line(:),1);
    regression = polyval(regresion_coeff,theory_line);
    
    % Do spme plotting
    if i == 1
        subplot(sub_fig_setup(1),sub_fig_setup(2),sub_fig_index_1); hold all;
        imagesc(b_data.scan.x_axis*1e3,b_data.scan.z_axis*1e3,b_data.get_image());
        colormap gray; axis image; caxis([-60 0]);
        xlabel('x [mm]');ylabel('z [mm]');
        set(gca,'FontSize',15);if(nargin == 3); title(title_txt); end
        set(gca, 'YDir','reverse');
        c = 'r';
    else
        c = 'g'; 
    end
    subplot(sub_fig_setup(1),sub_fig_setup(2),sub_fig_index_1); hold all;
    rectangle('Position',[x_start z_start abs(x_start-x_stop) abs(z_start-z_stop)],...
         'LineWidth',2,'LineStyle','--','EdgeColor',c)

    subplot(sub_fig_setup(1),sub_fig_setup(2),sub_fig_index_2+i-1);
    hold all;
    plot(theory_line,theory_line,'LineWidth',2,'DisplayName','Theoretical');
    plot(theory_line,mean_line,'LineWidth',2,'DisplayName','Mean response');
    plot(theory_line,regression,'LineWidth',2,'DisplayName','Estimated slope');
    set(gca, 'XDir','reverse');xlabel('Input [dB]');ylabel('Output [dB]');
    
    text(-5,-55,sprintf('Theory: 1'),'FontSize',18);
    text(-5,-60,sprintf('Estimated: %.2f',regresion_coeff(1)),'FontSize',18);
    legend show;set(gca,'FontSize',15); ylim([-80 0]);
    
    v= max(abs(theory_line));
      rectangle('Position',[-v -80 v 80],...
         'LineWidth',4,'LineStyle','-','EdgeColor',c)
    xlim([-v 0]);
    
    %Calculate the DRT value according to the definition in equation (31)
    drt(i) = regresion_coeff(1)./1;
    text(-5,-65,sprintf('DRT: %.2f',(drt(i))),'FontSize',18);
    
    % If we do the axial gradient as well (for the simulation) we redefine
    % the position of the gradient variables
    if(do_axial == 2)
        z_start = 9;
        z_stop = 39;
        x_start = 15;
        x_stop = 18.5;
        set(f,'Position',[125 273 926 331]);
    else
        set(f,'Position',[382 286 702 334]);
    end
end

end

