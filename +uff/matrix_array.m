classdef matrix_array < uff.probe 
    %MATRIX_ARRAY   UFF data class for a 2-D matrix transducer array
    %
    %   MATRIX_ARRAY defines a rectangular grid of elements equally spaced
    %   in the azimuth (x) and elevation (y) directions.
    %
    %   Properties:
    %       N_x             number of elements in azimuth
    %       N_y             number of elements in elevation
    %       pitch_x         inter-element spacing in azimuth [m]
    %       pitch_y         inter-element spacing in elevation [m]
    %       element_width   element width [m] (default: pitch_x)
    %       element_height  element height [m] (default: pitch_y)
    %
    %   Example:
    %       prb = uff.matrix_array();
    %       prb.N_x = 32; prb.N_y = 32;
    %       prb.pitch_x = 300e-6; prb.pitch_y = 300e-6;
    %
    %   See also UFF.PROBE, UFF.CURVILINEAR_MATRIX_ARRAY

    %   authors: Alfonso Rodriguez-Molares (alfonsom@ntnu.no)
    %   $Last updated: 2017/06/11$

    %% compulsory properties
    properties  (Access = public)
        pitch_x        % distance between the elements in the azimuth direction [m]
        pitch_y        % distance between the elements in the elevation direction [m]
        N_x            % number of elements in the azimuth direction
        N_y            % number of elements in the elevation direction
    end

    %% optional properties
    properties  (Access = public)
        element_width  % width of the elements in the azimuth direction [m]
        element_height % height of the elements in the elevation direction [m]
    end

    %% constructor
    methods (Access = public)
        function h=matrix_array(varargin)
            h = h@uff.probe(varargin{:});
        end
    end


    %% update method
    methods 
        function update(h)
            if ~isempty(h.pitch_x)&&~isempty(h.pitch_y)&&~isempty(h.N_x)&&~isempty(h.N_y) 
                
                if isempty(h.element_width)
                    h.element_width=h.pitch_x;
                end
                
                if isempty(h.element_height)
                    h.element_height=h.pitch_y;
                end
                
                % compute element center location
                x0=(1:h.N_x)*h.pitch_x;
                y0=(1:h.N_y)*h.pitch_y;
                x0=x0-mean(x0);
                y0=y0-mean(y0);
                
                % ndgrid
                [X, Y]=ndgrid(x0,y0);

                % assign geometry
                h.geometry=[X(:) Y(:) zeros(h.N_x*h.N_y,3) h.element_width*ones(h.N_x*h.N_y,1) h.element_height*ones(h.N_x*h.N_y,1)]; % probe geometry
            end
        end
    end
    
    %% set methods
    methods  
        function set.pitch_x(h,in_pitch)
            assert(numel(in_pitch)==1, 'The input should be a scalar in [m]');
            h.pitch_x=in_pitch;
            h.update()
        end
        function set.pitch_y(h,in_pitch)
            assert(numel(in_pitch)==1, 'The input should be a scalar in [m]');
            h.pitch_y=in_pitch;
            h.update()
        end
        function set.N_x(h,in_N_elements)
            assert(numel(in_N_elements)==1, 'The input should be a scalar');
            h.N_x=in_N_elements;
            h.update()
        end
        function set.N_y(h,in_N_elements)
            assert(numel(in_N_elements)==1, 'The input should be a scalar');
            h.N_y=in_N_elements;
            h.update()
        end
        function set.element_width(h,in_width)
            assert(numel(in_width)==1, 'The input should be a scalar in [m]');
            h.element_width=in_width;
            h.update()
        end
        function set.element_height(h,in_height)
            assert(numel(in_height)==1, 'The input should be a scalar in [m]');
            h.element_height=in_height;
            h.update()
        end
    end
    
end