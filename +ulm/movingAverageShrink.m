function ys = movingAverageShrink(y, span)
%MOVINGAVERAGESHRINK Moving average matching smooth(y,span,'moving').
% Uses the full span in the interior of y, and symmetrically shrinks the
% window near each edge (1,3,5,...,span), the same way
% smooth(y,span,'moving') does. This differs from movmean(y,span)'s own
% edge handling, which does not shrink symmetrically and, for a span
% comparable to length(y) (as ulm.tracking2D's smooth_factor can be for
% short tracks), ends up flattening most of the reconstructed signal
% rather than just its edges.
%
% Exists so ulm.tracking2D and ulm.Track2MatOut can smooth tracks
% without depending on the Curve Fitting Toolbox's smooth().
%
% INPUTS:
%       - y: numeric vector to smooth
%       - span: window size (reduced by one if even, matching smooth())
% OUTPUT:
%       - ys: smoothed vector, same size as y

y = y(:);
n = numel(y);
if mod(span, 2) == 0
    span = span - 1; % smooth() reduces an even span by one
end
halfwidth = (span - 1) / 2;

ys = zeros(n, 1, 'like', y);
for i = 1:n
    w = min([halfwidth, i - 1, n - i]);
    ys(i) = mean(y((i - w):(i + w)));
end
end
