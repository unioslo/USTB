classdef transform < uff
    %TRANSFORM   UFF class to handle coordinate transforms in cartesian space
    %roll              Rotation around the x axis [rad]
    %pitch             Rotation around the y axis [rad]
    %yaw               Rotation around the z axis [rad]
    %rotation_order    Controls in which order the rotations are applied
    %origo             UFF.POINT object that translates the origin of the system    	

    properties  (Access = public)    
        roll           = 0           % Rotation around the x axis [rad]
        pitch          = 0           % Rotation around the y axis [rad]
        yaw            = 0           % Rotation around the z axis [rad]
        rotation_order = 'ypr'
        origo          = uff.point() % UFF.POINT object
    end
    
    properties (Dependent, Hidden)
        R_yaw
        R_pitch
        R_roll
    end
    
    properties (Dependent)
        R
        T
        t
    end
    %% constructor -> uff constructor
    methods (Access = public)
        function h=transform(varargin)
            h = h@uff(varargin{:});
        end
    end
    
    methods
        function output = apply_transform(h, input)
            validateattributes(input, {'numeric'}, {'real', 'ncols', 3})
            
            % Apply transform and remove 4th column
            output = [input, ones(size(input, 1), 1)]*h.T.'; 
            output(:, 4) = [];
        end
    end
 
    %% Set methods
    methods 
        function set.roll(h, in_roll)
            validateattributes(in_roll, {'numeric'}, {'real', 'scalar'})
            h.roll=in_roll;
        end
        function set.yaw(h, in_yaw)
            validateattributes(in_yaw, {'numeric'}, {'real', 'scalar'})
            h.yaw=in_yaw;
        end
        function set.pitch(h, in_pitch)
            validateattributes(in_pitch, {'numeric'}, {'real', 'scalar'})
            h.pitch=in_pitch;
        end
        function set.rotation_order(h, in_rotation_order)
            assert(any(validatestring(in_rotation_order, {'ypr', 'yrp', 'ryp', 'rpy', 'pry', 'pyr'})), 'Rotation order must be defined as a three character vector')
            h.rotation_order=in_rotation_order;
        end
        function set.origo(h,in_origo)
            assert(isa(in_origo,'uff.point'), 'The input is not a POINT class. Check HELP UFF.POINT');
            h.origo=in_origo;
        end
    end
    
    %% Get methods
    methods
        function val = get.R_roll(h)
            val  = [1, 0, 0; 0, cos(h.roll), -sin(h.roll); 0, sin(h.roll), cos(h.roll)];
        end
        
        function val = get.R_yaw(h)
            val  = [cos(h.yaw), -sin(h.yaw), 0; sin(h.yaw), cos(h.yaw), 0; 0, 0, 1];
        end
        
        function val = get.R_pitch(h)
            val  = [cos(h.pitch), 0, sin(h.pitch); 0, 1, 0; -sin(h.pitch), 0, cos(h.pitch)];
        end
        
        function val = get.t(h)
            % Translation vector
            val  = [h.origo.x; h.origo.y; h.origo.z];
        end
        
        function val = get.R(h)
            % Concatenation of ration matrices
            switch (h.rotation_order)
                case 'ypr'
                    val = h.R_yaw * h.R_pitch * h.R_roll;
                    
                case 'yrp'
                    val = h.R_yaw * h.R_pitch * h.R_roll;
                    
                case 'ryp'
                    val = h.R_roll * h.R_yaw * h.R_pitch;
                    
                case 'rpy'
                    val = h.R_roll * h.R_pitch * h.R_yaw;
                    
                case 'pry'
                    val = h.R_pitch * h.R_roll * h.R_yaw;
                    
                case 'pyr'
                    val = h.R_pitch * h.R_yaw * h.R_roll;
            end
        end
        
        function val = get.T(h)
            % Transform Matrix
            val = [h.R, h.t; [0, 0, 0, 1]];
        end
        
    end
    
end

