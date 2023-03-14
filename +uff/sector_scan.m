classdef sector_scan < uff.scan
    %SECTOR_SCAN   UFF class to define a sector scan 
    %   SECTOR_SCAN contains the position of the azimuth and depth axis
    %   from an origin. If more origins are present
    %
    %   Compulsory properties:
    %         azimuth_axis         % Vector containing the azimuth coordinates [rad]
    %         depth_axis           % Vector containing the distance coordinates [m]
    %         origin               % Vector of UFF.POINT objects
    %
    %   Example:
    %         sca = uff.linear_scan();
    %         sca.x_axis=linspace(-20e-3,20e-3,256);
    %         sca.z_axis=linspace(0e-3,40e-3,256);
    %         scan.plot()
    %
    %   See also UFF.SCAN, UFF.LINEAR_SCAN

    %   authors:    Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>
    %               Anders E. Vrålstad <anders.e.vralstad@ntnu.no>
    %               Stefano Fiorentini <stefano.fiorentini@ntnu.no>
    %   $Date: 2022/12/20$

    properties  (Access = public)
        azimuth_axis                % Vector containing the azimuth coordinates [rad]
        depth_axis                  % Vector containing the distance coordinates [m]
        origin                      % Vector of UFF.POINT objects
    end
    
    properties  (Dependent)
        N_azimuth_axis            % Number of pixels in azimuth_axis
        N_depth_axis              % Number of pixels in depth_axis
        N_origins                 % Number of scanline origins
        depth_step                % Step size along the depth axis [m]
        reference_distance        % Distance used for the calculation of the phase term [m]      
    end
    
    properties (Access = private)
        theta                     % Azimuth coordinates [rad]
        rho                       % Depth coordinates [m]
    end
    
    %% constructor -> uff constructor
    methods (Access = public)
        function h=sector_scan(varargin)
            h = h@uff.scan(varargin{:});

            if isempty(h.origin)
                h.origin = uff.point();
            end
        end
    end
    
    %% update pixel position
    methods (Access = private)
        function h=update_pixel_position(h)
            if isempty(h.azimuth_axis) || isempty(h.depth_axis) || isempty(h.origin) 
                return
            end
            
            assert(h.N_origins == 1 || h.N_origins == h.N_azimuth_axis, ...
                'Number of origins should be either one or equal to the number of scan lines.');
            
            % Defining the pixel mesh
            [rho, theta] = ndgrid(h.depth_axis, h.azimuth_axis); %#ok<*PROP>
            
            N_pixels = numel(rho);
            
            % Define origin struct
            x0 = [h.origin.x];
            y0 = [h.origin.y];
            z0 = [h.origin.z];
            
            % Storing in case the reference distance is needed
            h.rho = rho(:);
            h.theta = theta(:);
            
            % position of the pixels
            h.x=reshape(rho.*sin(theta)+x0, [N_pixels, 1]);
            h.y=reshape(zeros(size(rho))+y0, [N_pixels, 1]);
            h.z=reshape(rho.*cos(theta)+z0, [N_pixels, 1]);
        end
    end
    
    %% Set methods
    methods
        function set.azimuth_axis(h,in_azimuth_axis)
            validateattributes(in_azimuth_axis, {'single', 'double'}, {'vector'})
            h.azimuth_axis=in_azimuth_axis(:);
            h.update_pixel_position();
        end
        function set.depth_axis(h,in_depth_axis)
            validateattributes(in_depth_axis, {'single', 'double'}, {'vector'})
            h.depth_axis=in_depth_axis(:);
            h.update_pixel_position();
        end
        function set.origin(h,in_origin)
            validateattributes(in_origin, {'uff.point'}, {'vector'})
            h.origin=in_origin(:);
            h.update_pixel_position();
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
        function value=get.N_origins(h)
            value=numel(h.origin);
        end
    end
end

