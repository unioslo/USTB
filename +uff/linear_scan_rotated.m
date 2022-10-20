classdef linear_scan_rotated < uff.scan
    %LINEAR_SCAN_ROTATED   UFF class to define a rotated linear scan 
    %   LINEAR_SCAN_ROTATED contains the position of the x and z axis
    %
    %   Compulsory properties:
    %         x_axis                % Vector containing the x coordinates of the x - axis [m]
    %         z_axis                % Vector containing the z coordinates of the z - axis [m]
    %         rotation_angle        % Rotation angle [rad]
    %         center_of_rotation    % Vector containing the (x,y,z) coordinates [m] of the rotation point
    %
    %   Example:
    %         sca = uff.linear_scan_rotated();
    %         sca.x_axis=linspace(-20e-3,20e-3,256);
    %         sca.z_axis=linspace(0e-3,40e-3,256);
    %         sca.rotation_angle = 20*pi/180;
    %         sca.center_of_rotation = [0 0 0];
    %         scan.plot()
    %
    %   See also UFF.SCAN, UFF.SECTOR_SCAN

    %   authors: ...
    %   $Date: 2017/06/18 $

    properties  (Access = public)
        x_axis              % Vector containing the x coordinates of the x - axis [m]
        z_axis              % Vector containing the z coordinates of the z - axis [m]
        rotation_angle      % Rotated angle [rad]
        center_of_rotation  % Vector containing the (x,y,z) coordinates [m] of the rotation point
    end
    
    properties  (Dependent)
        N_x_axis              % number of pixels in the x_axis
        N_z_axis              % number of pixels in the z_axis
        x_step                % the step size in m of the x samples
        z_step                % the step size in m of the z samples
        reference_distance    % distance used for the calculation of the phase term
    end
    
    %% constructor -> uff constructor
    methods (Access = public)
        function h=linear_scan_rotated(varargin)
            h = h@uff.scan(varargin{:});
            h.update_pixel_position();
        end
    end
    
    %% update pixel position
    methods 
        function h=update_pixel_position(h)
            
            % defining the pixel mesh 
            [X, Z]=meshgrid(h.x_axis,h.z_axis);
            
            % defining rotation parameters
            angle=h.rotation_angle;
            centerRot=h.center_of_rotation;
            
            % rotating the pixel mesh around center_of_rotation with
            % rotation_angle
            if ~isempty(X) && ~isempty(angle) && ~isempty(centerRot)
                Xc = X - centerRot(1);
                Zc = Z - centerRot(3);
%                 rotMatrix = vrrotvec2mat([0,0,1,angle]);
%                 RotGrid = [Xc(:), Zc(:), zeros(size(Xc(:)))]*rotMatrix;
                rotMatrix = [cos( angle) -sin(angle); sin(angle) cos(angle)];
                RotGrid = [Xc(:) Zc(:)]*rotMatrix;
                X = reshape(RotGrid(:,1),size(Xc));
                Z = reshape(RotGrid(:,2),size(Zc));
                X = X + centerRot(1);
                Z = Z + centerRot(3);
            end
                 
            % position of the pixels
            if ~isempty(X)&& ~isempty(angle) && ~isempty(centerRot)
                h.x=X(:);
                h.y=0.*X(:);
                h.z=Z(:);
            end
        end
    end
    
    %% Set methods
    methods
        function h=set.x_axis(h,in_x_axis)
            assert(size(in_x_axis,2)==1, 'The input must be a column vector.')
            h.x_axis=in_x_axis;
            h=h.update_pixel_position();
        end
        function h=set.z_axis(h,in_z_axis)
            assert(size(in_z_axis,2)==1, 'The input vector must be a column vector.')
            h.z_axis=in_z_axis;
            h=h.update_pixel_position();
        end
        function h=set.rotation_angle(h,in_rotation_angle)
            assert(size(in_rotation_angle,2)==1, 'The input vector must be a column vector.')
            h.rotation_angle=in_rotation_angle;
            h=h.update_pixel_position();
        end
        function h=set.center_of_rotation(h,in_center_of_rotation)
            assert(size(in_center_of_rotation,2)==1, 'The input vector must be a column vector.')
            h.center_of_rotation=in_center_of_rotation;
            h=h.update_pixel_position();
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
        function value=get.x_step(h)
            value = mean(diff(h.x_axis(1:end)));
        end
        function value=get.z_step(h)
            value = mean(diff(h.z_axis(1:end)));
        end
        function value=get.reference_distance(h)
            value = sin(h.rotation_angle)*h.x + cos(h.rotation_angle)*h.z;
        end
    end
    
end

