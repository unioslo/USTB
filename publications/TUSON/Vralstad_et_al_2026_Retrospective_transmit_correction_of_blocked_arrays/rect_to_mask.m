function mask = rect_to_mask(rect_pos, Xs, Zs)
%RECT_TO_MASK  Create binary mask from rectangle position [x, z, w, h] on grid (Xs, Zs).
%   rect_pos = [x_left, z_top, width, height] in same units as Xs/Zs.
%   Xs, Zs are 1-D vectors (column coords of the image).
%   Returns logical matrix of size [numel(Zs), numel(Xs)].

x_left = rect_pos(1);
z_top = rect_pos(2);
w = rect_pos(3);
h = rect_pos(4);

x_mask = (Xs >= x_left) & (Xs <= x_left + w);
z_mask = (Zs >= z_top) & (Zs <= z_top + h);

mask = logical(z_mask(:) * x_mask(:)');
end
