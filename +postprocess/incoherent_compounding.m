classdef incoherent_compounding < postprocess
%INCOHERENT_COMPOUNDING   Sum magnitude of beamformed data across dimensions.
%
%   Incoherent compounding sums the absolute value of beamformed data across
%   the specified dimension(s), reducing speckle at the cost of phase information.
%
%   Input:  uff.beamformed_data -> Output: uff.beamformed_data
%
%   Properties:
%       dimension   Which dimension(s) to sum over (transmit, receive, or both)
%
%   Example:
%       obj = postprocess.incoherent_compounding();
%
%   See also POSTPROCESS, COHERENT_COMPOUNDING, DIMENSION
%
%   authors: Alfonso Rodriguez-Molares (alfonso.r.molares@ntnu.no)
%            Ole Marius Hoel Rindal <olemarius@olemarius.net>
%
%   $Last updated: 2017/05/11$
    
    %% constructor
    methods (Access = public)
        function h=incoherent_compounding()
            h.name='Incoherent compounding MATLAB';
            h.reference='www.ntnu.no';
            h.implemented_by={'Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>','Ole Marius Hoel Rindal <olemarius@olemarius.net>'};
            h.version='v1.0.3';
        end
    end
    
    properties (Access = public)
        dimension = dimension.both;          %Which "dimension" to sum over
    end
    
    
    methods
        function output=go(h)
            % check if we can skip calculation
            if h.check_hash()
                output= h.output; 
                return;
            end
            
            [N_pixels Nrx Ntx N_frames]=size(h.input.data);
            
            % declare output structure
            h.output=uff.beamformed_data(h.input); % ToDo: instead we should copy everything but the data

            switch h.dimension
                case dimension.both
                    %out_data.data=zeros(N_pixels, 1, 1, N_frames);
                    h.output.data=sum(sum(abs(h.input.data),2),3);
                case dimension.transmit
                    %out_data.data=zeros(N_pixels, Nrx, 1, N_frames);
                    h.output.data=sum(abs(h.input.data),3);
                case dimension.receive
                    %out_data.data=zeros(N_pixels, 1, Ntx, N_frames);
                    h.output.data=sum(abs(h.input.data),2);
                otherwise
                    error('Unknown dimension mode; check HELP dimension');
            end
            
            % pass reference
            output = h.output;
            
            % update hash
            h.save_hash();
        end
    end
end
