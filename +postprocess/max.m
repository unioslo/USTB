classdef max < postprocess
%MAX   Matlab implementation of max of beamformed values
%
%   authors: Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>
%            Ole Marius Hoel Rindal <olemarius@olemarius.net>
%
%   $Last updated: 2017/09/10$

   
    %% constructor
    methods (Access = public)
        function h=max()
            h.name='Maximum value MATLAB';   
            h.reference= 'www.ustb.no';                
            h.implemented_by={'Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>','Ole Marius Hoel Rindal <olemarius@olemarius.net>'};    
            h.version='v1.0.4';
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
            
            switch h.dimension
                case dimension.both
                    h.output=uff.beamformed_data(h.input); % ToDo: instead we should copy everything but the data
                    h.output.data=zeros(N_pixels, 1, 1, N_frames);
                    h.output.data=max(max(abs(h.input.data),[],2),[],3);
                case dimension.transmit
                    h.output=uff.beamformed_data(h.input); % ToDo: instead we should copy everything but the data
                    h.output.data=zeros(N_pixels, Nrx, 1, N_frames);
                    h.output.data=max(abs(h.input.data),[],3);
                case dimension.receive
                    h.output=uff.beamformed_data(h.input); % ToDo: instead we should copy everything but the data
                    h.output.data=zeros(N_pixels, 1, Ntx, N_frames);
                    h.output.data=max(abs(h.input.data),[],2);
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
