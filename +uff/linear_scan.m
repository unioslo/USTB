classdef linear_scan < uff.scan
    %LINEAR_SCAN   UFF class to define a linear scan 
    %   LINEAR_SCAN contains the position of the x and z axis
    %
    %   Compulsory properties:
    %         x_axis           % Vector containing the x coordinates [m]
    %         y_axis           % Vector containing the y coordinates [m]
    %         z_axis           % Vector containing the z coordinates [m]
    %
    %   Example:
    %         sca = uff.linear_scan();
    %         sca.x_axis=linspace(-20e-3,20e-3,256);
    %         sca.z_axis=linspace(0e-3,40e-3,256);
    %         scan.plot()
    %
    %   See also UFF.SCAN, UFF.SECTOR_SCAN

    %   authors: Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>
    %            Stefano Fiorentini <stefano.fiorentini@ntnu.no>
    %   Date: 2023/10/27

    properties  (Access = public)
        x_axis           % Vector containing the x coordinates of the x - axis [m]
        y_axis           % Vector containing the x coordinates of the x - axis [m]
        z_axis           % Vector containing the z coordinates of the z - axis [m]
        transform        % Vector of uff.transform objects
    end
    
    properties  (Dependent)
        N_x_axis              % number of pixels in the x_axis
        N_y_axis              % number of pixels in the yaxis
        N_z_axis              % number of pixels in the z_axis
        x_step                % the step size in m of the x samples
        y_step                % the step size in m of the x samples
        z_step                % the step size in m of the z samples
        reference_distance    % distance used for the calculation of the phase term
    end
    
    %% constructor -> uff constructor
    methods (Access = public)
        function h=linear_scan(varargin)
            h = h@uff.scan(varargin{:});

            if isempty(h.transform)
                h.transform = uff.transform();
            end

            h.update_pixel_position();
        end
    end
    
    %% update pixel position
    methods 
        function update_pixel_position(h)

            if isempty(h.x_axis) || isempty(h.y_axis) || isempty(h.z)
                return
            end
            
             % defining the pixel mesh
            [Z, X, Y] = ndgrid(h.z_axis, h.x_axis, h.y_axis);

            xyz = [X(:), Y(:), Z(:)];

            for i = 1:length(h.transform)
                xyz = h.transform(i).apply_transform(xyz);
            end


            h.x = xyz(:,1);
            h.y = xyz(:,2);
            h.z = xyz(:,3);
        end
    end
    
    %% Set methods
    methods
        function set.x_axis(h,in_x_axis)
            validateattributes(in_x_axis, {'single', 'double'}, {'real', 'vector'})
            h.x_axis=in_x_axis(:);
            h.update_pixel_position();
        end
        function set.y_axis(h,in_y_axis)
            validateattributes(in_y_axis, {'single', 'double'}, {'real', 'vector'})
            h.y_axis=in_y_axis(:);
            h.update_pixel_position();
        end
        function set.z_axis(h,in_z_axis)
            validateattributes(in_z_axis, {'single', 'double'}, {'real', 'vector'})
            h.z_axis=in_z_axis(:);
            h.update_pixel_position();
        end
        function set.transform(h,in_transform)
            validateattributes(in_transform {'uff.transform'}, {'vector'})
            h.transform=in_transform(:);
            h.update_pixel_position();
        end
    end
    %% Get methods
    methods
        function value=get.N_x_axis(h)
            value=numel(h.x_axis);
        end
        function value=get.N_y_axis(h)
            value=numel(h.y_axis);
        end
        function value=get.N_z_axis(h)
            value=numel(h.z_axis);
        end
        function value=get.x_step(h)
            value = mean(diff(h.x_axis));
        end
        function value=get.y_step(h)
            value = mean(diff(h.y_axis));
        end
        function value=get.z_step(h)
            value = mean(diff(h.z_axis));
        end
        function value=get.reference_distance(h)
            value = h.z;
        end
    end
    
end

