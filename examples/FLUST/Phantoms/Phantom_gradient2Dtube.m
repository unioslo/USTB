function [flowField, p, GT_vel] = Phantom_gradient2Dtube( setup, X, Y, Z ) 

%% small 2D tube phantom with velocity gradient. Set vel_1 and vel_2 equal for plug flow.
p.btf = 60;
p.npoints = 10;
p.flowlength = 0.0024; %0.005; %0.03; %0.005;
p.tubedepth = 0.015; %0.03;
p.maxLineSpacing = 0.0001; %0.00015; %lambda/2 for 5 MHz
p.diameter = 0.001;
p.vel_1 = 0.4;
p.vel_2 = 2;

fields = fieldnames(setup);
for k=1:size(fields,1)
    if(isfield(p,fields{k}))
        p.(fields{k}) = setup.(fields{k});
    else
        disp([ fields{k} ' is not a valid parameter for this phantom type']);
    end
end

noFlowLines = ceil(p.diameter/p.maxLineSpacing)+1;
veltab = linspace( p.vel_1, p.vel_2, noFlowLines);
unitVec = [sind(p.btf); 0; cosd(p.btf)];

depthtab = linspace( p.tubedepth-p.maxLineSpacing*(noFlowLines-1)/2, p.tubedepth+p.maxLineSpacing*(noFlowLines-1)/2, noFlowLines);
for kk = 1:noFlowLines
    time_max = p.flowlength/veltab(kk);
    currtubedepth = depthtab(kk);
    flowField(kk).timetab = linspace(0, time_max, p.npoints);
    flowField(kk).postab = veltab(kk)*(flowField(kk).timetab-time_max/2).*unitVec+[0; 0; currtubedepth];
    flowField(kk).timetab = flowField(kk).timetab.'; 
    flowField(kk).postab = flowField(kk).postab.';
end
if nargin > 1
    projZ = Z-X/tand(p.btf);
    projDist = X/sind(p.btf);
    GT_vel = interp1( depthtab, veltab, projZ);
    GT_vel( abs( projDist) > p.flowlength/2 ) = NaN;
    GT = GT_vel
end