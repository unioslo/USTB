function [sca,amp] = simulatedPhantomGradientBlock(sca_per_mm2,x_min,x_max,z_min,z_max,Intensity,dB_mm)
%SIMULATEDPHANTOMNARROWNOHYPERECHOCYST Summary of this function goes here
%   Detailed explanation goes here

% speckle 
area_speckle_mm = (x_max-x_min)*(z_max-z_min)/1e-6;
N=ceil(sca_per_mm2*area_speckle_mm);

% position
xxp_speckle=random('unif',x_min,x_max,N,1);
zzp_speckle=random('unif',z_min,z_max,N,1);

% randomization of edges (to avoid specular reflection)
min_mask=abs(zzp_speckle-z_min)<0.5e-3;
zzp_speckle(min_mask)= zzp_speckle(min_mask)+random('unif',-0.125e-3,0.125e-3,sum(min_mask),1);
max_mask=abs(zzp_speckle-z_max)<0.5e-3;
zzp_speckle(max_mask)= zzp_speckle(max_mask)+random('unif',-0.125e-3,0.125e-3,sum(max_mask),1);

% Set the scatterers together
sca = [xxp_speckle zeros(N,1) zzp_speckle];   % list with the scatterers coordinates [m]
%amp = 10^(Intensity/20/(sca_per_mm2/590))*ones(N,1);      % making intensity independent of concentration
if numel(dB_mm)==1
    amp = 10.^((Intensity-(xxp_speckle-x_min)/1e-3*dB_mm)/20);
else
    amp = 10.^((Intensity-(xxp_speckle-x_min)/1e-3*dB_mm(1)-(zzp_speckle-z_min)/1e-3*dB_mm(2))/20);
end

% show
% mask=(20*log10(amp)>-60) & (20*log10(amp)<0);
% figure;
% plot3(sca(mask,1)*1e3,sca(mask,3)*1e3,20*log10(amp(mask)),'b.'); hold on; axis equal; grid on;
% plot3(sca(~mask,1)*1e3,sca(~mask,3)*1e3,20*log10(amp(~mask)),'r.'); 
% xlabel('x[mm]');
% ylabel('z[mm]');
% zlabel('Intensity[dB]');

end

