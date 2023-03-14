classdef scan < uff
    %SCAN   UFF class to define a scan 
    %   SCAN contains the position of a collection of pixels. It is a
    %   superclass for more easy-to-handle classes such as UFF.LINEAR_SCAN
    %   or UFF.SECTOR_SCAN
    %
    %   Compulsory properties:
    %         xyz                % Vector containing the [x, y, z] coordinates of each pixel in [m]
    %
    %   Read-only properties
    %         x                  % Vector containing the x coordinates of each pixel in [m]
    %         y                  % Vector containing the y coordinates of each pixel in [m]
    %         z                  % Vector containing the z coordinates of each pixel in [m]
    %
    %   Example:
    %         sca = uff.scan();
    %         x_axis=linspace(-20e-3,20e-3,256);
    %         z_axis=linspace(0e-3,40e-3,256);
    %         [X, Z]=meshgrid(x_axis,z_axis);
    %         sca.xyz = [X(:), zeros([numel(X), 1]), Z(:)];
    %
    %   See also UFF.LINEAR_SCAN, UFF.SECTOR_SCAN


    properties  (Access = public)
        x                  % Vector containing the x coordinate of each pixel in the matrix
        y                  % Vector containing the x coordinate of each pixel in the matrix
        z                  % Vector containing the z coordinate of each pixel in the matrix
    end
    
    properties  (Dependent)
        N_pixels           % total number of pixels in the matrix
        xyz                % location of the source [m m m] if the source is not at infinity    
    end
    
    %% constructor -> uff constructor
    methods (Access = public)
        function h=scan(varargin)
            h = h@uff(varargin{:});
        end
    end
    
    %% plot methods
    methods
        function figure_handle=plot(h,figure_handle_in,title_in)
            % plotting scan
            if (nargin>1) && ~isempty(figure_handle_in)
                figure_handle=figure(figure_handle_in); hold on;
            else
                figure_handle=figure();
                title('Probe');
            end
            
            plot3(h.x*1e3,h.y*1e3,h.z*1e3,'k.');
            xlabel('x[mm]'); ylabel('y[mm]'); zlabel('z[mm]');
            set(gca,'ZDir','Reverse', 'Layer', 'top');
            set(gca,'fontsize',14);
            
            axis equal tight
            grid on
            box on

            if nargin>2
                title(title_in);
            end
        end
    end
    
    %% Set methods
    methods
        function set.x(h,val)
            validateattributes(val, {'single', 'double'}, {'vector'})
            h.x=val(:);
        end
        function set.y(h,val)
            validateattributes(val, {'single', 'double'}, {'vector'})
            h.y=val(:);
        end
        function set.z(h,val)
            validateattributes(val, {'single', 'double'}, {'vector'})
            h.z=val(:);
        end
        function set.xyz(h,val)
            validateattributes(val, {'single', 'double'}, {'2d', 'ncols', 3})
            h.x=val(:,1);
            h.y=val(:,2);
            h.z=val(:,3);
        end
    end
    
    %% Get methods
    methods
        function val=get.N_pixels(h)
            val=numel(h.x);
        end
        function val=get.xyz(h)
             val=[h.x, h.y, h.z];
        end
    end
end

