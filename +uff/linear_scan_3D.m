classdef linear_scan_3D < uff.scan
    %LINEAR_SCAN_3D   UFF data class for a 3-D Cartesian volume scan
    %
    %   LINEAR_SCAN_3D defines a regular 3-D grid using x_axis, y_axis,
    %   and z_axis vectors.
    %
    %   Properties:
    %       x_axis      x-axis sample positions [m]
    %       y_axis      y-axis sample positions [m]
    %       z_axis      z-axis sample positions [m]
    %       transform   UFF.TRANSFORM applied to pixel positions
    %
    %   Example:
    %       sca = uff.linear_scan_3D();
    %       sca.x_axis = linspace(-20e-3, 20e-3, 64);
    %       sca.y_axis = linspace(-20e-3, 20e-3, 64);
    %       sca.z_axis = linspace(0, 40e-3, 128);
    %
    %   See also UFF.SCAN, UFF.LINEAR_SCAN

    %   authors: Alfonso Rodriguez-Molares (alfonso.r.molares@ntnu.no)
    %   $Date: 2017/06/18 $

    properties  (Access = public)
        x_axis           % Vector containing the x coordinates of the x - axis [m]
        y_axis           % Vector containing the y coordinates of the y - axis [m]
        z_axis           % Vector containing the z coordinates of the z - axis [m]
        transform = uff.transform();
    end
    
    properties  (Dependent)
        N_y_axis              % number of pixels in the x_axis
        N_x_axis              % number of pixels in the x_axis
        N_z_axis              % number of pixels in the z_axis
        z_step                % the step size in m of the z samples
        reference_distance        % distance used for the calculation of the phase term
    end
    
    %% constructor -> uff constructor
    methods (Access = public)
        function h=linear_scan_3D(varargin)
            h = h@uff.scan(varargin{:});
            h.update_pixel_position();
        end
    end
    
    %% update pixel position
    methods
        function update_pixel_position(h)
            
            % defining the pixel mesh
            [Z, X, Y] = ndgrid(h.z_axis, h.x_axis, h.y_axis);
            
            % position of the pixels
            if ~isempty(X)
                
                xyz = [X(:), Y(:), Z(:)];
                
                for i = 1:length(h.transform)
                    xyz = h.transform(i).apply_transform(xyz);
                end
                
                
                h.x = xyz(:,1);
                h.y = xyz(:,2);
                h.z = xyz(:,3);
            end
        end
    end
    
    %% Set methods
    methods
        function set.x_axis(h,in_x_axis)
            validateattributes(in_x_axis, {'numeric'}, {'real', 'vector'})
            h.x_axis=in_x_axis(:);
            h.update_pixel_position();
        end
        function set.z_axis(h,in_z_axis)
            validateattributes(in_z_axis, {'numeric'}, {'real', 'vector'})
            h.z_axis=in_z_axis(:);
            h.update_pixel_position();
        end
        function set.y_axis(h,in_y_axis)
            validateattributes(in_y_axis, {'numeric'}, {'real', 'vector'})
            h.y_axis=in_y_axis(:);
            h.update_pixel_position();
        end
        function set.transform(h,in_transform)
            assert(isa(in_transform,'uff.transform'), 'The input is not a TRANSFORM class. Check HELP UFF.TRANSFORM');
            h.transform=in_transform(:);
            h.update_pixel_position();
        end
    end
    
    %% Get methods
    methods
        function value=get.N_x_axis(h)
            value=numel(h.x_axis);
        end
        function value=get.N_z_axis(h)
            value=numel(h.z_axis);
        end
        function value=get.N_y_axis(h)
            value=numel(h.y_axis);
        end
        function value=get.z_step(h)
            value = mean(diff(h.z_axis(1:end)));
        end
        function value=get.reference_distance(h)
            value = 0;
        end
    end
    
end

