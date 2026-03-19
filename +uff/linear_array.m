classdef linear_array < uff.probe 
    %LINEAR_ARRAY   UFF data class for a linear (1-D) transducer array
    %
    %   LINEAR_ARRAY defines an array of elements equally spaced along a
    %   straight line (the x-axis). The geometry is computed automatically
    %   when N and pitch are set.
    %
    %   Properties:
    %       N               number of elements
    %       pitch           inter-element spacing [m]
    %       element_width   element width [m] (default: pitch)
    %       element_height  element height [m] (default: 10 * element_width)
    %
    %   Example:
    %       prb = uff.linear_array();
    %       prb.N = 128;
    %       prb.pitch = 300e-6;
    %
    %   See also UFF.PROBE, UFF.CURVILINEAR_ARRAY, UFF.MATRIX_ARRAY

    %   authors: Alfonso Rodriguez-Molares (alfonsom@ntnu.no)
    %   $Last updated: 2017/06/09$

    %% compulsory properties
    properties  (Access = public)
        N              % number of elements 
        pitch          % distance between the elements in the azimuth direction [m]
    end

    %% optional properties
    properties  (Access = public)
        element_width  % width of the elements in the azimuth direction [m]
        element_height % height of the elements in the elevation direction [m]
    end
    
    %% constructor
    methods (Access = public)
        function h=linear_array(varargin)
            h = h@uff.probe(varargin{:});
        end
    end

    %% update method
    methods 
        function h=update(h)
            if ~isempty(h.pitch)&~isempty(h.N) 
                
                if isempty(h.element_width)
                    h.element_width=h.pitch;
                end
                
                if isempty(h.element_height)
                    h.element_height=10*h.element_width;
                end
                
                % compute element abcissa
                x0=(1:h.N)*h.pitch;
                x0=x0-mean(x0);

                % assign geometry
                h.geometry=[x0(:) zeros(h.N,4) h.element_width*ones(h.N,1) h.element_height*ones(h.N,1)]; % probe geometry
            end
        end
    end
    
    %% set methods
    methods  
        function h=set.pitch(h,in_pitch)
            assert(numel(in_pitch)==1, 'The input should be a scalar in [m]');
            h.pitch=in_pitch;
            h=h.update();
        end
        function h=set.N(h,in_N_elements)
            assert(numel(in_N_elements)==1, 'The input should be a scalar');
            h.N=in_N_elements;
            h=h.update();
        end
        function h=set.element_width(h,in_width)
            assert(numel(in_width)==1, 'The input should be a scalar in [m]');
            h.element_width=in_width;
            h=h.update();
        end
        function h=set.element_height(h,in_height)
            assert(numel(in_height)==1, 'The input should be a scalar in [m]');
            h.element_height=in_height;
            h=h.update();
        end
    end    
end