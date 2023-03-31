function [varargout] = my_arrow(start,stop,varargin)
arrow_gap_pc = 0.02; % defines gap size relative to size of initial arrow
d=stop-start;
if length(d)==3
    dx=d(1);dy=d(2);dz=d(3);
else
    dx=d(1);dy=d(2);dz=0;
    stop = [stop 0];
    start = [start 0];
end
[th,phi,r] = cart2sph(dx,dy,dz);
arrow_gap = arrow_gap_pc*r;
[x1,y1,z1] = sph2cart(th,phi,arrow_gap);
b = start+[x1 y1 z1];
e = stop-[x1 y1 z1];
if rem(nargin,2)
  ah = arrow(b,e,varargin{1},varargin{2:end});
else
  ah = arrow(b,e,varargin{1:end});
end    
if nargout == 1
    varargout{1} = ah;
end