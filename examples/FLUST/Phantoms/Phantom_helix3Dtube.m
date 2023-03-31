function [flowField, GT] = Phantom_helix3Dtube( p, X, Z ) % parameter structure p not used in this example

%% small 3D tube phantom, run and check signal integrity in the middle of the tube
btf = 60;
npoints = 10;
revolvspeed = 10; %points per rotation
flowlength = 0.0024; %0.005; %0.03; %0.005;
tubedepth = 0.015; %0.03;
radius = 0.001; %0.0005;
depthstep = 0.0002; %0.00015; %lambda/2 for 5 MHz
noLineDepths = ceil( 2*radius/depthstep)+1; %odd number
vel_low = 0.5;
vel_high = 0.5;
% veltab = linspace( vel_low, vel_high, noLineDepths);
% veltab = linspace( vel_high, vel_low, noFlowLines);

% depthtab = (-(noLineDepths-1)/2:1:(noLineDepths-1)/2)*depthstep+tubedepth;
depthtab = (-(noLineDepths-1)/2:1:(noLineDepths-1)/2)*depthstep;
eltab = (-(noLineDepths-1)/2:1:(noLineDepths-1)/2)*depthstep;

[D, E] = meshgrid( depthtab, eltab);
radPos = sqrt( D.^2+E.^2 );
velTab = (1-(radPos/radius).^2)*vel_high+vel_low;
velTab( radPos > radius) = NaN;

GTdepth = depthtab-tubedepth;
GTveltab = (1-(GTdepth/radius).^2)*vel_high+vel_low;

ctr = 1;
for kk = 1:length( D(:) ),
    if isnan( velTab(kk) )
        continue;
    end
    time_max = flowlength/velTab(kk);
%     origtubedepth = D(kk); %depthtab(kk);
%     origtubeelpos = E(kk); %eltab(kk);
    phasefact = exp( 1i* 2*pi*(1:npoints)/revolvspeed );
%     currtubepos = [cosd(ang) sind(ang); -sind(ang) cosd(ang)]*[origtubedepth origtubeelpos];
    
    origtubepos = D(kk)+1i*E(kk);
    currtubepos = origtubepos.*phasefact;
    currdepth = real( currtubepos);
    currelpos = imag( currtubepos);
    
%     currdepth = currtubepos(1);
%     currelpos = currtubepos(2);
    
    flowField(ctr).timetab = linspace(0, time_max, npoints);
    flowField(ctr).postab = velTab(kk)*(flowField(ctr).timetab-time_max/2).*[sind(btf); 0; cosd(btf)]+ ...
        [zeros(1, npoints); currelpos; currdepth] + ...
        [0; 0; tubedepth];
    flowField(ctr).timetab = flowField(ctr).timetab.'; 
    flowField(ctr).postab = flowField(ctr).postab.';
    ctr = ctr + 1;
end

if nargin > 1,
    projZ = Z-X/tand(btf);
    projDist = X/sind(btf);
    GT = interp1( depthtab, GTveltab, projZ);
    GT( abs( projDist) > flowlength/2 ) = NaN;
end