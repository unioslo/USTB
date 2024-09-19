classdef refocus < preprocess
    %REFOCUS
    %
    %   authors: Anders E. Vrålstad <anders.e.vralstad@ntnu.no>
    %            Nick Bottenus
    %            Rehman Ali
    %   
    %   Code adapted from 
    %   github.com/nbottenus/REFoCUS
    %   
    %   $Last updated: 2024/09/19$
    
    %% constructor
    methods (Access = public)
        function h = refocus()
            h.name='REFoCUS implemented in MATLAB';
            h.reference='www.github.com/nbottenus/REFoCUS';
            h.implemented_by={'Anders E. Vrålstad <anders.e.vralstad@ntnu.no>'};
            h.version='v1.1.0'; 
        end
    end
    
    properties (Access = public)
        post_pad_samples = 200;
        use_filter = false;
        filter_N = 10;
        filter_Wn = [0.05,0.3];
        regularization = @Hinv_adjoint;
        decode_parameter = [];
    end  

    methods (Access = public)
        % REFOCUS_DECODE Decode focused beams using the applied delays
        %
        % rf_decoded = REFOCUS_DECODE(rf_encoded,s_shift)
        %
        % Parameters:
        %   rf_encoded - RF data - samples x receive channel x transmit event
        %   delays - Applied delays in samples - transmit event x transmit element
        %
        % Name/value pairs:
        %   'fun' - Inverse function (default = @Hinv_adjoint)
        %   'apod' - Apodization applied for each transmit (same size as s_shift)
        %   'param' - Parameter for the inverse function
        function rf_decoded = refocus_decode(h,rf_encoded,delays,varargin)
            p=inputParser;
            p.addOptional('fun',@Hinv_adjoint);
            p.addOptional('apod',[]);
            p.addOptional('param',[]);
            p.parse(varargin{:});
            
            [n_samples, n_receives, n_transmits]=size(rf_encoded);
            n_elements=size(delays,2);
            assert(size(delays,1)==n_transmits,'Transmit count inconsistent between rf_encoded and delays')
            
            % Default apodization is all ones
            if(isempty(p.Results.apod))
                apod = ones(size(delays));
            else
                apod = p.Results.apod;
                assert(all(size(apod)==size(delays)),'Apodization size should match delays size')
            end
            
            % Promote to floating point if needed
            if(~isfloat(rf_encoded))
                rf_encoded=single(rf_encoded);
            end
            
            % 1-D FFT to convert time to frequency
            RF_encoded=fft(single(rf_encoded));
            RF_encoded=permute(RF_encoded,[3 2 1]); % (transmit event x receive channel x time sample)
            frequency=(0:n_samples-1)/n_samples;
            
            % Apply encoding matrix at each frequency
            RF_decoded = zeros(n_samples,n_elements,n_receives,'like',rf_encoded);
            for i=2:ceil(n_samples/2) % only compute half, assume symmetry, skip 0 frequency
                Hinv = p.Results.fun(h,delays,frequency(i),apod,p.Results.param);
                RF_decoded(i,:,:) = Hinv*RF_encoded(:,:,i);
            end
            RF_decoded=permute(RF_decoded,[1 3 2]); % (frequency x receive channel x transmit element)
            
            % Inverse FFT for real signal
            rf_decoded=ifft(RF_decoded,'symmetric');
        end
        
        %H_MODEL_MATRIX Computes H Matrix Based on Delays, Frequency, and Apodization
        % H = ForwardModel(delays,f,apod)
        % INPUTS:
        %   delays = N x M matrix (N transmits, M elements) of delays (in samples)
        %   f = Normalized Frequency (1/samples) Ranging from 0 to 1
        %   apod = N x M matrix of apodizations
        % OUTPUTS:
        %   H = N x M model matrix
        function H = H_model_matrix(h,delays,f,apod)
            % Model Matrix with Delay, Frequency, and Apodization
            H = apod.*exp(-1j*2*pi*f*delays);
        end
        
        %H_INV_ADJOINT Computes Adjoint of H Matrix
        % Hinv = Hinv_adjoint(delays,f,apod,param)
        % INPUTS:
        %   delays = N x M matrix (N transmits, M elements) of delays (in samples)
        %   f = Normalized Frequency (1/samples) Ranging from 0 to 1
        %   apod = N x M matrix of apodizations
        %   param = function handle as a function of frequency (e.g. param = @(f) f)
        % OUTPUTS:
        %   Hinv = M x N matrix inverse of H 
        function Hinv = Hinv_adjoint(h,delays,f,apod,param)
            % Forward Model Matrix
            H = h.H_model_matrix(delays,f,apod);
            % Adjoint (Conjugate Transpose)
            Hinv = H';
            % Default (No Ramp Filter)
            if(~isempty(param))
                Hinv = param(f)*Hinv;
            end
        end
        
        %H_INV_TIKHONOV Computes Tikhonov Regularized Inverse of H Matrix
        % Hinv = Hinv_tikhonov(delays,f,apod,param)
        % INPUTS:
        %   delays = N x M matrix (N transmits, M elements) of delays (in samples)
        %   f = Normalized Frequency (1/samples) Ranging from 0 to 1
        %   apod = N x M matrix of apodizations
        %   param = Regularization Parameter
        % OUTPUTS:
        %   Hinv = M x N matrix inverse of H 
        function Hinv = Hinv_tikhonov(h,delays,f,apod,param)
            % Forward Model Matrix
            H = h.H_model_matrix(delays,f,apod);
            % Default Regularization Parameter Value
            if(isempty(param))
                param = 1e-3;
            end
            % Regularization Relative to Maximum Singular Value
            smax = norm(H,2); N = size(H,2); 
            reg = param*smax*eye(N);
            % Tikhonov Regularized Inverse Matrix
            Hinv = (H'*H + reg'*reg)\H';
        end
        
        %H_INV_RSVD Computes Regularized SVD-Based Inverse of H Matrix
        % Hinv = Hinv_rsvd(delays,f,apod,param)
        % INPUTS:
        %   delays = N x M matrix (N transmits, M elements) of delays (in samples)
        %   f = Normalized Frequency (1/samples) Ranging from 0 to 1
        %   apod = N x M matrix of apodizations
        %   param = Regularization Parameter
        % OUTPUTS:
        %   Hinv = M x N matrix inverse of H 
        function Hinv = Hinv_rsvd(h,delays,f,apod,param)
            % Forward Model Matrix
            H = h.H_model_matrix(delays,f,apod);
            % Compute SVD of H
            [U,S,V] = svd(H); 
            % Default Regularization Parameter Value
            if(isempty(param))
                param = 1e-3;
            end
            % Regularized Inversion Singular Value Matrix
            Sinv = S./(S.^2+(param*S(1))^2); % Regularize small values
            Sinv(S==0) = 0; % Only preserve the diagonal
            % Regularized Inversion of Model Matrix
            Hinv = V*Sinv'*U';
        end
        
        %H_INV_TSVD Computes Truncated SVD-Based Inverse of H Matrix
        % Hinv = Hinv_tsvd(delays,f,apod,param)
        % INPUTS:
        %   delays = N x M matrix (N transmits, M elements) of delays (in samples)
        %   f = Normalized Frequency (1/samples) Ranging from 0 to 1
        %   apod = N x M matrix of apodizations
        %   param = Truncation Parameter
        % OUTPUTS:
        %   Hinv = M x N matrix inverse of H 
        function Hinv = Hinv_tsvd(h,delays,f,apod,param)
            % Forward Model Matrix
            H = h.H_model_matrix(delays,f,apod);
            % Compute SVD of H
            [U,S,V] = svd(H);
            % Default Truncation Parameter Value
            if(isempty(param))
                param = 1e-3;
            end
            % Truncate Singular Value Matrix
            Sinv = 1./S;
            Sinv(S<param*S(1)) = 0; % Truncate small values
            Sinv(S==0) = 0; % Only preserve the diagonal
            % Regularized Inversion of Model Matrix
            Hinv = V*Sinv'*U';
        end
    end    
    
    methods (Access = public)
        function output=go(h)  
            % Check if we can skip calculation
            if h.check_hash()
                output= h.output;
                return;
            end

            % If IQ
            if abs(h.input.modulation_frequency)>eps
                error('Only implemented for RF channel data, not IQ.')
            end
            
            N_channels = h.input.N_channels;
            N_waves = h.input.N_waves;
            N_frames = h.input.N_frames;
            
            tx_delays = zeros(N_channels,N_waves);
            tx_apod = zeros(N_channels,N_waves);
            for wave = 1:N_waves
                tx_delays(:,wave) = h.input.sequence(wave).delay_values - h.input.sequence(wave).delay;
                tx_apod(:,wave) = h.input.sequence(wave).apodization_values;
            end
         
            rxdata_multiTx = padarray(h.input.data,h.post_pad_samples,'post');
            normalized_rxdata_multiTx = double(rxdata_multiTx / max(rxdata_multiTx(:)));
            N_samples_output = size(normalized_rxdata_multiTx,1);

            %%
            full_synth_data = zeros(N_samples_output, N_channels, N_channels,N_frames);
            for fr = 1:N_frames
            % Decode Multistatic Data Using REFoCUS
                full_synth_data(:,:,:,fr) = h.refocus_decode(normalized_rxdata_multiTx(:,:,:,fr),tx_delays.'*double(h.input.sampling_frequency),...
                'fun',h.regularization,'apod',tx_apod.','param',h.decode_parameter);
            end
            
            % Passband Filter Channel Data
            if h.use_filter
                [b, a] = butter(h.filter_N, h.filter_Wn); % Filter
                full_synth_data = filtfilt(b, a, double(full_synth_data));
            end

            % Create output channel data object
            h.output = uff.channel_data();
            h.output.initial_time = h.input.initial_time;
            h.output.modulation_frequency = h.input.modulation_frequency;
            h.output.sampling_frequency = h.input.sampling_frequency;
            h.output.data = single(full_synth_data);
            h.output.sound_speed = h.input.sound_speed;
            h.output.probe = uff.probe; h.output.probe.geometry = h.input.probe.geometry;
            h.output.sequence = uff.wave;

            for wave = 1:N_channels
                h.output.sequence(wave) = uff.wave;
                h.output.sequence(wave).probe = uff.probe; 
                h.output.sequence(wave).probe.geometry = h.input.probe.geometry; 
                h.output.sequence(wave).sound_speed = h.input.sound_speed;
                h.output.sequence(wave).source = uff.point('xyz', h.input.probe.geometry(wave,1:3));
                h.output.sequence(wave).delay = sqrt(sum(h.output.sequence(wave).source.xyz.^2)) / h.output.sequence(wave).sound_speed; 
                h.output.sequence(wave).origin = uff.point('xyz', h.input.probe.geometry(wave,1:3));
            end
            
            % Pass reference
            output = h.output;

            % Update hash
            h.save_hash();
        end
    end
end


