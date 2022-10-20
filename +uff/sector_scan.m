classdef sector_scan < uff.scan
    %SECTOR_SCAN   UFF class to define a linear scan 
    %   SECTOR_SCAN contains the position of the azimuth and depth axis
    %   from a position apex.
    %
    %   Compulsory properties:
    %         x_axis           % Vector containing the x coordinates of the x - axis [m]
    %         z_axis           % Vector containing the z coordinates of the z - axis [m]
    %
    %   Example:
    %         sca = uff.linear_scan();
    %         sca.x_axis=linspace(-20e-3,20e-3,256);
    %         sca.z_axis=linspace(0e-3,40e-3,256);
    %         scan.plot()
    %
    %   See also UFF.SCAN, UFF.LINEAR_SCAN

    %   authors: Alfonso Rodriguez-Molares (alfonso.r.molares@ntnu.no)
    %   $Date: 2017/06/18 $

    properties  (Access = public)
        azimuth_axis                % Vector containing the azimuth coordinates of the azimuth axis [rad]
        depth_axis                  % Vector containing the distance coordinates of the distance axis [m]
        apex                        % POINT class
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
        function h=sector_scan(varargin)
            h = h@uff.scan(varargin{:});
            h.update_pixel_position();
            if ~isa(h.apex, 'uff.point'), h.apex = uff.point(); end
        end
    end
    
    %% update pixel position
    methods 
        function h=update_pixel_position(h)
            if isempty(h.azimuth_axis)||isempty(h.depth_axis)||isempty(h.apex) return; end
            
            % defining the pixel mesh 
            [h.theta h.rho]=meshgrid(h.azimuth_axis,h.depth_axis);
            
            h.theta=h.theta(:);
            h.rho=h.rho(:);
            
            % position of the pixels
            h.x=h.rho.*sin(h.theta)+h.apex.x;
            h.y=0.*h.rho+h.apex.y;
            h.z=h.rho.*cos(h.theta)+h.apex.z;
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
        function h=set.apex(h,in_apex)
            assert(isa(in_apex,'uff.point'), 'The input is not a SOURCE class. Check HELP SOURCE');
            h.apex=in_apex;
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

