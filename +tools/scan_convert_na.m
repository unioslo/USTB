%GETSCANCONVERTEDIMAGE Converts an image from beamspace to carthesian coordinates.
%
% [scanConvertedImage, Xs, Zs] = scan_convert_na(inputImage, thetas, ranges, sizeX, sizeZ, interpolationMethod)
%
% inputImage   : A range x beams sized image
% thetas       : A vector containing the beam angles (in radians)
% ranges       : A vector containing the ranges (in meters) for the beams' samples
% origins      : A vector containing the origins for each scanline
% sizeX, sizeZ : The pixel size of the output image; default is 512x512
% interpolationMethod : One of the interpolation methods in the 'interp2' method; default is 'linear'
%
% An example use of the function output:
% >> imagesc(Xs, Zs, scanConvertedImage)
%
% Last modified:
% 2009.09.10 - Are C. Jensen {Created the function (more of a rewrite/cleanup of Austeng's code)}
% 2022.12.09 - Anders E. Vrålstad
function [scanConvertedImage, Xs, Zs] = scan_convert_na(inputImage, thetas, ranges,origins, sizeX, sizeZ, interpolationMethod)

% Set parameters to default values if they are not provdied
if nargin<7
  interpolationMethod = 'linear';
end
if nargin<5
  sizeX = 512;
  sizeZ = 512;
end

% Check sizes of input
assert(size(thetas,1)==size(origins,1),'This scan convertion requires the size of thetas to be similar to origins.');

% Get the cartesian coordinates corresponding to the beamspace pixels in inputImage
[thetaGrid, rangeGrid] = meshgrid(thetas, ranges);

[z, x] = pol2cart(thetaGrid, rangeGrid);
z = z+origins(:,3)';
x = x+origins(:,1)';

% Find the "box" in cartesian coordinates that encapsulates all our samples
minX = min(x(:));
maxX = max(x(:));
minZ = min(z(:));
maxZ = max(z(:));

% Find the carthesian coordinates for the samples we want as output, ..
Xs = minX:(maxX-minX)/(sizeX-1):maxX;
Zs = minZ:(maxZ-minZ)/(sizeZ-1):maxZ;
[Xs, Zs] = meshgrid(Xs, Zs);

% Finally do a simple linear interpolation in cartesian-coordinate-space:
scanConvertedImage = griddata(double(x), double(z), double(inputImage), double(Xs), double(Zs),interpolationMethod);
scanConvertedImage(isnan(scanConvertedImage)) = -Inf;
% We are resampling using a rectangular grid, so need only the X-s and the Z-s as vectors:
Xs = Xs(1,:)';
Zs = Zs(:,1);

