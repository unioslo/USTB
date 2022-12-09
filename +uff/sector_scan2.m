classdef sector_scan2 < uff.scan
    %SECTOR_SCAN2   UFF class to define a linear scan 
    %   SECTOR_SCAN contains the position of the azimuth and depth axis
    %   from position origins.
    %
    %
    %   See also UFF.SCAN, UFF.SECOR_SCAN
    %   authors:    Anders E. Vrålstad (anders.e.vralstad@ntnu.no)
    %   $Date: 2022/12/07 $

    properties  (Access = public)
        azimuth_axis                % Vector containing the azimuth coordinates of the azimuth axis [rad]
        depth_axis                  % Vector containing the distance coordinates of the distance axis [m]
        origins                     % uff.probe object containing the originating coordinats for the scanlines
    end
    
    properties  (Dependent)
        N_azimuth_axis            % number of pixels in the x_axis
        N_depth_axis              % number of pixels in the z_axis
        depth_step                % the step size in m of the depth samples
        reference_distance        % distance used for the calculation of the phase term      
    end
    
    properties (Access = private)
        theta                     % azimuth coordinates in radians
        rho                       % depth coordinates in m
    end
    
    %% constructor -> uff constructor
    methods (Access = public)
        function h=sector_scan2(varargin)
            h = h@uff.scan(varargin{:});
            h.update_pixel_position();
            if ~isa(h.origins, 'uff.probe'), h.origins = uff.probe('geometry',[0,0,0]); end
        end
    end
    
    %% update pixel position
    methods 
        function h=update_pixel_position(h)
            if isempty(h.azimuth_axis)||isempty(h.depth_axis)||isempty(h.origins) return; end
            
            % Find origins
            if h.origins.N_elements == 1
               scanline_origins = uff.probe('geometry',zeros(h.N_azimuth_axis,7));
            else
                scanline_origins = uff.probe('geometry',h.origins.geometry);
            end

            % defining the pixel mesh s
            [h.theta h.rho]=meshgrid(h.azimuth_axis,h.depth_axis);

            origins_x = repelem(scanline_origins.x,h.N_depth_axis,1);
            origins_y = repelem(scanline_origins.y,h.N_depth_axis,1);
            origins_z = repelem(scanline_origins.z,h.N_depth_axis,1);

            h.theta=h.theta(:);
            h.rho=h.rho(:);

            origins_x = origins_x(:);
            origins_y = origins_y(:);
            origins_z = origins_z(:);
            
            % position of the pixels
            h.x=h.rho.*sin(h.theta)+origins_x;
            h.y=0.*h.rho+origins_y;
            h.z=h.rho.*cos(h.theta)+origins_z;
        end
    end
    
    %% Set methods
    methods
        function h=set.azimuth_axis(h,in_azimuth_axis)
            assert(size(in_azimuth_axis,2)==1, 'The input must be a column vector.')
            h.azimuth_axis=in_azimuth_axis;
            h=h.update_pixel_position();
        end
        function h=set.depth_axis(h,in_depth_axis)
            assert(size(in_depth_axis,2)==1, 'The input vector must be a column vector.')
            h.depth_axis=in_depth_axis;
            h=h.update_pixel_position();
        end
        function h=set.origins(h,in_origins)
            assert(isa(in_origins,'uff.probe'), 'The input is not a PROBE class. Check HELP SOURCE');
            if ~isempty(h.azimuth_axis); assert(isequal(in_origins.N_elements,h.N_azimuth_axis), 'The number of origins is different from the numbers of azimuth angles.'); end;
            h.origins=in_origins;
            h=h.update_pixel_position();
        end
    end
    
    %% Get methods
    methods
        function value=get.N_azimuth_axis(h)
            value=numel(h.azimuth_axis);
        end
        function value=get.N_depth_axis(h)
            value=numel(h.depth_axis);
        end      
        function value=get.depth_step(h)
            value = mean(diff(h.depth_axis(1:end)));
        end
        function value=get.reference_distance(h)
            value = h.rho;
        end
    end
   
end

