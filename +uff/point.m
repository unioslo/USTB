classdef point < uff
    %POINT   UFF class to define a point location
    %   POINT contains the position of a point in a tridimensional space. It
    %   express that location in spherical coordinates which allows to place 
    %   points at infinity but in a given direction. 
    %
    %   Compulsory properties:
    %         distance  = 0   % distance from the point location to the origin of coordinates [m]
    %         azimuth   = 0   % angle from the point location to the plane YZ [rad]
    %         elevation = 0   % angle from the point location to the plane XZ [rad]
    %
    %   Example:
    %         pnt = uff.point();
    %         pnt.distance = 20e-3;
    %         pnt.azimuth = 0.3*pi;
    %         pnt.elevation = 0;
    %
    %   See also UFF.WAVE

    %   authors: Alfonso Rodriguez-Molares (alfonso.r.molares@ntnu.no)
    %   $Date: 2017/06/09 $

    %% public properties
    properties  (Access = public)
        distance  = 0   % distance from the point location to the origin of coordinates [m]
        azimuth   = 0   % angle from the point location to the plane YZ [rad]
        elevation = 0   % angle from the point location to the plane XZ [rad]
    end
    
    %% dependent properties
    properties  (Dependent)   
        xyz                   % location of the point [m m m] if the point is not at infinity        
        x
        y
        z
    end    
    
    %% constructor -> uff constructor
    methods (Access = public)
        function h=point(varargin)
            h = h@uff(varargin{:});
        end
    end
    
    %% set methods
    methods  
         function h=set.distance(h,in_distance)
             assert(numel(in_distance)==1, 'The distance should be a escalar in [m]');
             if in_distance >= 0
                h.distance=in_distance;
             else
                h.distance=-in_distance;
                h.xyz = -h.xyz;
             end    
         end
         function h=set.azimuth(h,in_azimuth)
             assert(numel(in_azimuth)==1, 'The azimuth should be a escalar in [rad]');
             h.azimuth=in_azimuth;
         end
         function h=set.elevation(h,in_elevation)
             assert(numel(in_elevation)==1, 'The elevation should be a escalar in [rad]');
             h.elevation=in_elevation;
         end
         function h=set.xyz(h,in_xyz)
             assert(size(in_xyz,2)==3, 'The xyz must be an array [x y z] - [m m m]');
             h.distance=norm(in_xyz,2);
             h.azimuth=atan2(in_xyz(1),in_xyz(3));
             if(h.distance>0)
                 if isinf(in_xyz(2))
                    h.elevation=pi/2*sign(in_xyz(2));
                 else
                    h.elevation=asin(in_xyz(2)/h.distance);
                 end
             else
                h.elevation=0;
             end
         end
         function h=set.x(h,in_x)
             assert(numel(in_x)==1, 'The x must be an scalar in [m]');
              % update spherical
              y=h.y;
              z=h.z;
              h.distance=norm([in_x y z],2);
              h.azimuth=atan2(in_x,z);
              if(h.distance>0)
                h.elevation=asin(y/h.distance);
              else
                h.elevation=0;
              end
         end
         function h=set.y(h,in_y)
             assert(numel(in_y)==1, 'The y must be an scalar in [m]');
              x=h.x;
              z=h.z;
              h.distance=norm([x in_y z],2);
              if(h.distance>0)
                h.elevation=asin(in_y/h.distance);
              else
                h.elevation=0;
              end
         end
         function h=set.z(h,in_z)
             assert(numel(in_z)==1, 'The z must be an scalar in [m]');
              x=h.x;
              y=h.y;
              h.distance=norm([x y in_z],2);
              h.azimuth=atan2(x,in_z);
              if(h.distance>0)
                h.elevation=asin(y/h.distance);
              else
                h.elevation=0;
              end
         end         
    end
    
    %% get methods
    methods  
         function value=get.xyz(h)
             value=[h.x h.y h.z];
         end
         function value=get.x(h)
               if (h.azimuth==pi)||(h.azimuth==0)
                   value=0;
               else
                   value=h.distance.*sin(h.azimuth).*cos(h.elevation);
               end
         end
         function value=get.y(h)
             if (h.elevation==0)
                value=0;
             else
                value=h.distance.*sin(h.elevation);
             end
         end
         function value=get.z(h)
             if abs(h.azimuth)==pi/2||abs(h.elevation)==pi/2
                 value=0;
             else
                value=h.distance.*cosd(h.azimuth*180/pi).*cosd(h.elevation*180/pi); 
             end
         end
    end
    
    %% plot methods
    methods
        function figure_handle=plot(h,figure_handle_in,in_title)
            % plotting point
            if (nargin>1) && ~isempty(figure_handle_in)
                figure_handle=figure(figure_handle_in);
            else
                figure_handle=figure();
                title('point');
            end            
            
            if nargin>2
                title(in_title);
            end
            
            if isinf(h.distance)
                x=sin(h.azimuth).*cos(h.elevation);
                y=sin(h.elevation);
                z=cos(h.azimuth).*cos(h.elevation);
                
                quiver3(0,0,0,x,y,z,10,'b'); grid on; axis equal;
                xlabel('x[mm]'); ylabel('y[mm]'); zlabel('z[mm]');
                set(gca,'ZDir','Reverse');
                set(gca,'fontsize',14);
            else
                plot3(h.x*1e3,h.y*1e3,h.z*1e3,'bo'); grid on; axis equal;
                xlabel('x[mm]'); ylabel('y[mm]'); zlabel('z[mm]');
                set(gca,'ZDir','Reverse');
                set(gca,'fontsize',14);
            end
        end
    end
end