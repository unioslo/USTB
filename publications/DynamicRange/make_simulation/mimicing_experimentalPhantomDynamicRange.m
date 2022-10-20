function [sca_tot,amp_tot] = mimicing_experimentalPhantomDynamicRange(sca_per_mm2)

%% Create lateral gradient (lg)
x_min_lg = -19/1000;
x_max_lg = 20/1000;
z_min_lg = 39/1000;
z_max_lg = 49/1000;
Intensity_lg = 0;
dB_mm_lg = 1.66;

[sca_lg,amp_lg] = simulatedPhantomGradientBlock(sca_per_mm2,x_min_lg,x_max_lg,z_min_lg,z_max_lg,Intensity_lg,dB_mm_lg);
% 

%% Create hypoechoic cyst (hc)
x_min_hc = -15/1000;
x_max_hc = 3/1000;
z_min_hc = 9.5/1000;
z_max_hc = 25.5/1000;
Intensity_hc = -10;
dB_mm_hc = 0;


[sca_hc_temp,amp_hc_temp] = simulatedPhantomGradientBlock(sca_per_mm2,x_min_hc,x_max_hc,z_min_hc,z_max_hc,Intensity_hc,dB_mm_hc);

% Define geometry of nonechoic cyst
r=5e-3;           % Radius of cyst [m]
xc=-5.5e-3;           % Position of cyst in x [m]
zc=17.5e-3;           % Position of cyst in z [m]
%Find the indexes inside cyst
inside_nonechoic = (((sca_hc_temp(:,1)-xc).^2 + (sca_hc_temp(:,3)-zc).^2) < r^2);

%%
clear sca_hc;
sca_hc(:,1) = sca_hc_temp(inside_nonechoic==0,1);
sca_hc(:,2) = sca_hc_temp(inside_nonechoic==0,2);
sca_hc(:,3) = sca_hc_temp(inside_nonechoic==0,3);
amp_hc = amp_hc_temp(inside_nonechoic==0);

%%
sca_points(1,:) =[10e-3,  0, 10e-3];    % point scatterer position [m]
sca_points(2,:) =[10e-3,  0, 20e-3];    %Pont in speckle
sca_points(3,:) =[10e-3,  0, 30e-3];    % point scatterer position [m]

amp_points = max([amp_lg(:); amp_hc(:); ]).*ones(size(sca_points,1),1);
%amp_points(2) = amp_points(3)*1.2;
%%

sca_tot = [sca_lg; sca_hc; sca_points];
amp_tot = [amp_lg; amp_hc; amp_points];

figure;
plot3(sca_tot(:,1)*1e3,sca_tot(:,3)*1e3,20*log10(amp_tot),'b.'); axis equal;
zlim([-60 5]);
xlabel('X [mm]');ylabel('Z [mm]');zlabel('Amplitude [dB]');