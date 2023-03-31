classdef linear_scan < uff.scan
    %LINEAR_SCAN   UFF class to define a linear scan 
    %   LINEAR_SCAN contains the position of the x and z axis
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
    %   See also UFF.SCAN, UFF.SECTOR_SCAN

    %   authors: Alfonso Rodriguez-Molares (alfonso.r.molares@ntnu.no)
    %   $Date: 2017/06/18 $

    properties  (Access = public)
        x_axis           % Vector containing the x coordinates of the x - axis [m]
        z_axis           % Vector containing the z coordinates of the z - axis [m]
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
        function h=linear_scan(varargin)
            h = h@uff.scan(varargin{:});
            h.update_pixel_position();
        end
    end
    
    %% update pixel position
    methods 
        function h=update_pixel_position(h)
            
            % defining the pixel mesh 
            [X Z]=meshgrid(h.x_axis,h.z_axis);
            
            % position of the pixels
            if ~isempty(X)
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
            value = h.z;
        end
    end
    
end

