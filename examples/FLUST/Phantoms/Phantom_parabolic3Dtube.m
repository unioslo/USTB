function [flowField, p, GT] = Phantom_parabolic3Dtube( setup, X, Y, Z ) % 

%% parabolic phantom

p.btfAZ = 60;
p.btfEL = 0;
p.npoints = 10;
p.flowlength = 0.0024; %0.005; %0.03; %0.005;
p.tubedepth = 0.015; %0.03;
p.diameter = 0.003; %0.0005;
p.maxLineSpacing = 0.0001;
p.vel_low = 0.1;
p.vel_high = 2;

if ~isempty(setup)
    fields = fieldnames(setup);
    for k=1:size(fields,1)
        if(isfield(p,fields{k}))
            p.(fields{k}) = setup.(fields{k});
        else
            disp([ fields{k} ' is not a valid parameter for this phantom type']);
        end
    end
end

noLineDepths = ceil( p.diameter/p.maxLineSpacing/2)*2+1; %odd number
eltab = linspace(-p.diameter/2, p.diameter/2, noLineDepths);
depthtab = eltab;

% depthtab = (-(noLineDepths-1)/2:1:(noLineDepths-1)/2)*depthstep+p.tubedepth;
% eltab = (-(noLineDepths-1)/2:1:(noLineDepths-1)/2)*depthstep;

radius = p.diameter/2;
[D, E] = meshgrid( depthtab, eltab);
radPos = sqrt( D.^2+E.^2 );
velTab = (1-(radPos/radius).^2)*(p.vel_high-p.vel_low)+p.vel_low;
velTab( radPos > radius) = NaN;
origPos = [zeros( size( D(:) ) ).'; E(:).'; D(:).'];
rAZ = [cosd(90-p.btfAZ) 0 sind(90-p.btfAZ); 0 1 0; -sind(90-p.btfAZ) 0 cosd(90-p.btfAZ)];
rEL = [1 0 0; 0 cosd(p.btfEL) -sind(p.btfEL); 0 sind(p.btfEL) cosd(p.btfEL)];
rotPos = rEL*rAZ*origPos;
rotZ = rotPos(3,:)+p.tubedepth;
rotY = rotPos(2,:);
rotX = rotPos(2,:);


% GTdepth = depthtab-p.tubedepth;
% GTveltab = (1-(GTdepth/radius).^2)*p.vel_high+p.vel_low;
% unitVec = [sind(p.btfAZ)*cosd(p.btfEL) cosd(p.btfAZ)*cosd(p.btfEL) sind(p.btfAZ)].';
unitVec = rEL*rAZ*[1 0 0].';

ctr = 1;
for kk = 1:length( rotX(:) )
    if isnan( velTab(kk) )
        continue;
    end
    time_max = p.flowlength/velTab(kk);
    flowField(ctr).timetab = linspace(0, time_max, p.npoints);
    flowField(ctr).postab = velTab(kk)*(flowField(ctr).timetab-time_max/2).*unitVec+[rotX(kk); rotY(kk); rotZ(kk)];
    flowField(ctr).timetab = flowField(ctr).timetab.'; 
    flowField(ctr).postab = flowField(ctr).postab.';
    ctr = ctr + 1;
end

if nargin > 1
    posTab = [X(:).'; Y(:).'; Z(:).'-p.tubedepth];
    projTab = posTab-unitVec*unitVec.'*posTab;
    radTab = sqrt( sum( abs( projTab ).^2, 1) );
    axTab = unitVec.'*posTab;
    GT_vel = (1-(radTab/radius).^2)*(p.vel_high-p.vel_low)+p.vel_low;
    GT_vel( abs(radTab) > radius ) = NaN;
    GT_vel( abs(axTab) > p.flowlength/2 ) = NaN;
    GT = (GT_vel.*unitVec).';
end