%
% Functions used in Module 2, IN3015/4015, 
% Dept. of Informatics, University of Oslo, Norway
%
% Version 1.0
% August 31, 2021.
%


function f = k_wave_lib()
    f.defineSimulation = @defineSimulation;
    f.plotResponse = @plotResponse;
end

function [kgrid, medium, source] =  defineSimulation(c0, f0, ...
    num_elements, steering_angle, rFocus, cycles, Nx, Ny, dx, dy, x_offset);

% define the properties of the propagation medium
medium.sound_speed = c0;  % [m/s]
%medium.alpha_coeff = 0;    
%medium.alpha_power = 1.5;

% create kgrid & the time array
kgrid = kWaveGrid(Nx, dx, Ny, dy);
kgrid.makeTime(medium.sound_speed);

% define source mask for a linear transducer with an odd number of elements  
source.p_mask = zeros(Nx, Ny);
start_index = round(Ny/2) - floor(num_elements/2) + 1;
source.p_mask(x_offset, start_index:start_index + num_elements - 1) = 1;

% define the properties of the tone burst used to drive the transducer
sampling_freq = 1/kgrid.dt;     % [Hz]
element_spacing = dx;           % [m]
tone_burst_freq = f0;           % [Hz]
tone_burst_cycles = cycles;

% Source positions (in grid units) 
[sx,sy] = meshgrid(x_offset,start_index:start_index + num_elements - 1);

% Set focal point (in grid units)
fx = round(rFocus/dx + x_offset)*cosd(steering_angle);
fy = round(Ny/2)+1 + round(rFocus/dx + x_offset)*sind(steering_angle);

% Distance from source to focal point [m]
d = sqrt((sx-fx).^2*dx^2 + (sy-fy).^2*dy^2);

% Travel time (in sample units)
t = round(d/c0/kgrid.dt);

% Time delay [in sample units] 
offset = 10;
delay = offset + max(t) - t;

% create the tone burst signals
source.p = toneBurst(sampling_freq, tone_burst_freq, tone_burst_cycles, ...
    'SignalOffset', delay);

end

function plotResponse(sensor_data, source, kgrid, t, PMLSize);

% Read out source positions and offset. Find shift of x-axis.
[I, J] = ind2sub(size(source.p_mask),find(source.p_mask));
x_offset = min(I);
x_ind = [x_offset:length(kgrid.x_vec)];

start_index = min(J);
num_elements = length(J);

% get the number of time points in the source signal
num_source_time_points = length(source.p(1,:));

% get suitable scaling factor for plot axis
[~, scale, prefix] = scaleSI(kgrid.t_array(num_source_time_points));
%
% plot the input time series
figure; % clf;
stackedPlot(kgrid.t_array(1:num_source_time_points) * scale, source.p);
xlabel(['Time [' prefix 's]']);
ylabel('Input Signals');


%
% plot the rms recorded pressure

figure; % clf

% Making temporal axis and variable
ax = kgrid.x_vec(x_ind) - kgrid.x_vec(x_offset);
ay = kgrid.y_vec;
tmp_p = sensor_data.p_rms(x_ind,:);

imagesc(ay * 1e3, ax * 1e3, tmp_p);
colormap(getColorMap);
ylabel('x-position [mm]');
xlabel('y-position [mm]');

% Plot -3 dB contour relative to max

cAxis = caxis;

hold on
[M,c] = contour(ay*1e3, ax*1e3, ...
    db(tmp_p / max(tmp_p(:))), [-3 -6],'--');
c.LineWidth = 2;
hold off

% Plot -3 & -6 dB contour adjusted for gain loss



% Convert til polar representation, scale, and convert back
[polarImage, angle, radius] = inverse_scan_convert( ...
    tmp_p, ay, ax);

maxRadius = max(polarImage,[],2);
pImage = polarImage./repmat(maxRadius,[1 size(polarImage,2)]);
[~, stopIndex] = min(abs(radius - max(ax)));
pImage(stopIndex-10:end,:) = 0;

