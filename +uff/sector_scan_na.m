classdef sector_scan_na < uff.scan
    %sector_scan_na   UFF class to define a non-apical sector scan 
    %   SECTOR_SCAN_NA contains the position of the azimuth and depth axis
    %   from position origins. It is non-apical because the scanlines does
    %   not necessarily concentrate in an apex
    %
    %
    %   See also UFF.SCAN, UFF.SECOR_SCAN
    %   authors:    Anders E. Vrålstad (anders.e.vralstad@ntnu.no)
    %   $Date: 2022/12/13 $

    properties  (Access = public)
        azimuth_axis                % Vector containing the azimuth coordinates of the azimuth axis [rad]
        depth_axis                  % Vector containing the distances from the origin [m]
        origins                     % UFF.POINT containing the originating coordinats for the scanlines
    end
    
    properties  (Dependent)
        N_azimuth_axis            % number of scanlines in the azimuthal direction
        N_depth_axis              % number of steps in the depth direction
        N_origins                 % number of scanline origins
        depth_step                % the step size in m of the depth samples
        reference_distance        % distance used for the calculation of the phase term
    end
    
    properties (Access = private)
        theta                     % azimuth coordinates in radians
        rho                       % depth coordinates in m
    end
    
    %% constructor -> uff constructor
    methods (Access = public)
        function h=sector_scan_na(varargin)
            h = h@uff.scan(varargin{:});
            h.update_pixel_position();
            if ~isa(h.origins,'uff.point'), h.origins = uff.point(); end
        end
    end
    
    %% update pixel position
    methods 
        function h=update_pixel_position(h)
            if isempty(h.azimuth_axis)||isempty(h.depth_axis)||isempty(h.origins) return; end
            
            % Defining the pixel mesh s
            [h.theta h.rho]=meshgrid(h.azimuth_axis,h.depth_axis);
            
            % Interpolate origins to be of same number as the number of
            % scanlines
            if h.N_azimuth_axis~=h.N_origins
                origins_matrix = h.get_origins_matrix();
                new_origins_matrix = interp1(1:1:size(origins_matrix,1),origins_matrix,linspace(1,size(origins_matrix,1),h.N_azimuth_axis));
                for scanline_index = 1:h.N_azimuth_axis; uff_points(scanline_index) = uff.point('xyz',new_origins_matrix(scanline_index,:)); end
                h.origins = uff_points;
            end
            % Find matrix of origin positions
            origins_matrix = h.get_origins_matrix();

            origins_x = repelem(origins_matrix(:,1),h.N_depth_axis,1);
            origins_y = repelem(origins_matrix(:,2),h.N_depth_axis,1);
            origins_z = repelem(origins_matrix(:,3),h.N_depth_axis,1);

            h.theta=h.theta(:);
            h.rho=h.rho(:);

            origins_x = origins_x(:);
            origins_y = origins_y(:);
            origins_z = origins_z(:);
            
            % position of the pixels
            h.x=h.rho.*sin(h.theta)+origins_x;
            h.y=0.*(h.rho+origins_y);
            h.z=h.rho.*cos(h.theta)+origins_z;
        end

        function origins_matrix=get_origins_matrix(h)
            if h.N_origins == 1
                origins_matrix = zeros(h.N_azimuth_axis,3);
                for origin_index = 1:h.N_azimuth_axis; origins_matrix(origin_index,:) = h.origins.xyz; end     
            else
                origins_matrix = zeros(h.N_origins,3);
                for origin_index = 1:h.N_origins; origins_matrix(origin_index,:) = h.origins(origin_index).xyz; end     
            end
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
            assert(isa(in_origins,'uff.point'), 'The input is not a POINT class. Check HELP SOURCE');
            if ~isempty(h.azimuth_axis); 
                assert(isequal(size(in_origins,2),h.N_azimuth_axis)||in_origins.N_elements==1, ...
                    'The number of origins is different from the numbers of azimuth angles.'); 
            end
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
        function value=get.N_origins(h)
            value=numel(h.origins);
        end  
        function value=get.depth_step(h)
            value = mean(diff(h.depth_axis(1:end)));
        end
        function value=get.reference_distance(h)
            value = h.rho;
        end
    end
end


