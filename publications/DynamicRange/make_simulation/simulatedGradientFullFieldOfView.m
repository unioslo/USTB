function [sca_tot,amp_tot] = simulatedGradientFullFieldOfView(sca_per_mm2)

%% Create lateral gradient (lg)
x_min_lg = -20/1000;
x_max_lg = 20/1000;
z_min_lg = 5/1000;
z_max_lg = 50/1000;
Intensity_lg = 0;
dB_mm_lg = 1.8;

[sca_lg,amp_lg] = simulatedPhantomGradientBlock(sca_per_mm2,x_min_lg,x_max_lg,z_min_lg,z_max_lg,Intensity_lg,dB_mm_lg);

sca_tot = [sca_lg;];
amp_tot = [amp_lg;];

figure;
plot3(sca_tot(:,1)*1e3,sca_tot(:,3)*1e3,20*log10(amp_tot),'b.'); axis equal;
zlim([-60 5]);
xlabel('X [mm]');ylabel('Z [mm]');zlabel('Amplitude [dB]');