[scaledImage Ys Xs] = scan_convert(pImage, angle, radius, 777, 777);

scaledImage = scaledImage/max(scaledImage(:));

% Crop image to avoid scaling of axis
[~, Y1] = min(abs(Ys - ay(1)));
[~, Y2] = min(abs(Ys - ay(end)));
[~, X1] = min(abs(Xs - ax(1)));
[~, X2] = min(abs(Xs - ax(end)));
scaledImage = scaledImage(X1:X2,Y1:Y2);
Ys = Ys(Y1:Y2);
Xs = Xs(X1:X2);

% Plot -3 and -6 dB contour on original data
hold on
[M,c] = contour(Ys*1e3, Xs*1e3, db(scaledImage), [-3 -6],'LineColor','b');
c.LineWidth = 2;
hold off
caxis(cAxis)

% Plot sensor
hold on;
Y1 = start_index;
Y2 = start_index + num_elements - 1;
X1 = x_offset-2;
X2 = x_offset;

X = [X1 X2 X2 X1];
Y = [Y1 Y1 Y2 Y2];

patch(kgrid.y_vec(Y) * 1e3, ...
    (kgrid.x_vec(X) - kgrid.x_vec(x_offset)) * 1e3,'green');
hold off

axis tight; axis image; 
title('RMS Pressure');
%title(['RMS Pressure, Focal range: ',num2str(rFocus*1e3,'%.0f'), ...
%    ' mm. No cycles: ',int2str(cycles)]);
tmpTxt = {...
    ['f0 = ',num2str(t.f0/1e6,'%.1f'),' MHz'], ...
    ['c = ',num2str(t.c,'%d'),' m/s'], ...
    ['rFocus = ',num2str(t.rFocus*1e3,'%.1f'),' mm'], ...
    ['No. cycles = ',num2str(t.cycles,'%.1f')], ...
    ['Aperture size = ',num2str(t.D*1e3,'%.1f'),' mm'], ...
    ['Steered to ',num2str(t.angle,'%.1f'),' deg']};
text((min(ay)+ 0.03*(max(ay)-min(ay)))*1e3, ...
    (min(ax)+ 0.03*(max(ax)-min(ax)))*1e3, ...
    tmpTxt, ...
    'HorizontalAlignment','left','VerticalAlignment','top', ...
    'Color','white');
    
end

function [polarImage, angle, radius] = inverse_scan_convert(inputImage, xs, zs, noAng, noR, interpolationMethod)

% Set parameters to default values if they are not provdied
if nargin<6
  interpolationMethod = 'linear';
end
if nargin<4
  noAng = 181;
  noR = 256;
end

% Get the theta and range for every sample and put them in grids the size of inputImage
[xGrid, zGrid] = meshgrid(xs, zs);

% Find the "box" in cartesian coordinates that encapsulates all our samples
[Th, Ra] = cart2pol(xGrid, zGrid);
Th = Th - pi/2;
maxT = max(abs(Th(:)));
minR = min(Ra(:));
maxR = max(Ra(:));

% Find the carthesian coordinates for the samples we want as output, ..
angle = -maxT:(2*maxT)/(noAng-1):maxT;
radius = minR:(maxR-minR)/(noR-1):maxR;
[Ts, Rs] = meshgrid(angle, radius);

% .. and then get what these samples are in polar coordinates:
[ZGridOut, XGridOut] = pol2cart(Ts, Rs);

% Finally do a simple linear interpolation in polar-coordinate-space:
polarImage = interp2(double(xGrid), double(zGrid), double(inputImage), ...
    double(XGridOut), double(ZGridOut), interpolationMethod,0);

end

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
scanConvertedImage = interp2(double(thetaGrid), double(rangeGrid), double(inputImage), double(thetaGridOut), double(rangeGridOut), interpolationMethod,0);

% We are resampling using a rectangular grid, so need only the X-s and the Z-s as vectors:
Xs = Xs(1,:)';
Zs = Zs(:,1);

end



