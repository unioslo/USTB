classdef phase_coherence_factor < postprocess
%PHASE_COHERENCE_FACTOR   Matlab implementation of Camacho-Fritsch Phase Coherence Factor
%
%   MATLAB implementation of Camacho-Fritsch Phase Coherence Factor beamforming
%   method as described in the paper:
%
%   J. Camacho and C. Fritsch, "Phase coherence imaging of grained materials," 
%   in IEEE Transactions on Ultrasonics, Ferroelectrics, and Frequency Control, 
%   vol. 58, no. 5, pp. 1006-1015, May 2011.
%
%   The implementation computes coherence either on transmit, receive, or
%   both.
%
%   implementers: Ole Marius Hoel Rindal <olemarius@olemarius.net>
%                 Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>
%
%   $Last updated: 2017/09/12$

        %% constructor
    methods (Access = public)
        function h=phase_coherence_factor()
            h.name='Phase Coherence Factor MATLAB';   
            h.reference='J. Camacho and C. Fritsch, Phase coherence imaging of grained materials, in IEEE Transactions on Ultrasonics, Ferroelectrics, and Frequency Control, vol. 58, no. 5, pp. 1006-1015, May 2011.';                
            h.implemented_by={'Ole Marius Hoel Rindal <olemarius@olemarius.net>','Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>'};    
            h.version='v1.0.3';
        end
    end

    %% Additional properties
    properties
        center_frequency                              % center frequency of RF signals [Hz]
        sound_speed=1540;                             % reference sound speed [m/s]
        gamma=1;                                      % mixing ratio
        sigma_0=pi/sqrt(3);                           % reference phase value
        FCA                                           % BEAMFORMED_DATA class with the computed absolute phase coherence factor
        FCC                                           % BEAMFORMED_DATA class with the computed complex phase coherence factor
    end
    
    properties (Access = public)
       dimension = dimension.both;          %Which "dimension" to sum over
    end
    
    methods
        function output=go(h)
            % check if we can skip calculation
            if h.check_hash()
                output = h.output; 
                return;
            end            
           
            % check dimensions
            if (h.dimension==dimension.receive) && (h.input.N_channels<2)
                error('Not enough channels to compute factor');
            end
            if (h.dimension==dimension.transmit) && (h.input.N_waves<2)
                error('Not enough waves to compute factor');
            end
            if (h.dimension==dimension.both) 
                if (h.input.N_channels<2)&&(h.input.N_waves>1)
                    warning('Not enough channels to compute factor. Changing dimension to dimension.transmit');
                    h.dimension = dimension.transmit;
                elseif (h.input.N_waves<2)&&(h.input.N_channels>1)
                    warning('Not enough waves to compute factor. Changing dimension to dimension.receive');
                    h.dimension = dimension.receive;
                elseif (h.input.N_waves<2)&&(h.input.N_channels<2)
                    error('Not enough waves and channels to compute factor');
                end
            end
            
             % check if we have information about the receive apodization
            if (h.dimension~=dimension.transmit)
                if isempty(h.receive_apodization)||(h.receive_apodization.window==uff.window.none)
                    rx_apodization=ones(h.input.N_pixels,h.input.N_channels);
                else
                    h.receive_apodization.focus = h.input.scan;
                    rx_apodization=h.receive_apodization.data;
                end
            end
            
            % check if we have information about the transmit apodization
            if (h.dimension~=dimension.receive)
                if isempty(h.transmit_apodization)||(h.transmit_apodization.window==uff.window.none)||(isempty(h.transmit_apodization.sequence)&&isempty(h.input.sequence))
                    tx_apodization=ones(h.input.N_pixels, 1, h.input.N_waves);
                else
                    h.transmit_apodization.focus = h.input.scan;
                    % calculate transmit apodization according to 10.1109/TUFFC.2015.007183
                    if isempty(h.transmit_apodization.sequence) h.transmit_apodization.sequence=h.input.sequence; end
                    tx_apodization=reshape(h.transmit_apodization.data,[h.input.N_pixels, 1, h.input.N_waves]);
                end
            end
            
            % compute signal phase 
            if isempty(h.center_frequency)
                aux_data=h.input.data;
            else
                [dummy dummy rx_propagation_distance]=h.receive_apodization.incidence_aperture();
                aux_data=bsxfun(@times,h.input.data,exp(-1i*2*pi*h.center_frequency*2*rx_propagation_distance/h.sound_speed));
            end
            signal_phase = angle(aux_data);
            
            % auxiliary phase
            mask=(signal_phase<=0);
            auxiliary_phase=signal_phase-pi;
            auxiliary_phase(mask)=signal_phase(mask)+pi;

            % declare output structure
            h.output=uff.beamformed_data(h.input);  % ToDo: instead we should copy everything but the data
            h.FCA=uff.beamformed_data(h.input);     % ToDo: instead we should copy everything but the data
            h.FCC=uff.beamformed_data(h.input);     % ToDo: instead we should copy everything but the data

            switch h.dimension
                case dimension.both
                    coherent_sum=sum(sum(h.input.data,2),3);
                    
                    % collapsing 2nd and 3rd dimmension into 2nd dimension
                    signal_phase=reshape(signal_phase,[h.input.N_pixels, h.input.N_channels*h.input.N_waves 1 h.input.N_frames]);
                    auxiliary_phase=reshape(auxiliary_phase,[h.input.N_pixels, h.input.N_channels*h.input.N_waves 1 h.input.N_frames]);                    
                    apodization_matrix=reshape(bsxfun(@times,tx_apodization,rx_apodization),[h.input.N_pixels, h.input.N_channels*h.input.N_waves]);

                    std_phase=tools.weigthed_std(signal_phase,apodization_matrix,2);
                    std_auxiliary=tools.weigthed_std(auxiliary_phase,apodization_matrix,2);
                    std_complex=sqrt(tools.weigthed_var(cos(signal_phase),apodization_matrix,2)+tools.weigthed_var(sin(signal_phase),apodization_matrix,2));
                case dimension.transmit
                    coherent_sum=sum(h.input.data,3);
                    std_phase=tools.weigthed_std(signal_phase,tx_apodization,3);
                    std_auxiliary=tools.weigthed_std(auxiliary_phase,tx_apodization,3);
                    std_complex=sqrt(tools.weigthed_var(cos(signal_phase),tx_apodization,3)+tools.weigthed_var(sin(signal_phase),tx_apodization,3));
                case dimension.receive
                    coherent_sum=sum(h.input.data,2);
                    std_phase=tools.weigthed_std(signal_phase,rx_apodization,2);
                    std_auxiliary=tools.weigthed_std(auxiliary_phase,rx_apodization,2);
                    std_complex=sqrt(tools.weigthed_var(cos(signal_phase),rx_apodization,2)+tools.weigthed_var(sin(signal_phase),rx_apodization,2));
                otherwise
                    error('Unknown dimension mode; check HELP dimension');
            end
            % min of std deviation of phase and auxiliary phase
            sf=bsxfun(@min,std_phase,std_auxiliary);
                
            % Absolute phase coherence factor
            h.FCA.data=1-(h.gamma/h.sigma_0).*sf;
            h.FCA.data(h.FCA.data < 0) = 0;
            h.FCA.data(isnan(h.FCA.data)) = 0;

            % Complex phase coherence factor
            h.FCC.data=1-std_complex;

            % phase coherent factor image            
            h.output.data = h.FCC.data .* coherent_sum; 
            
            % pass reference
            output = h.output;
            
            % update hash
            h.save_hash();
        end   
    end
end



