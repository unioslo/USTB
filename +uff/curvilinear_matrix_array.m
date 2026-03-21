classdef curvilinear_matrix_array < uff.matrix_array 
    %CURVILINEAR_MATRIX_ARRAY   UFF data class for a curvilinear 2-D matrix array
    %
    %   CURVILINEAR_MATRIX_ARRAY defines a 2-D grid of elements arranged on
    %   a cylindrical surface: curved in the azimuth direction and linear
    %   in the elevation direction. Inherits N_x, N_y, pitch_x, pitch_y
    %   from MATRIX_ARRAY.
    %
    %   Properties:
    %       radius_x        radius of curvature in azimuth [m]
    %
    %   Dependent properties:
    %       maximum_angle   angle of the outermost elements [rad]
    %
    %   Example:
    %       prb = uff.curvilinear_matrix_array('N_x', 32, 'N_y', 32, ...
    %           'pitch_x', 300e-6, 'pitch_y', 300e-6, 'radius_x', 60e-3);
    %
    %   See also UFF.MATRIX_ARRAY, UFF.PROBE

    %   authors: Anders E. Vrålstad (anders.e.vralstad@ntnu.no)
    %   $Last updated: 2022/11/22$

    %% compulsory properties
    properties  (Access = public)
        radius_x         % radius of the curvilinear array in azimuth direction [m]
    end
    
    %% optional properties  
     properties  (Dependent)
        maximum_angle  % angle of the outermost elements in the array
     end 

    %% constructor
    methods (Access = public)
        function h=curvilinear_matrix_array(varargin)
            h = h@uff.matrix_array(varargin{:});
        end
    end
     
    %% update method
    methods 
        function h=update(h)
            if ~isempty(h.pitch_x)&&~isempty(h.pitch_y)&&~isempty(h.N_x)&&~isempty(h.N_y)&&~isempty(h.radius_x)
                
                if isempty(h.element_width)
                    h.element_width=h.pitch_x;
                end
                
                if isempty(h.element_height)
                    h.element_height=h.pitch_y;
                end

                % compute element coordinates
                dtheta=2*asin(h.pitch_x/2/h.radius_x); 
                theta=(0:h.N_x-1)*dtheta; theta=theta-mean(theta);
                
                % Cylindical coordinates
                x0=h.radius_x*sin(theta);
                y0 = (0:h.N_y-1)*h.pitch_y; y0 = y0 - mean(y0);

                [X,Y]=meshgrid(x0,y0);    
                Z=h.radius_x*ones(h.N_y,1)*cos(theta)-h.radius_x;
                    
                THETA = atan2(X,Z)-pi/2;
                % assign geometry
                h.geometry=[X(:) Y(:) Z(:) THETA(:) zeros(h.N_x*h.N_y,1) h.element_width*ones(h.N_x*h.N_y,1) h.element_height*ones(h.N_x*h.N_y,1)]; % probe geometry
            end
        end
    end
    
    %% set methods
    methods  
        function h=set.radius_x(h,in_radius)
            assert(numel(in_radius)==1, 'The input should be a scalar in [m]');
            h.radius_x=in_radius;
            h=h.update();
        end
    end
     %% Get methods
    methods
        function value=get.maximum_angle(h)
            value=max(abs(h.geometry(:,4)));
        end
    end
end