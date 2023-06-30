classdef matrix_array < uff.probe 
    %MATRIX_ARRAY   UFF class to define a matrix array probe geometry
    %   MATRIX_ARRAY contains defines an 2D array of elements with regularly 
    %   spaced in both dimmensions. 
    %
    %   Compulsory properties
    %     properties  (SetAccess = public)
    %         pitch_x        % distance between the elements in the azimuth direction [m]
    %         pitch_y        % distance between the elements in the elevation direction [m]
    %         N_x            % number of elements in the azimuth direction
    %         N_y            % number of elements in the elevation direction
    %     end
    % 
    %  Optional properties
    %     properties  (SetAccess = public)
    %         element_width  % width of the elements in the azimuth direction [m]
    %         element_height % height of the elements in the elevation direction [m]
    %     end
    % 
    %   Example:
    %         prb = uff.matrix_array('N_x',32,'N_y',32,'pitch_x',300e-6,'pitch_y',300e-6);
    %         prb.plot();
    %
    %   See also UFF.PROBE

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
        function h=update(h)
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
        function h=set.pitch_x(h,in_pitch)
            assert(numel(in_pitch)==1, 'The input should be a scalar in [m]');
            h.pitch_x=in_pitch;
            h=h.update();
        end
        function h=set.pitch_y(h,in_pitch)
            assert(numel(in_pitch)==1, 'The input should be a scalar in [m]');
            h.pitch_y=in_pitch;
            h=h.update();
        end
        function h=set.N_x(h,in_N_elements)
            assert(numel(in_N_elements)==1, 'The input should be a scalar');
            h.N_x=in_N_elements;
            h=h.update();
        end
        function h=set.N_y(h,in_N_elements)
            assert(numel(in_N_elements)==1, 'The input should be a scalar');
            h.N_y=in_N_elements;
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