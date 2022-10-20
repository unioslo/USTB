classdef generalized_coherence_factor < postprocess
%GENERALIZED_COHERENCE_FACTOR   Matlab implementation of Li et al Generalized Coherence Factor
%
%   MATLAB implementation of Li et al Generalized coherence factor beamforming
%   method as described in the paper:
%
%   Pai-Chi Lin and Meng-Lin Li, "Adaptive Imaging Using the Generalized
%   Coherence Factor" IEEE TUFFC 50(2):128-141, 2003.
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
        function h=coherence_factor()
            h.name='Generalized Coherence Factor MATLAB';   
            h.reference= 'Pai-Chi Lin and Meng-Lin Li, "Adaptive Imaging Using the Generalized Coherence Factor" IEEE TUFFC 50(2):128-141, 2003.';                
            h.implemented_by={'Ole Marius Hoel Rindal <olemarius@olemarius.net>','Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>'};    
            h.version='v1.0.1';
        end
    end
        
    %% Additional properties
    properties
        GCF                                           % BEAMFORMED_DATA class with the computed coherent factor
        active_element_criterium=0.16;                % value to decide whether an element is used or not. This value depends on the SNR so it must be adjusted on a case-by-case basis.
        dimension = dimension.both;                   % dimension class that specifies whether the process will run only on transmit, receive, or both.
        M0 = 4;                                       % low frequency
    end

    methods
        function output = go(h)
            % check if we can skip calculation
            if h.check_hash()
                output= h.output; 
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

            % declare output structure
            h.output=uff.beamformed_data(h.input); % ToDo: instead we should copy everything but the data
            h.GCF=uff.beamformed_data(h.input); % ToDo: instead we should copy everything but the data

            % integrated cofficients
            apertureIndeces = 1;
            waveIndeces = 1;
            if h.M0 > 1
                if h.input.N_channels>1
                    apertureIndeces = [1:h.M0+1 h.input.N_channels-h.M0+1:h.input.N_channels];
                end
                if h.input.N_waves>1
                    waveIndeces = [1:h.M0+1 h.input.N_waves-h.M0+1:h.input.N_waves];
                end
            end

            switch h.dimension
                case dimension.both
                    active_elements=double(bsxfun(@times,tx_apodization,rx_apodization)>h.active_element_criterium);
                    coherent_sum=sum(sum(h.input.data,2),3);
                    fft_data=permute(fft2(permute(h.input.data,[2 3 1 4])),[3 1 2 4]);
                    LF_sum=sum(sum(abs(fft_data(:,apertureIndeces,waveIndeces,:)).^2,2),3);
                    total_sum=sum(sum(abs(fft_data).^2,2),3);
                    M=sum(sum(active_elements,2),3);
                case dimension.transmit
                    active_elements=double(tx_apodization>h.active_element_criterium);
                    coherent_sum=sum(h.input.data,3);
                    fft_data=fft(h.input.data,[],3);
                    LF_sum=sum(abs(fft_data(:,:,waveIndeces,:)).^2,3);
                    total_sum=sum(abs(fft_data).^2,3);
                    M=sum(active_elements,3);
                case dimension.receive
                    active_elements=double(rx_apodization>h.active_element_criterium);
                    coherent_sum=sum(h.input.data,2);
                    fft_data=fft(h.input.data,[],2);
                    LF_sum=sum(abs(fft_data(:,apertureIndeces,:,:)).^2,2);
                    total_sum=sum(abs(fft_data).^2,2);
                    M=sum(active_elements,2);
                otherwise
                    error('Unknown dimension mode; check HELP dimension');
            end
            
            % Coherent Factor
            h.GCF.data = LF_sum./total_sum; 
            h.GCF.data(isnan(h.GCF.data))=0;
            % generalized coherent factor image            
            h.output.data = h.GCF.data .* coherent_sum;
            
            % pass reference
            output = h.output;
            
            % update hash
            h.save_hash();
        end   
    end
end



