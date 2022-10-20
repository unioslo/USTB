classdef fast_demodulation < preprocess
    %FAST_DEMODULATION   Faster implementation of IQ demodulation in MATLAB
    %
    %   authors: Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>
    %            Stefano Fiorentini <stefano.fiorentini@ntnu.no>
    %
    %   $Last updated: 2020/10/06$
    
    %% constructor
    methods (Access = public)
        function h = fast_demodulation()
            h.name='Fast IQ demodulation implementation in MATLAB';
            h.reference='www.ustb.no';
            h.implemented_by={'Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>', ...
                'Stefano Fiorentini <stefano.fiorentini@ntnu.no>'};
            h.version='v1.2.0';
        end
    end
    
    properties (Access = public)
        plot_on = false                             % plot intermediate graphs
        modulation_frequency                        % modulation frequency [Hz]
        downsample_frequency                        % sampling frequency after downsampling [Hz]
        lowpass_frequency_vector = [0.5, 1];        % start and end of the transition band, defined
                                                    % as a multiple of the modulation frequency
    end
    
    properties (Dependent)
        b                                           % Low-pass FIR filter coefficients
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
                    'The estimated central frequency will be used. ']);

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
            
            % Calculate gr delay introduced by the filter
            b = h.b; %#ok<*PROP>
            delay = (length(b) - 1) / 2 / h.input.sampling_frequency;
            
            % Plot RF channel data power spectrum
            if(h.plot_on)      
                if ~exist('pw', 'var')
                    [fx, pw] = tools.power_spectrum(h.input.data, h.input.sampling_frequency);
                end
                
                pv = max(pw);       % find peak value
                
                figure('Color', 'w')
                subplot(1,2,1)
                hold on
                obj = plot(fx*1e-6, 10*log10(pw), 'k', 'LineWidth', 1, ...
                    'DisplayName', 'RF channel data');
                plot([h.modulation_frequency, h.modulation_frequency]*1e-6, ...
                    [-120, 0]+10*log10(pv), 'r--', 'LineWidth', 1)
                plot(-[h.modulation_frequency, h.modulation_frequency]*1e-6, ...
                    [-120, 0]+10*log10(pv), 'r--', 'LineWidth', 1)
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
            
            if s < tools.getAvailableMemory() / 4 
                % Down-mix
                data = h.input.data .* exp(-1j*2*pi*h.modulation_frequency*h.input.time);
                
                if(h.plot_on)
                    [fx, pw] = tools.power_spectrum(data, h.input.sampling_frequency);
                    
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
                    drawnow()
                end
                
                % Perform base-band filtering
                fprintf(1, 'Low-pass filtering\n');
                data = filter(b, 1, data, [], 1);
                
                if(h.plot_on)
                    [fx, pw] = tools.power_spectrum(data, h.input.sampling_frequency);
                    
                    pv = max(pw);       % find peak value
                    
                    H = freqz(b, 1, 1024, 'whole', h.input.sampling_frequency);
                    H = fftshift(H);
                    F = linspace(-h.input.sampling_frequency/2, h.input.sampling_frequency/2, 1025);
                    F(end) = [];

                    subplot(1,2,2)
                    hold on
                    obj(2) = plot(fx*1e-6, 10*log10(pw), 'c--', 'LineWidth', 1, ...
                        'DisplayName', 'IQ channel data');
                    obj(3) = plot(F*1e-6, ...
                        10*log10(abs(H).^2 / max(abs(H).^2)) + 10*log10(pv), 'b-', ...
                        'DisplayName', 'Low-pass filter frequency response');
                    hold off
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
                % Down-mix
                downmix = exp(-1j*2*pi*h.modulation_frequency*h.input.time);
                tmp = h.input.data(:,:,:,1) .* downmix;   
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
                    drawnow()
                end
                % Filter
                tmp = filter(b, 1, tmp, [], 1);   
                if(h.plot_on)
                    [fx, pw] = tools.power_spectrum(tmp, h.input.sampling_frequency);
                    
                    pv = max(pw);       % find peak value
                    
                    H = freqz(b, 1, 1024, 'whole', h.input.sampling_frequency);
                    H = fftshift(H);
                    F = linspace(-h.input.sampling_frequency/2, h.input.sampling_frequency/2, 1025);
                    F(end) = [];
                    
                    subplot(1,2,2)
                    hold on
                    obj(2) = plot(fx*1e-6, 10*log10(pw), 'c--', 'LineWidth', 1, ...
                        'DisplayName', 'IQ channel data');
                    obj(3) = plot(F*1e-6, ...
                        10*log10(abs(H).^2 / max(abs(H).^2)) + 10*log10(pv), 'b-', ...
                        'DisplayName', 'Low-pass filter frequency response');
                    hold off
                    legend(obj, 'location', 'southeast')
                    drawnow()
                end
                % Decimate
                data(:,:,:,1) = tmp(1:Ndown:end, :, :, 1);   
                
                % Rest of the frames are processed together
                for i = 2:size(h.input.data, 4)
                    tmp = h.input.data(:,:,:,i) .* downmix;     % Down-mix
                    tmp = filter(b, 1, tmp, [], 1);          	% Filter
                    data(:,:,:,i) = tmp(1:Ndown:end, :, :); 	% Decimate
                end
            end
            
            % Create output channel data object
            h.output = uff.channel_data(h.input);
            h.output.initial_time = h.output.initial_time - delay;
            h.output.modulation_frequency = h.modulation_frequency;
            h.output.sampling_frequency = h.downsample_frequency;
            h.output.data = data;
            
            % Pass reference
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
        function set.lowpass_frequency_vector(h, val)
            validateattributes(val, {'numeric'}, {'nonnegative', 'size', [1, 2], 'real'})
            h.lowpass_frequency_vector = val;
        end
    end
    
    %% get methods
    methods
        function val = get.b(h)
            % Filter specification
            A = [1, 0];                                                      	% band type: 0='stop', 1='pass'
            dev = [1e-2, 1e-3];                                                	% max ripple in pass-band and stop-band
            [N, Wn, beta, ftype] = kaiserord(h.lowpass_frequency_vector * ...
                h.modulation_frequency, A, dev, h.input.sampling_frequency);   	% window parameters
            val = fir1(N, Wn, ftype, kaiser(N+1,beta), 'noscale');             	% filter design
        end
    end
end
