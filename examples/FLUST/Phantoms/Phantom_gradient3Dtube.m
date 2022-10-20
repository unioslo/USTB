function [flowField, GT] = Phantom_gradient3Dtube( p, X, Z ) % parameter structure p not used in this example

%% small 2D tube phantom, run and check signal integrity in the middle of the tube

btfAZ = 60;
btfEL = 30;
npoints = 10;
flowlength = 0.0024; %0.005; %0.03; %0.005;
tubedepth = 0.015; %0.03;
radius = 0.0003; %0.0005;
depthstep = 0.0001; %0.00015; %lambda/2 for 5 MHz
noLineDepths = ceil( 2*radius/depthstep)+1; %odd number
vel_low = 0.1;
vel_high = 2;
% veltab = linspace( vel_low, vel_high, noLineDepths);
% veltab = linspace( vel_high, vel_low, noFlowLines);

depthtab = (-(noLineDepths-1)/2:1:(noLineDepths-1)/2)*depthstep+tubedepth;
eltab = (-(noLineDepths-1)/2:1:(noLineDepths-1)/2)*depthstep;

[D, E] = meshgrid( depthtab, eltab);
radPos = sqrt( (D-tubedepth).^2+E.^2 );
velTab = (1-(radPos/radius).^2)*vel_high+vel_low;
velTab( radPos > radius) = NaN;

GTdepth = depthtab-tubedepth;
GTveltab = (1-(GTdepth/radius).^2)*vel_high+vel_low;


unitVec = [sind(btfAZ)*cosd(btfEL) cosd(btfAZ)*cosd(btfEL) sind(btfAZ)].';

ctr = 1;
for kk = 1:length( D(:) ),
    if isnan( velTab(kk) )
        continue;
    end
    time_max = flowlength/velTab(kk);
    currtubedepth = D(kk); %depthtab(kk);
    currtubeelpos = E(kk); %eltab(kk);
    flowField(ctr).timetab = linspace(0, time_max, npoints);
%     flowField(ctr).postab = velTab(kk)*(flowField(ctr).timetab-time_max/2).*[sind(btfAZ); 0; cosd(btfAZ)]+[0; currtubeelpos; currtubedepth];
    flowField(ctr).postab = velTab(kk)*(flowField(ctr).timetab-time_max/2).*unitVec+[0; currtubeelpos; currtubedepth];
    flowField(ctr).timetab = flowField(ctr).timetab.'; 
    flowField(ctr).postab = flowField(ctr).postab.';
    ctr = ctr + 1;
end

if nargin > 1,
    projZ = Z-X/tand(btfAZ);
    projDist = X/sind(btfAZ);
    GT = interp1( depthtab, GTveltab, projZ);
    GT( abs( projDist) > flowlength/2 ) = NaN;
end