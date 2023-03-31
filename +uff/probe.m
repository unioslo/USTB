classdef probe < uff
    %PROBE   UFF class to define arbitrary probe geometries
    %   PROBE contains the position and attitude of all elements of a
    %   probe.  Optionally PROBE can hold each element width and height,
    %   assuming the elements were rectangular. Information is stored in a 
    %   single matrix form called geometry, one row per element containing:
    %
    %   [x y z azimuth elevation width height]
    %
    %   Compulsory properties:
    %         geometry  = 0   % distance from the point location to the origin of coordinates [m]
    %
    %   Example:
    %         prb = uff.probe();
    %         pnt.distance = 20e-3;
    %         pnt.azimuth = 0.3*pi;
    %         pnt.elevation = 0;
    %
    %   See also UFF.WAVE

    %   authors: Alfonso Rodriguez-Molares (alfonsom@ntnu.no)
    %   $Date: 2017/06/09 $

    %% public properties
    properties  (Access = public)
        origin            % uff.point class location of the probe respect to origin of coordinates
        geometry         % matrix with attitude of rectangular elements [x y z theta phi width height] - [m m m rad rad m m]
    end
    
    %% dependent properties
    properties  (Dependent)   
        N_elements         % number of elements 
        x                  % center of the element in the x axis[m]
        y                  % center of the element in the y axis[m]
        z                  % center of the element in the z axis[m]
        theta              % orientation of the element in the azimuth direction [rad]
        phi                % orientation of the element in the elevation direction [rad]
        width              % element width [m]
        height             % element height [m]
        r                  % distance from the element center to the origin of coordinates [m]
    end
    
    %% constructor
    methods (Access = public)
        function h=probe(varargin)
            h = h@uff(varargin{:});
        end
    end
    
    %% plot methods
    methods
        function figure_handle=plot(h,figure_handle_in,title_in)
            x = [(h.x-h.width/2.*cos(h.theta)).'; (h.x+h.width/2.*cos(h.theta)).'; (h.x+h.width/2.*cos(h.theta)).'; (h.x-h.width/2.*cos(h.theta)).'];
            y = [(h.y-h.height/2.*cos(h.phi)).'; (h.y-h.height/2.*cos(h.phi)).'; (h.y+h.height/2.*cos(h.phi)).'; (h.y+h.height/2.*cos(h.phi)).'; ];
            z = [(h.z+h.width/2.*sin(h.theta)+h.height/2.*sin(h.phi)).'; (h.z-h.width/2.*sin(h.theta)+h.height/2.*sin(h.phi)).'; (h.z-h.width/2.*sin(h.theta)-h.height/2.*sin(h.phi)).'; (h.z+h.width/2.*sin(h.theta)-h.height/2.*sin(h.phi)).'];
            c = linspace(0,1,h.N_elements);
            
            % plotting probe
            if (nargin>1) && ~isempty(figure_handle_in)
                figure_handle=figure(figure_handle_in); hold on;
            else
                figure_handle=figure();
                title('Probe');
            end

            fill3(x*1e3,y*1e3,z*1e3,c); grid on; axis equal tight; hold on;
            plot3(h.x*1e3,h.y*1e3,h.z*1e3,'k+');
            xlabel('x[mm]'); ylabel('y[mm]'); zlabel('z[mm]');
            set(gca,'ZDir','Reverse');
            set(gca,'fontsize',14);
            
            if nargin>2
                title(title_in);
            end
        end
    end
    
    %% set methods
    methods  
        function h=set.geometry(h,in_geometry)
            
            % if element tilt & dimensions aren't provided we set them to 0
            N_columns=size(in_geometry,2);
            if(N_columns<7)
                in_geometry=[in_geometry zeros(size(in_geometry,1),7-size(in_geometry,2))];
            end
            
            assert(size(in_geometry,2)==7, 'The elements matrix should be [x y z theta phi width height] - [m m m rad rad m m]');
            h.geometry=in_geometry;
        end
    end
    
    %% get methods
    methods  
        function value=get.N_elements(h)
            value=size(h.geometry,1);
        end
        function value=get.x(h)
            %if h.N_elements==0 error('The PROBE class is empty'); end
            if h.N_elements==0 value=[]; 
            else
                value=h.geometry(:,1);
            end
        end
        function value=get.y(h)
            if h.N_elements==0 value=[]; 
            else
                value=h.geometry(:,2);
            end
        end
        function value=get.z(h)
            if h.N_elements==0 value=[]; 
            else
                value=h.geometry(:,3);
            end
        end
        function value=get.theta(h)
            if h.N_elements==0 value=[]; 
            else
                value=h.geometry(:,4);
            end
        end
        function value=get.phi(h)
            if h.N_elements==0 value=[]; 
            else
                value=h.geometry(:,5);
            end
        end
        function value=get.width(h)
            if h.N_elements==0 value=[]; 
            else
                value=h.geometry(:,6);
            end
        end
        function value=get.height(h)
            if h.N_elements==0 value=[]; 
            else
                value=h.geometry(:,7);
            end
        end
        function value=get.r(h)
            if h.N_elements==0 value=[]; 
            else
                value=sqrt(sum(h.geometry(:,1:3).^2,2));
            end
        end
    end
end