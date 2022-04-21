function [flowField, GT] = Phantom_gradient2Dtube( p, X, Z ) % parameter structure p not used in this example

%% small 2D tube phantom, run and check signal integrity in the middle of the tube
btf = 60;
npoints = 10;
flowlength = 0.0024; %0.005; %0.03; %0.005;
tubedepth = 0.015; %0.03;
depthstep = 0.0001; %0.00015; %lambda/2 for 5 MHz
noFlowLines = 11; %odd number
vel_low = 0.4;
vel_high = 2;
veltab = linspace( vel_low, vel_high, noFlowLines);
% veltab = linspace( vel_high, vel_low, noFlowLines);

depthtab = (-(noFlowLines-1)/2:1:(noFlowLines-1)/2)*depthstep+tubedepth;
for kk = 1:noFlowLines,
    time_max = flowlength/veltab(kk);
    currtubedepth = depthtab(kk);
    flowField(kk).timetab = linspace(0, time_max, npoints);
    flowField(kk).postab = veltab(kk)*(flowField(kk).timetab-time_max/2).*[sind(btf); 0; cosd(btf)]+[0; 0; currtubedepth];
    flowField(kk).timetab = flowField(kk).timetab.'; 
    flowField(kk).postab = flowField(kk).postab.';
end
if nargin > 1,
    projZ = Z-X/tand(btf);
    projDist = X/sind(btf);
    GT = interp1( depthtab, veltab, projZ);
    GT( abs( projDist) > flowlength/2 ) = NaN;
end