classdef sector_scan_3D < uff.scan
    %SECTOR_SCAN   UFF class to define a sector scan 
    %   SECTOR_SCAN contains the position of the azimuth, elevations and depth axis
    %   from a position apex. NB! Azimuth and elevation is given x as
    %   pointing axis.
    %
    %   Compulsory properties:
    %         azimuth_axis     % Vector containing the azimuth coordinates of the azimuth axis [rad]
    %         elevation_axis   % Vector containing the elevation coordinates of the elevation axis [rad]
    %         depth_axis       % Vector containing the distance coordinates of the distance axis [m]
    %
    %   Example:
    %         sca = uff.sector_scan_3D();
    %         sca.azimuth_axis = linspace(-pi/4,pi/4,64);
    %         sca.azimuth_axis = linspace(-pi/4,pi/4,64);
    %         sca.depth_axis   = linspace(0, 70e-2, 256);
    %         scan.plot()
    %
    %   See also UFF.SCAN, UFF.LINEAR_SCAN

    %   authors: Alfonso Rodriguez-Molares (alfonso.r.molares@ntnu.no)
    %   $Date: 2017/06/18 $

    properties  (Access = public)
        azimuth_axis                % Vector containing the azimuth coordinates of the azimuth axis [rad]
        elevation_axis              % Vector containing the azimuth coordinates of the elevation axis [rad]
        depth_axis                  % Vector containing the distance coordinates of the distance axis [m]
        transform = uff.transform();
    end
    
    properties  (Dependent)
        N_azimuth_axis            % number of pixels in azimuth_axis
        N_elevation_axis          % number of pixels in elevation_axis
        N_depth_axis              % number of pixels in depth_axis
        depth_step                % the step size in m of the depth samples
        reference_distance        % distance used for the calculation of the phase term
    end
    
    %% constructor -> uff constructor
    methods (Access = public)
        function h=sector_scan_3D(varargin)
            h = h@uff.scan(varargin{:});
            h.update_pixel_position();
        end
    end
    
    %% update pixel position
    methods 
        function update_pixel_position(h)
            if isempty(h.azimuth_axis)||isempty(h.depth_axis)||isempty(h.elevation_axis)
                return
            end
            
            % defining the pixel mesh 
            [D, AZ, EL] = ndgrid(h.depth_axis, h.azimuth_axis, h.elevation_axis);
            
            % position of the pixels
            [z, y, x] = sph2cart(EL, AZ, D);
            xyz = [x(:), y(:), z(:)];
            
            for i = 1:length(h.transform)
                xyz = h.transform(i).apply_transform(xyz);
            end
            
            h.x = xyz(:,1);
            h.y = xyz(:,2);
            h.z = xyz(:,3);
        end
    end
    
    %% Set methods
    methods
        function set.azimuth_axis(h,in_azimuth_axis)
            validateattributes(in_azimuth_axis, {'numeric'}, {'real', 'vector'})
            h.azimuth_axis=in_azimuth_axis(:);
            h.update_pixel_position();
        end
        function set.elevation_axis(h,in_elevation_axis)
            validateattributes(in_elevation_axis, {'numeric'}, {'real', 'vector'})
            h.elevation_axis=in_elevation_axis(:);
            h.update_pixel_position();
        end
        function set.depth_axis(h,in_depth_axis)
            validateattributes(in_depth_axis, {'numeric'}, {'real', 'vector'})
            h.depth_axis=in_depth_axis(:);
            h.update_pixel_position();
        end
        function set.transform(h,in_transform)
            assert(isa(in_transform,'uff.transform'), 'The input is not a TRANSFORM class. Check HELP UFF.POINT');
            h.transform=in_transform(:);
            h.update_pixel_position();
        end
    end
    
    %% Get methods
    methods
        function value=get.N_azimuth_axis(h)
            value=numel(h.azimuth_axis);
        end
        function value=get.N_elevation_axis(h)
            value=numel(h.elevation_axis);
        end
        function value=get.N_depth_axis(h)
            value=numel(h.depth_axis);
        end      
        function value=get.depth_step(h)
            value = mean(diff(h.depth_axis(1:end)));
        end
        function value=get.reference_distance(h)
            value = h.z;
        end
    end
   
end

