function flowField = Phantom_small2Dtube( p ) % parameter structure p not used in this example

%% small 2D tube phantom, run and check signal integrity in the middle of the tube
btf = 60;
npoints = 10;
flowlength = 0.005;
tubedepth = 0.015; %0.03;
depthstep = 0.00015; %lambda/2 for 5 MHz
noFlowLines = 1; %odd number
max_vel = 1;


depthtab = (-(noFlowLines-1)/2:1:(noFlowLines-1)/2)*depthstep+tubedepth;
time_max = flowlength/max_vel;


for kk = 1:noFlowLines,
    currtubedepth = depthtab(kk);
    flowField(kk).timetab = linspace(0, time_max, npoints);
    flowField(kk).postab = max_vel*(flowField(kk).timetab-time_max/2).*[sind(btf); 0; cosd(btf)]+[0; 0; currtubedepth];
    flowField(kk).timetab = flowField(kk).timetab.'; 
    flowField(kk).postab = flowField(kk).postab.';
end