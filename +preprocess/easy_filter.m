classdef easy_filter < preprocess
    %EASY_FILTER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        numerator
        denominator
        group_delay_compensation
    end

    properties (Dependent)
        sampling_frequency
    end
    
    methods
        function fs = get.sampling_frequency(obj)
            fs = 1;
            if ~isempty(obj.input)
                fs = obj.input.sampling_frequency;
            end
        end
    end

    methods
        function obj = easy_filter()
            obj.numerator = 1;
            obj.denominator = 1;
            obj.group_delay_compensation = [];
        end
        
        function output = go(obj)
            [data_filt, ~] = filter(obj.numerator, obj.denominator, obj.input.data, [], 1);
            
            obj.output = uff.channel_data(obj.input);
            obj.output.data = data_filt;

            % If group_delay_compensation is provided, correct it using circshift
            if ~isempty(obj.group_delay_compensation)
                obj.output.data = circshift(obj.output.data, -obj.group_delay_compensation, 1);
            end

            output = obj.output;
        end

        function [h,w] = frequency_response(obj,N)
            arguments
                obj (1,1)
                N (1,1) double = 512;
            end

            [h,w] = freqz(obj.numerator, obj.denominator, N, obj.sampling_frequency);
        end
        
        function [phi, w] = phase_response(obj,N)
            arguments
                obj (1,1)
                N (1,1) double = 512;
            end

            [phi, w] = phasez(obj.numerator, obj.denominator, N, obj.sampling_frequency);
        end

        function fig = plot(obj, h, N)
            arguments
                obj
                h (1,1) handle = figure();
                N (1,1) double = 512;
            end

            fig = h;

            [H, w] = obj.frequency_response(N);
            [phi, ~] = obj.phase_response(N);
            
            % Create figure with two y-axes
            axes(h);
            yyaxis left
            plot(w, 20*log10(abs(H)));
            ylabel('Magnitude (dB)');
            
            yyaxis right
            plot(w, phi);
            ylabel('Phase (radians)');
            xlabel('Frequency (Hz)');
            xlim([min(w), max(w)]);
            
            title('Frequency and Phase Response');
            grid on;
            legend('Magnitude', 'Phase');
        end
    end
end

