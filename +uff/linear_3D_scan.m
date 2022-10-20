classdef linear_3D_scan < uff.scan
    %LINEAR_3D_SCAN   UFF class to define a linear scan 
    %   LINEAR_3D_SCAN contains the position of the x and z axis
    %
    %   Compulsory properties:
    %         radial_axis         % Vector containing the coordinates in the radial direction axis [m]
    %         axial_axis          % Vector containing the coordinates in the axial direction axis [m]
    %         roll                % Angle between the radial axis and the x-axis [rad]
    %
    %   Example:
    %         sca = uff.linear_3D_scan();
    %         sca.radial_axis=linspace(-20e-3,20e-3,256);
    %         sca.axial_axis=linspace(0e-3,40e-3,256);
    %         sca.roll=0;
    %         sca.plot();
    %
    %   See also UFF.SCAN, UFF.SECTOR_SCAN
    
    %   authors: Alfonso Rodriguez-Molares (alfonso.r.molares@ntnu.no)
    %   $Date: 2017/06/18$

    properties  (Access = public)
        radial_axis         % Vector containing the coordinates in the radial direction axis [m]
        axial_axis          % Vector containing the coordinates in the axial direction axis [m]
        roll                % Angle between the radial axis and the x-axis [rad]
    end
    
    properties  (Dependent)
        N_radial_axis             % number of pixels in the x_axis
        N_axial_axis              % number of pixels in the z_axis
    end
    
    %% constructor -> uff constructor
    methods (Access = public)
        function h=linear_3D_scan(varargin)
            h = h@uff.scan(varargin{:});
            h.update_pixel_position();
            
            if isempty(h.roll)
                h.roll = 0
            end
        end
    end
    
    %% update pixel position
    methods 
        function h=update_pixel_position(h)
            % defining the pixel mesh 
            [R A]=meshgrid(h.radial_axis,h.axial_axis);
            
            % position of the pixels
            if ~isempty(R)&&~isempty(h.roll)
                h.x=R(:)*cos(h.roll);
                h.y=R(:)*sin(h.roll);
                h.z=A(:);
            end
        end
    end
    
    %% Set methods
    methods
        function h=set.radial_axis(h,in_radial_axis)
            assert(size(in_radial_axis,2)==1, 'The input must be a column vector.')
            h.radial_axis=in_radial_axis;
            h=h.update_pixel_position();
        end
        function h=set.axial_axis(h,in_axial_axis)
            assert(size(in_axial_axis,2)==1, 'The input vector must be a column vector.')
            h.axial_axis=in_axial_axis;
            h=h.update_pixel_position();
        end
        function h=set.roll(h,in_roll)
            assert(numel(in_roll)==1, 'The input vector must be a scalar.')
            h.roll=in_roll;
            h=h.update_pixel_position();
        end
    end
    
    %% Get methods
    methods
        function value=get.N_radial_axis(h)
            value=numel(h.radial_axis);
        end
        function value=get.N_axial_axis(h)
            value=numel(h.axial_axis);
        end        
    end
    
end

