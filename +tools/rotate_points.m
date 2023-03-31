function [x, y, z] = rotate_points(x, y, z, theta, phi)
	
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

