function [x, y, z] = rotate_points(x, y, z, theta, phi)
    %ROTATE_POINTS   Rotate 3-D points by azimuth and elevation angles
    %
    %   [x, y, z] = tools.rotate_points(x, y, z, theta, phi)
    %
    %   Parameters:
    %       x, y, z     point coordinates (matrices)
    %       theta       azimuth rotation angle [rad]
    %       phi         elevation rotation angle [rad]

    % rotate azimuth
	if abs(theta)>0
        xp = x*cos(theta) - z*sin(theta);
        zp  = x*sin(theta) + z*cos(theta);
        x=xp; 
        z=zp;
    end
   
    % rotate phi
    if abs(phi)>0
        yp = y*cos(phi) - z*sin(phi);
        zp = y*sin(phi) + z*cos(phi);
        y=yp; 
        z=zp;
    end
    
end

