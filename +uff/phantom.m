classdef phantom 
    %PHANTOM   UFF data class describing a scattering phantom
    %
    %   PHANTOM defines point scatterers and medium properties used by
    %   simulators such as FRESNEL.
    %
    %   Properties:
    %       points          Nx4 matrix of scatterers [x y z Gamma] [m m m unitless]
    %       time            time instant [s]
    %       sound_speed     medium speed of sound [m/s]
    %       density         medium density [kg/m3]
    %       alpha           attenuation coefficient [dB/cm/MHz]
    %
    %   Dependent properties:
    %       N_points        number of point scatterers
    %       x, y, z         scatterer coordinates [m]
    %       Gamma           reflection coefficients
    %
    %   Example:
    %       pha = uff.phantom();
    %       pha.sound_speed = 1540;
    %       pha.points = [0, 0, 20e-3, 1];
    %
    %   See also UFF.CHANNEL_DATA, FRESNEL
    
    %   authors: Alfonso Rodriguez-Molares (alfonso.r.molares@ntnu.no)
    %   $Date: 2017/02/22 $

    %% public properties
    properties  (Access = public)
        points           % matrix of point scaterers [x y z Gamma] - [m m m unitless]
        time             % time [s]
        sound_speed      % medium sound speed [m/s]
        density          % medium density [kg/m3]
        alpha            % medium attenuation [dB/cm/MHz]
    end
    
    %% protected properties
    properties  (Dependent)   
        N_points           % number of points 
        x                  % points position in the x axis [m]
        y                  % points position in the y axis [m]
        z                  % points position in the z axis [m]
        Gamma              % reflection coefficient [unitless]
        r                  % distance from the points to the origin [m]
        theta              % angle in the azimuth direction respect to origin [rad]
        phi                % angle in the elevation direction respect to origin [rad]
    end
    
    %% constructor
    methods (Access = public)
        function h=phantom(points_in,time_in,sound_speed_in,density_in,alpha_in)
            %PHANTOM   Constructor of PHANTOM class
            %
            %   h = phantom(points, time, sound_speed, density, alpha)
            %
            %   See also UFF.CHANNEL_DATA
            
            h.time=0;               % time [s]
            h.sound_speed=1540;     % sound speed [m/s]
            h.density=1020;         % density [kg/m3]
            h.alpha=0.0;            % attenuation [dB/cm/MHz]
            
            if nargin>0
               h.points=points_in;
            end
            if nargin>1
                h.time=time_in;
            end
            if nargin>2
                h.sound_speed=sound_speed_in;
            end
            if nargin>3
                h.density=density_in;
            end
            if nargin>4
                h.alpha=alpha_in;
            end
        end
    end
    
    %% plot methods
    methods
        function figure_handle=plot(h,figure_handle_in,title_in)
            % plotting phantom
            if (nargin>1) && ~isempty(figure_handle_in)
                figure_handle=figure(figure_handle_in);
            else
                figure_handle=figure();
                view(-30,30);
            end
            %[az,el] = view();
            %if (el==90) 
                %plot(h.points(:,1)*1e3,h.points(:,3)*1e3,'ro'); grid on; axis equal; hold on;
            %else
                plot3(h.points(:,1)*1e3,h.points(:,2)*1e3,h.points(:,3)*1e3,'ro'); grid on; axis equal; hold on;
                xlabel('x[mm]'); ylabel('y[mm]'); zlabel('z[mm]');
                set(gca,'ZDir','Reverse');
                set(gca,'fontsize',14);
            %end
            
            if nargin>2
                title(title_in);
            end
        end
    end
    
    %% set methods
    methods  
        function h=set.points(h,in_points)
            assert(size(in_points,2)==4, 'The points matrix should be [x y z Gamma] - [m m m unitless]');
            h.points=in_points;
        end
    end
    
    %% get methods
    methods  
        function value=get.N_points(h)
            value=size(h.points,1);
        end
         function value=get.x(h)
            value=h.points(:,1);
        end
        function value=get.y(h)
            value=h.points(:,2);
        end
        function value=get.z(h)
            value=h.points(:,3);
        end
        function value=get.Gamma(h)
            value=h.points(:,4);
        end
        function value=get.r(h)
            value=sqrt(sum(h.points(:,1:3).^2,2));
        end
        function value=get.theta(h)
            value=atan2(h.points(:,1),h.points(:,3));
        end
        function value=get.phi(h)
            value=atan2(h.points(:,2),h.points(:,3));
        end
    end
end