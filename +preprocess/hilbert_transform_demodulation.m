classdef hilbert_transform_demodulation < preprocess
    %HILBERT_DEMODULATION   Hilbert transform-based implementation of IQ demodulation in MATLAB
    %
    %
    %   authors: Bastien Denarie
    %            Stefano Fiorentini <stefano.fiorentini@ntnu.no>
    %
    %   $Last updated: 2020/10/9$
    
    %% constructor
    methods (Access = public)
        function h = hilbert_transform_demodulation()
            h.name='Hilbert transform-based IQ demodulation in MATLAB';
            h.reference='www.ustb.no';
            h.implemented_by={'Bastien Denaire', ...
                'Stefano Fiorentini <stefano.fiorentini@ntnu.no>'};
            h.version='v1.1.0';
        end
    end
    
    properties (Access = public)
        plot_on = false             % plot intermediate graphs
        modulation_frequency        % modulation frequency [Hz]
        downsample_frequency        % sampling frequency after downsampling [Hz]
    end
    
    methods
        function output=go(h)
            
            % Check if we can skip calculation
            if h.check_hash()
                output= h.output;
                return;
            end
            
            % Estimate modulation frequency if needed
            if isempty(h.modulation_frequency)
                warning(['The modulation frequency is not specified. ', ...
                    'The estimated central frequency will be used. '])

                [fx, pw] = tools.power_spectrum(h.input.data, h.input.sampling_frequency);
                
                % computing central frequency and bandwidth
                fprintf(1, 'Estimating power spectrum\n');
                [dc, ic] = max(pw); 

                bw_lo = interp1(pw(1:ic), fx(1:ic), dc/2);      % -6dB lower limit
                bw_up = interp1(pw(ic:round(end/2)), ...
                    fx(ic:round(end/2)), dc/2);                 % -6dB upper limit
                fc = (bw_lo+bw_up)/2;                           % center frequency
                
                % Set modulation ferquency
                h.modulation_frequency = -fc;
            end
            
            % Estimate downsampling frequency if needed
            if isempty(h.downsample_frequency)
                warning(['The downsampling frequency is not specified. ', ...
                    'Using 2 * modulation_frequency.'])
                
                h.downsample_frequency = 2 * h.modulation_frequency;
            end
            
            % Check whether the RF sampling frequency is a multiple of the 
            % downsample frequency
            if mod(h.input.sampling_frequency, h.downsample_frequency) ~= 0
                warning(['The input sample frequency is not a multiple of the specified downsample frequency. ', ...
                    'Rounding up the downsample frequency to the next higher downsample frequency.'])
            end
            
            Ndown = floor(h.input.sampling_frequency / h.downsample_frequency);
            h.downsample_frequency = h.input.sampling_frequency / Ndown;
            
                            
            % Plot RF channel data power spectrum
            if(h.plot_on)      
                if ~exist('pw', 'var')
                    [fx, pw] = tools.power_spectrum(h.input.data, h.input.sampling_frequency);
                end
                
                pv = max(pw);       % find peak value
                
                figure('Color', 'w')
                subplot(1,2,1)
                hold on
                obj = plot(fx*1e-6, 10*log10(pw), 'k', 'LineWidth', 1, 'DisplayName', 'RF channel data');
                plot([h.modulation_frequency, h.modulation_frequency]*1e-6, [-120, 0]+10*log10(pv), 'r--', ...
                    'LineWidth', 1)
                plot(-[h.modulation_frequency, h.modulation_frequency]*1e-6, [-120, 0]+10*log10(pv), 'r--', ...
                    'LineWidth', 1)
                hold off
                xlim([-2*h.modulation_frequency, 2*h.modulation_frequency]*1e-6)
                ylim([-120, 0])
                grid on
                box on
                xlabel('f [MHz]')
                ylabel('Power spectrum [dB]')
                legend(obj, 'location', 'southeast')
                drawnow()
            end
            
            % Perform check to ensure that the complex matrix will fit into
            % memory. If not, print a warning and process dataset in a loop     
            
            s = numel(h.input.data) * (isa(h.input.data, 'double')*8 + ...
                isa(h.input.data, 'single')*4); % approximate size of RF channel data
            
            if s < tools.getAvailableMemory() / 3 
                % Down-mix
                data = h.input.data .* exp(-1j*2*pi*h.modulation_frequency*h.input.time);
            
            % Calculate pre-envelope
            data = hilbert(h.input.data); 
            
            % Down-mix
            
            data = data .* exp(-1j*2*pi*h.modulation_frequency*h.input.time);
            
            if(h.plot_on)
                [fx, pw] = tools.power_spectrum(data, h.input.sampling_frequency);
                
                pv = max(pw);       % find peak value
                
                subplot(1,2,2)
                hold on
                obj = plot(fx*1e-6, 10*log10(pw), 'k', 'LineWidth', 1, 'DisplayName', 'IQ channel data');
                plot([0, 0]*1e-6, [-120, 0]+10*log10(pv), 'r--', 'LineWidth', 1)
                hold off
                xlim([-h.downsample_frequency, h.downsample_frequency]*1e-6)
                ylim([-120, 0])
                grid on
                box on
                xlabel('f [MHz]')
                ylabel('Power spectrum [dB]')
                legend(obj, 'location', 'southeast')
                drawnow()
            end
            
            % Decimate
            data = data(1:Ndown:end, :, :, :);
            
            else
                warning(['Size of RF channel data is greater than 30% of the available memory. ', ...
                    'Data will be processed in a loop to prevent out-of-memory issues.'])
                
                % Pre-allocate IQ channel data matrix
                data = complex(zeros([length(1:Ndown:size(h.input.data, 1)), ...
                    size(h.input.data, [2, 3, 4])], 'like', h.input.data));
                
                % Process 1st frame separately to allow plotting   
                tmp = hilbert(h.input.data(:,:,:,1)); 
                
                % Down-mix
                downmix = exp(-1j*2*pi*h.modulation_frequency*h.input.time);
                tmp = tmp .* downmix;
                
                if(h.plot_on)
                    [fx, pw] = tools.power_spectrum(tmp, h.input.sampling_frequency);
                    
                    pv = max(pw);       % find peak value
                    
                    subplot(1,2,2)
                    hold on
                    obj = plot(fx*1e-6, 10*log10(pw), 'k', 'LineWidth', 1, ...
                        'DisplayName', 'Down-mixed channel data');
                    plot([0, 0]*1e-6, [-120, 0]+10*log10(pv), 'r--', 'LineWidth', 1)
                    hold off
                    xlim([-h.downsample_frequency, h.downsample_frequency]*1e-6)
                    ylim([-120, 0])
                    grid on
                    box on
                    xlabel('f [MHz]')
                    ylabel('Power spectrum [dB]')
                    legend(obj, 'location', 'southeast')
                    drawnow()
                end
                % Decimate
                data(:,:,:,1) = tmp(1:Ndown:end, :, :, 1);   
                
                % Rest of the frames are processed together
                for i = 2:size(h.input.data, 4)
                    tmp = hilbert(h.input.data(:,:,:,i));      	% Calculate pre-envelope
                    tmp = tmp .* downmix;                       % Down-mix
                    data(:,:,:,i) = tmp(1:Ndown:end, :, :, :); 	% Decimate
                end
            end
            
            % Create output channel data object
            h.output = uff.channel_data(h.input);
            h.output.modulation_frequency = h.modulation_frequency;
            h.output.sampling_frequency = h.downsample_frequency;
            h.output.data = data;
            
            % pass reference
            output = h.output;
            
            % Update hash
            h.save_hash();
        end
    end
    
    %% set methods
    methods
        function set.plot_on(h, val)
            validateattributes(val, {'logical'}, {'scalar'})
            h.plot_on = val;
        end
        function set.modulation_frequency(h, val)
            validateattributes(val, {'numeric'}, {'scalar', 'real', 'nonzero'})
            h.modulation_frequency = val;
        end
        function set.downsample_frequency(h, val)
            validateattributes(val, {'numeric'}, {'scalar', 'real'})
            h.downsample_frequency = val;
        end
    end   
end
