%GETSCANCONVERTEDIMAGE Converts an image from polar to carthesian coordinates.
%
% [scanConvertedImage, Xs, Zs] = getScanConvertedImage(inputImage, thetas, ranges, sizeX, sizeZ, interpolationMethod)
%
% inputImage   : A range x beams sized image
% thetas       : A vector containing the beam angles (in radians)
% ranges       : A vector containing the ranges (in meters) for the beams' samples
% sizeX, sizeZ : The pixel size of the output image; default is 512x512
% interpolationMethod : One of the interpolation methods in the 'interp2' method; default is 'linear'
%
% An example use of the function output:
% >> imagesc(Xs, Zs, scanConvertedImage)
%
% Last modified:
% 2009.09.10 - Are C. Jensen {Created the function (more of a rewrite/cleanup of Austeng's code)}
function [scanConvertedImage, Xs, Zs] = scan_convert(inputImage, thetas, ranges, sizeX, sizeZ, interpolationMethod)

% Set parameters to default values if they are not provdied
if nargin<6
  interpolationMethod = 'linear';
end
if nargin<4
  sizeX = 512;
  sizeZ = 512;
end

% Get the theta and range for every sample and put them in grids the size of inputImage
[thetaGrid, rangeGrid] = meshgrid(thetas, ranges);

% Find the "box" in cartesian coordinates that encapsulates all our samples
[z, x] = pol2cart(thetaGrid, rangeGrid);
minX = min(x(:));
maxX = max(x(:));
minZ = min(z(:));
maxZ = max(z(:));

% Find the carthesian coordinates for the samples we want as output, ..
Xs = minX:(maxX-minX)/(sizeX-1):maxX;
Zs = minZ:(maxZ-minZ)/(sizeZ-1):maxZ;
[Xs Zs] = meshgrid(Xs, Zs);

% .. and then get what these samples are in polar coordinates:
[thetaGridOut, rangeGridOut] = cart2pol(Zs, Xs);

% Finally do a simple linear interpolation in polar-coordinate-space:
scanConvertedImage = interp2(double(thetaGrid), double(rangeGrid), double(inputImage), double(thetaGridOut), double(rangeGridOut), interpolationMethod,-inf);

% We are resampling using a rectangular grid, so need only the X-s and the Z-s as vectors:
Xs = Xs(1,:)';
Zs = Zs(:,1);

