classdef channel_data < uff
    %CHANNEL_DATA   UFF class to hold channel data
    %   CHANNEL_DATA contains raw ultrasound data as acquired from an
    %   ultrasound scanner. Data is stored in the property _data_ with
    %   dimensions:
    %
    %   [time dimension x channel dimension x wave dimension x frame dimension]
    %
    %   Compulsory properties:
    %         sampling_frequency         sampling frequency [Hz]
    %         initial_time               time of the initial sample [s]
    %         sound_speed                reference sound speed [m/s]
    %         modulation_frequency       modulation frequency [Hz]
    %         sequence                   collection of UFF.WAVE objects
    %         probe                      UFF.PROBE object
    %         data                       data [time dim. x channel dim. x wave dim. x frame dim.]
    %
    %   Optional properties:
    %         pulse                      UFF.PULSE object
    %         phantom                    UFF.PHANTOM object
    %         PRF                        pulse repetition frequency [Hz]
    %
    %   Example:
    %         chn_dta = uff.channel_data();
    %
    %   See also UFF.CHANNEL_DATA, UFF.BEAMFORMED_DATA, UFF.PROBE
    
    %   authors: Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>
    %   $last updated: 2017/02/24 $
    
    %% compulsory properties
    properties  (Access = public)
        sampling_frequency              % sampling frequency [Hz]
        initial_time                    % time of the initial sample [s]
        sound_speed             = 1540  % reference sound speed [m/s]
        modulation_frequency    = 0     % modulation frequency [Hz]
        sequence                        % collection of UFF.WAVE objects
        probe                           % UFF.PROBE object
        data                            % channel data [time dim. x channel dim. x wave dim. x frame dim.]
    end
    
    %% optional properties
    properties  (Access = public)
        PRF                             % pulse repetition frequency [Hz]
        pulse                           % UFF.PULSE object
        phantom                         % UFF.PHANTOM object
        N_active_elements               % number of active transducers on receive
    end
    
    %% dependent properties
    properties  (Dependent)
        N_samples                       % number of samples in the data
        N_elements                      % number of elements in the probe
        N_channels                      % number of elements in the probe
        N_waves                         % number of transmitted waves
        N_frames                        % number of frames
        lambda                          % wavelength [m]
    end
    
    %% constructor -> uff constructor
    methods (Access = public)
        function h=channel_data(varargin)
            h = h@uff(varargin{:});
        end
    end
    
    %% display methods
    methods
        function figure_handle=plot(h,figure_handle_in,n_wave,plot_abs)
            % PLOT Plots channel data
            
            if nargin>1 && not(isempty(figure_handle_in))
                figure_handle=figure(figure_handle_in);
            else
                figure_handle=figure();
            end
            
            if nargin <3
                n_wave=ceil(h.N_waves/2);
            end
            
            if nargin <4
                plot_abs='abs';
            end
            
            colorMap = tools.inferno;
            
            if abs(h.modulation_frequency)>eps
                if strcmp(plot_abs,'abs')
                    pcolor(1:h.N_elements,h.time(n_wave)*1e6,abs(h.data(:,:,n_wave))); grid on; axis tight; colormap(colorMap); shading interp;
                    caxis(max(max(abs(h.data(:,:,n_wave)))) .* [-1 1]);
                    xlabel('Channel');
                    ylabel('time [\mus]');
                    set(gca,'Ydir','reverse');
                    set(gca,'fontsize',14);
                    title(sprintf('Beam %d',n_wave));
                else
                    subplot(1,2,1);
                    pcolor(1:h.N_elements,h.time(n_wave)*1e6,real(h.data(:,:,n_wave))); grid on; axis tight; colormap(colorMap); shading interp;
                    caxis(max(max(abs(real(h.data(:,:,n_wave))))) .* [-1 1]);
                    xlabel('Channel');
                    ylabel('time [\mus]');
                    set(gca,'Ydir','reverse');
                    set(gca,'fontsize',14);
                    title(sprintf('Real Part - Beam %d',n_wave));
                    subplot(1,2,2);
                    pcolor(1:h.N_elements,h.time(n_wave)*1e6,imag(h.data(:,:,n_wave))); grid on; axis tight; colormap(colorMap); shading interp;
                    caxis(max(max(abs(imag(h.data(:,:,n_wave))))) * [-1 1]);
                    xlabel('Channel');
                    ylabel('time [\mus]');
                    set(gca,'Ydir','reverse');
                    set(gca,'fontsize',14);
                    title(sprintf('Imaginary Part - Beam %d',n_wave));
                end
            else
                if strcmp(plot_abs,'abs')
                    pcolor(1:h.N_elements,h.time(n_wave)*1e6,abs(hilbert(h.data(:,:,n_wave)))); grid on; axis tight; colormap(colorMap); shading interp;
                    caxis(max(max(abs(h.data(:,:,n_wave)))) .* [-1 1]);
                    xlabel('Channel');
                    ylabel('time [\mus]');
                    set(gca,'Ydir','reverse');
                    set(gca,'fontsize',14);
                    title(sprintf('Beam %d',n_wave));
                else
                    pcolor(1:h.N_elements,h.time(n_wave)*1e6,h.data(:,:,n_wave)); grid on; axis tight; colormap(colorMap); shading interp;
                    caxis(max(max(abs(h.data(:,:,n_wave)))) .* [-1 1]);
                    xlabel('Channel');
                    ylabel('time [\mus]');
                    set(gca,'Ydir','reverse');
                    set(gca,'fontsize',14);
                    title(sprintf('Beam %d',n_wave));
                end
            end
        end
    end
    
    %% set methods
    methods
        function h=set.phantom(h,in_phantom)
            if ~isempty(in_phantom)
                assert(isa(in_phantom,'uff.phantom'), 'The _phantom_ is not a PHANTOM class. Check HELP PHANTOM.');
            end
            h.phantom=in_phantom;
        end
        function h=set.pulse(h,in_pulse)
            if ~isempty(in_pulse)
                assert(isa(in_pulse,'uff.pulse'), 'The pulse is not a PULSE class. Check HELP PULSE.');
            end
            h.pulse=in_pulse;
        end
        function h=set.probe(h,in_probe)
            if ~isempty(in_probe)
                assert(isa(in_probe,'uff.probe'), 'The probe is not a UFF.PROBE class. Check HELP UFF.PROBE.');
            end
            h.probe=in_probe;
        end
        function h=set.sequence(h,in_sequence)
            if ~isempty(in_sequence)
                assert(isa(in_sequence,'uff.wave'), 'The sequence is not a UFF.WAVE class. Check HELP UFF.WAVE.');
            end
            h.sequence=in_sequence;
        end
        function h=set.sampling_frequency(h,in_sampling_frequency)
            if ~isempty(in_sampling_frequency)
                assert(numel(in_sampling_frequency)==1, 'The sampling frequency must be a scalar in [Hz]');
            end
            h.sampling_frequency=in_sampling_frequency;
        end
        function h=set.modulation_frequency(h,in_modulation_frequency)
            if ~isempty(in_modulation_frequency)
                assert(numel(in_modulation_frequency)==1, 'The sampling frequency must be a scalar in [Hz]');
            end
            h.modulation_frequency=in_modulation_frequency;
        end
        function h=set.sound_speed(h,in_sound_speed)
            if ~isempty(in_sound_speed)
                assert(numel(in_sound_speed)==1, 'The sound speed must be a scalar in [m/s]');
            end
            h.sound_speed=in_sound_speed;
        end
        function h=set.initial_time(h,in_initial_time)
            if ~isempty(in_initial_time)
                assert(numel(in_initial_time)==1, 'The initial time must be a scalar in [s]');
            end
            h.initial_time=in_initial_time;
        end
        function h=set.data(h,in_data)
            % checking needed inputs -> We cannot set an order in which
            % users will define data
            %            assert(~isempty(h.probe), 'The probe structure must be set before inserting the data.');
            %            assert(~isempty(h.sequence), 'The sequence structure must be set before inserting the data.');
            %            assert(~isempty(h.sampling_frequency), 'The sampling_frequency must be set before inserting the data.');
            %            assert(~isempty(h.initial_time), 'The initial_time must be set before inserting the data.');
            %            assert(size(in_data,2)==h.N_elements, 'The number of elements in the probe does not match the channels in the inserted data (2nd dimension).');
            %            assert(size(in_data,3)==h.N_waves, 'The number of waves in the sequence does not match the waves in the inserted data (3th dimension).');
            
            h.data=in_data;
        end
        function h=set.PRF(h,in_PRF)
            if ~isempty(in_PRF)
                assert(numel(in_PRF)==1, 'The PRF must be a scalar in [Hz]');
            end
            h.PRF=in_PRF;
        end
        function h=set.N_frames(h,in_N_frames)
            % FON: Don't like this :(
            %
            % A dependent variable that is used to crop the number of
            % frames. I like to reuse things, but this might be a step too
            % far
            if ~isempty(in_N_frames)
                assert(numel(in_N_frames)==1, 'The N_frames must be a scalar');
                assert(in_N_frames <= size(h.data,4), 'There is not that many frames in the channel_data.data');
                h.data = h.data(:,:,:,1:in_N_frames);
                warning(['You just deleted all frames except frames 1 to ',num2str(in_N_frames),', I hope you meant to!']);
            end
        end
    end
    
    methods
        function value=time(h,n_wave)
            value=(h.initial_time+(0:h.N_samples-1)/h.sampling_frequency).';
            if nargin>1
                value = value + h.sequence(n_wave).delay;
            end
        end
    end
    
    %% get methods
    methods
        function value=get.N_elements(h)
            value=h.probe.N_elements;
        end
        function value=get.N_channels(h)
            value=h.probe.N_elements;
        end
        function value=get.N_samples(h)
            value=size(h.data,1);
        end
        function value=get.N_waves(h)
            value=numel(h.sequence);
        end
        function value=get.N_frames(h)
            value=size(h.data,4);
        end
        function value=get.lambda(h)
            assert(~isempty(h.sound_speed),'You need to set the channel_data.sound_speed')
            assert(~isempty(h.pulse),'You need to set the pulse and the pulse center frequency.')
            value = h.sound_speed/h.pulse.center_frequency;
        end
    end
end