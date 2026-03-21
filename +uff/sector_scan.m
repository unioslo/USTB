classdef sector_scan < uff.scan
    %SECTOR_SCAN   UFF data class for a polar/sector pixel grid
    %
    %   SECTOR_SCAN defines a grid in spherical coordinates using
    %   azimuth_axis, elevation_axis, and depth_axis vectors. Commonly
    %   used with phased array probes.
    %
    %   Properties:
    %       azimuth_axis        azimuth angles [rad]
    %       elevation_axis      elevation angles [rad]
    %       depth_axis          depth (radial distance) [m]
    %       origin              UFF.POINT scan-line origin(s)
    %       transform           UFF.TRANSFORM applied to pixel positions
    %
    %   Dependent properties:
    %       N_azimuth_axis      number of azimuth samples
    %       N_elevation_axis    number of elevation samples
    %       N_depth_axis        number of depth samples
    %       depth_step          step size in depth [m]
    %       reference_distance  distance for phase term calculation [m]
    %
    %   Example:
    %       scan = uff.sector_scan('azimuth_axis', linspace(-pi/6, pi/6, 128).', ...
    %                              'depth_axis', linspace(0, 80e-3, 256).');
    %
    %   See also UFF.SCAN, UFF.LINEAR_SCAN

    %   authors:    Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>
    %               Anders E. Vrålstad <anders.e.vralstad@ntnu.no>
    %               Stefano Fiorentini <stefano.fiorentini@ntnu.no>
    %   Date: 2023/10/27

    properties  (Access = public)
        azimuth_axis = 0            % Vector containing the azimuth coordinates [rad]
        elevation_axis = 0          % Vector containing the elevation coordinates [rad]
        depth_axis = 0              % Vector containing the distance coordinates [m]
        transform                   % Vector of uff.transform objects
        origin                      % Vector of uff.point objects
    end
    
    properties  (Dependent)
        N_azimuth_axis            % Number of pixels in azimuth_axis
        N_elevation_axis          % Number of pixels in elevation_axis
        N_depth_axis              % Number of pixels in depth_axis
        N_origins                 % Number of scanline origins
        azimuth_step              % Step size along the azimuth axis [rad]
        elevation_step            % Step size along the elevation axis [rad]
        depth_step                % Step size along the depth axis [m]
        reference_distance        % Distance used for the calculation of the phase term [m]      
    end
    
    properties (Access = private)
        rho                       % Depth coordinates [m]
    end
    
    %% constructor -> uff constructor
    methods (Access = public)
        function h=sector_scan(varargin)
            h = h@uff.scan(varargin{:});

            if isempty(h.transform)
                h.transform = uff.transform();
            end

            if isempty(h.origin)
                h.origin = uff.point();
            end
        end
    end
    
    %% update pixel position
    methods (Access = private)
        function update_pixel_position(h)
            if isempty(h.azimuth_axis) || isempty(h.elevation_axis) || isempty(h.depth_axis) || isempty(h.origin) || isempty(h.transform)
                return
            end

            if h.N_azimuth_axis == 1 && h.N_elevation_axis == 1 % Parameter are not set yet
                return
            end

            if all(size(h.origin) == [h.N_elevation_axis,h.N_azimuth_axis]) % Transpose if stored incorrectly
                h.origin = h.origin.';
            end
            
            assert(h.N_origins == 1 || all(size(h.origin) == [h.N_azimuth_axis, h.N_elevation_axis]), ...
                'Number of origins should be either one or equal to the number of scan lines.');
                     
            % Defining the pixel grid
            [rho, theta, phi] = ndgrid(h.depth_axis, h.azimuth_axis, h.elevation_axis); %#ok<*PROP>

            % Storing in case the reference distance is needed
            h.rho = rho(:);

            N_pixels = numel(rho);

            % position of the pixels
            [Z, Y, X] = sph2cart(phi, theta, rho);
            
            % Define origin of scan lines
            if isscalar(h.origin)
                X0 = h.origin.x;
                Y0 = h.origin.y;
                Z0 = h.origin.z;
            else
                X0 = reshape([h.origin.x], [1, h.N_azimuth_axis, h.N_elevation_axis]);
                Y0 = reshape([h.origin.y], [1, h.N_azimuth_axis, h.N_elevation_axis]);
                Z0 = reshape([h.origin.z], [1, h.N_azimuth_axis, h.N_elevation_axis]);
            end

            xyz = [reshape(X + X0, [N_pixels, 1]), ...
                reshape(Y + Y0, [N_pixels, 1]), reshape(Z + Z0, [N_pixels, 1])];

            for n = 1:length(h.transform)
                xyz = h.transform(n).apply_transform(xyz);
            end

            h.x = xyz(:,1);
            h.y = xyz(:,2);
            h.z = xyz(:,3);
        end
    end
    
    %% Set methods
    methods
        function set.azimuth_axis(h,in_azimuth_axis)
            validateattributes(in_azimuth_axis, {'single', 'double'}, {'real', 'vector'})
            h.azimuth_axis=in_azimuth_axis(:);
            h.update_pixel_position();
        end
        function set.elevation_axis(h,in_elevation_axis)
            validateattributes(in_elevation_axis, {'single', 'double'}, {'real', 'vector'})
            h.elevation_axis=in_elevation_axis(:);
            h.update_pixel_position();
        end
        function set.depth_axis(h,in_depth_axis)
            validateattributes(in_depth_axis, {'single', 'double'}, {'real', 'vector'})
            h.depth_axis=in_depth_axis(:);
            h.update_pixel_position();
        end
        function set.transform(h,in_transform)
            validateattributes(in_transform, {'uff.transform'}, {'vector'})
            h.transform=in_transform(:);
            h.update_pixel_position();
        end
        function set.origin(h,in_origin)
            validateattributes(in_origin, {'uff.point'}, {'2d'})
            h.origin=in_origin;
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
            value = mean(diff(h.depth_axis));
        end
        function value=get.reference_distance(h)
            value = h.rho;
        end
        function value=get.N_origins(h)
            value=numel(h.origin);
        end
    end
end

