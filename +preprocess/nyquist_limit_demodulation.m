classdef nyquist_limit_demodulation < preprocess
    %NYQUIST_LIMIT_DEMODULATION   IQ demodulation at 2 samples per wavelength
    %
    %   Converts RF channel data to IQ (complex) channel data using a minimal
    %   demodulation scheme at the Nyquist limit (Fs/4). Assumes 4 samples per
    %   wavelength. Preprocess modifies channel data before beamforming.
    %
    %   Input:  uff.channel_data -> Output: uff.channel_data
    %
    %   Properties:
    %       plot_on                      plot intermediate graphs
    %
    %   Example:
    %       obj = preprocess.nyquist_limit_demodulation();
    %
    %   See also PREPROCESS, DEMODULATION
    
    %% constructor
    methods (Access = public)
        function h=nyquist_limit_demodulation()
            h.name='2 samples per wavelength demodulation MATLAB';
            h.reference='www.ustb.no';
            h.implemented_by={'Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>'};
            h.version='v1.0.5';
        end
    end
    
    properties (Access = public)
        plot_on                     % plot intermediate graphs
    end
    
    methods
        function output=go(h)
            
            % check if we can skip calculation
            if h.check_hash()
                output= h.output;
                return;
            end
            
            modulation_frequency= h.input.sampling_frequency/4;
            siz = size(h.input.data);
            N = prod(siz(3:end));        % collapse dimensions beyond 3
            
            %% copy data
            data = h.input.data(:,:,1:N);
            
            %% show spectrum
            if(h.plot_on)
                %fft_data = fftshift(fft(data(:,:), 1024));
                [fx pw] = tools.power_spectrum(h.input.data,h.sampling_frequency);
                assert(sum(pw)>0,'Dataset is zero');
                figure();
                subplot(1,2,1);
                plot(fx*1e-6,pw,'k'); hold on; axis manual; grid on;
                plot([modulation_frequency modulation_frequency]*1e-6,[0 1],'r--');
                plot(-[modulation_frequency modulation_frequency]*1e-6,[0 1],'r--');
                axis([-4*modulation_frequency*1e-6 4*modulation_frequency*1e-6 0 1]);
                xlabel('f [MHz]');
                ylabel('Relative amplitude');
                title('Before demodulation');
            end
            
            %% demodulation
            L=siz(1)-mod(siz(1),4);
            demod_data = zeros(size(data(1:4:L,:,:)));
            demod_data(1:L/4,:,:) =     (data(1:4:L,:,:) + data(2:4:L,:,:)/1i);
            %demod_data(1:2:L/2,:,:) =     data(1:4:L,:,:) + exp(-j/5)*data(2:4:L,:,:)/j;
            %demod_data(2:2:L/2,:,:) = - ( data(3:4:L,:,:) + exp(-j/5)*data(4:4:L,:,:)/j);
            
            if(h.plot_on)
                [fx pw] = tools.power_spectrum(demod_data,h.sampling_frequency/4);
                subplot(1,2,2);
                plot(fx*1e-6,pw,'k-'); hold on; grid on; axis manual;
                plot([0 0]*1e-6,[0 1],'r--');
                plot(-2*[modulation_frequency modulation_frequency]*1e-6,[0 1],'r--');
                axis([-4*modulation_frequency*1e-6 4*modulation_frequency*1e-6 0 1]);
                xlabel('f [MHz]');
                ylabel('Relative amplitude');
                title('After demodulation');
            end
            
            % copy results
            h.output=uff.channel_data(h.input);
            h.output.modulation_frequency = modulation_frequency;
            h.output.sampling_frequency = modulation_frequency;
            h.output.data=reshape(demod_data,[L/4 siz(2:end)]);
            
            % pass reference
            output = h.output;
            
            % update hash
            h.save_hash();
        end
    end
    
    %% set methods
    methods
        %         function h=set.input(h,in_data)
        %             assert(isa(in_data,'uff.channel_data'), 'The input channel_data is not a CHANNEL_DATA class. Check HELP CHANNEL_DATA.');
        %             assert(in_data.modulation_frequency==0,sprintf('The input channel_data is already demodulated with %0.2 MHz',in_data.modulation_frequency/1e6));
        %             assert(~isempty(in_data.data),'The input channel_data is empty');
        %             assert(any(in_data.data(:)>0),'The input channel_data is zero');
        %
        %             timediff=in_data.time(2)-in_data.time(1);
        %             assert(timediff>0,'The time interval of the time vector in the channel_data is zero');
        %
        %             h.sampling_frequency=1/timediff;
        %             h.input=in_data;
        %         end
        function h=set.plot_on(h,in_plot_on)
            assert(isa(in_plot_on,'logical'), 'The input plot_on is not a LOGICAL class (true/false). Check HELP LOGICAL.');
            h.plot_on=in_plot_on;
        end
    end
    
end
