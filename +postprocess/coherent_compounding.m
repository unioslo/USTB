classdef coherent_compounding < postprocess
%COHERENT_COMPOUNDING   Matlab implementation of Coherent compounding
% If the window_size property is specified, a sliding window compounding approach with window size
% window_size is performed. Sliding window compounding is only performed along the transmit
% dimension. The receive dimension is compounded as usual
%
%   authors: Alfonso Rodriguez-Molares (alfonso.r.molares@ntnu.no)
%            Ole Marius Hoel Rindal <olemarius@olemarius.net>
%            Fabrice Prieur
%            Stefano Fiorentini <stefano.fiorentini@ntnu.no>
%
%   $Last updated: 2023/09/01$

    %% constructor
    methods (Access = public)
        function h=coherent_compounding()
            h.name='Coherent compounding MATLAB';   
            h.reference='www.ntnu.no';                
            h.implemented_by={'Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>', ...
                'Ole Marius Hoel Rindal <olemarius@olemarius.net>', ...
                'Fabrice Prieur', ...
                'Stefano Fiorentini <stefano.fiorentini@ntnu.no>'};   
            h.version='v1.1.0';
        end
    end
    
    properties (Access = public)
       dimension = dimension.both;          % Which "dimension" to sum over
       window_size = []                     % If specified, do moving sum along transmit dimension
    end
    
    methods
        function output=go(h)
            % check if we can skip calculation
            if h.check_hash()
                output= h.output; 
                return;
            end
            
                        
            % Define output object
            h.output=uff.beamformed_data(h.input);
            
            if isempty(h.window_size)
                switch h.dimension
                    case dimension.both %#ok<*PROP>
                        h.output.data=sum(h.input.data,[2,3]);
                    case dimension.transmit
                        h.output.data=sum(h.input.data,3);
                    case dimension.receive
                        h.output.data=sum(h.input.data,2);
                    otherwise
                        error('Unknown dimension mode; check HELP dimension');
                end
            else
                assert(h.window_size <= h.input.N_waves, ...
                'Cannot have a window size greater that the available number of transmit events.')
            
                data = reshape(h.input.data, [h.input.N_pixels, h.input.N_channels, 1, h.input.N_waves*h.input.N_frames]);
                
                switch h.dimension
                    case dimension.both
                        h.output.data = movsum(sum(data, 2), h.window_size, 4, 'Endpoints', 'discard');
                    case dimension.transmit
                        h.output.data=movsum(data, h.window_size, 4, 'Endpoints', 'discard');
                    case dimension.receive
                        h.output.data=sum(h.input.data,2);
                    otherwise
                        error('Unknown dimension mode; check HELP dimension');
                end
            end            
            
            % pass reference
            output = h.output;
            
            % update hash
            h.save_hash();

        end
    end
    
    methods
        function set.dimension(h, val)
            validateattributes(val, {'dimension'}, {'scalar'})
            h.dimension = val;
        end
        function set.window_size(h, val)
            if ~isempty(val)
                validateattributes(val, {'single', 'double'}, {'integer', 'scalar'})
            end
            h.window_size = val;
        end
    end
end
