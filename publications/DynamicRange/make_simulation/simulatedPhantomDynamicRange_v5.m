function [sca_tot,amp_tot] = simulatedPhantomDynamicRange_v5(sca_per_mm2)

%% Create lateral gradient (lg)
x_min_lg = -20/1000;
x_max_lg = 20/1000;
z_min_lg = 39/1000;
z_max_lg = 49/1000;
Intensity_lg = 0;
dB_mm_lg = 1.8;%2;%1.66;

[sca_lg,amp_lg] = simulatedPhantomGradientBlock(sca_per_mm2,x_min_lg,x_max_lg,z_min_lg,z_max_lg,Intensity_lg,dB_mm_lg);

%% Create axial gradient (ag)
x_min_ag = 14/1000;
x_max_ag = 19/1000;
z_min_ag = 9/1000;
z_max_ag = 39/1000;
Intensity_ag = 0;
dB_mm_ag = 1.8;%1.66;

[sca_ag,amp_ag] = simulatedPhantomGradientBlock(sca_per_mm2,x_min_ag,x_max_ag,z_min_ag,z_max_ag,Intensity_ag,[0 dB_mm_ag]);


%% Create hypoechoic cyst (hc)
x_min_hc = -15.5/1000;
x_max_hc = 4.5/1000;
z_min_hc = 9/1000;
z_max_hc = 26.5/1000;
Intensity_hc = -10;
dB_mm_hc = 0;

[sca_hc_temp,amp_hc_temp] = simulatedPhantomGradientBlock(sca_per_mm2,x_min_hc,x_max_hc,z_min_hc,z_max_hc,Intensity_hc,dB_mm_hc);

% Define geometry of nonechoic cyst
r=4.25e-3;           % Radius of cyst [m]
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

%% Create amplitude box
diff = 2/1000;
x_min_left_l = -15/1000 + diff;
x_max_left_l = -12.5/1000 + diff;
z_min_left_l = 27.5/1000;
z_max_left_l = 32.5/1000;
Intensity_left_l = 0;

[sca_left_l,amp_left_l] = simulatedPhantomGradientBlock(sca_per_mm2,x_min_left_l,x_max_left_l,z_min_left_l,z_max_left_l,Intensity_left_l,0);
x_min_left_r = -12.5/1000 + diff;
x_max_left_r = -10/1000 + diff;
Intensity_left_r = -10;
[sca_left_r,amp_left_r] = simulatedPhantomGradientBlock(sca_per_mm2,x_min_left_r,x_max_left_r,z_min_left_l,z_max_left_l,Intensity_left_r,0);

x_min_right_l = -5/1000 + diff;
x_max_right_l = -2.5/1000 + diff;
z_min_right_l = 27.5/1000;
z_max_right_l = 32.5/1000;
Intensity_right_l = 0;

[sca_right_l,amp_right_l] = simulatedPhantomGradientBlock(sca_per_mm2,x_min_right_l,x_max_right_l,z_min_right_l,z_max_right_l,Intensity_right_l,0);
x_min_right_r = -2.5/1000 + diff;
x_max_right_r = 0/1000 + diff;
Intensity_right_r = -35;
[sca_right_r,amp_right_r] = simulatedPhantomGradientBlock(sca_per_mm2,x_min_right_r,x_max_right_r,z_min_right_l,z_max_right_l,Intensity_right_r,0)

%%
sca_points(1,:) =[-5.5e-3,  0, 7e-3];    % point scatterer position [m]
%sca_points(2,:) =[-7.5e-3,  0, 20e-3];    %Pont in speckle
sca_points(2,:) =[-5.5e-3,  0, 35e-3];    % point scatterer position [m]

%amp_points = max([amp_lg(:); amp_hc(:); amp_ag(:)]).*ones(size(sca_points,1),1);
amp_points = 10^(5/20).*ones(size(sca_points,1),1);
%amp_points(2) = amp_points(3)*1.2;
%%

sca_tot = [sca_lg; sca_hc; sca_ag; sca_left_l; sca_left_r; sca_right_l; sca_right_r; sca_points];
amp_tot = [amp_lg; amp_hc; amp_ag; amp_left_l; amp_left_r; amp_right_l;  amp_right_r; amp_points];

figure;
plot3(sca_tot(:,1)*1e3,sca_tot(:,3)*1e3,20*log10(amp_tot),'b.'); axis equal;
zlim([-60 5]);
xlabel('X [mm]');ylabel('Z [mm]');zlabel('Amplitude [dB]');
