classdef simplified_delay_multiply_and_sum < postprocess
    %DELAY MULTIPLY AND SUM  Matlab implementation of Delay Multiply And Sum
    %
    %   Matlab implementation of Delay Multiply And Sum as described in 
    %   the paper:
    %   
    %   Jeon, S., Park, E. Y., Choi, W., Managuli, R., jong Lee, K., & Kim,
    %   C. (2019). Real-time delay-multiply-and-sum beamforming with 
    %   coherence factor for in vivo clinical photoacoustic imaging of 
    %   humans. Photoacoustics, 15, 100136.
    %
    %   The implementation is a simplified version of delay-multiply-and-sum
    %
    %   implementers: Sufayan Ikabal Mulani <sufayanm@ifi.uio.no> and Ole Marius Hoel Rindal <olemarius@olemarius.net>
    %
    %   $Last updated: 2023/11/08$
    
    %% constructor
    methods (Access = public)
        function h=simplified_delay_multiply_and_sum()
            h.name='Simplified Delay Multiply and Sum';
            h.reference= 'Jeon, S., Park, E. Y., Choi, W., Managuli, R., jong Lee, K., & Kim, C. (2019). Real-time delay-multiply-and-sum beamforming with coherence factor for in vivo clinical photoacoustic imaging of humans. Photoacoustics, 15, 100136.';
            h.implemented_by={'Sufayan Ikabal Mulani <sufayanm@ifi.uio.no>', 'Ole Marius Hoel Rindal <olemarius@olemarius.net>'};
            h.version='';
        end
    end
    
    %% Additional properties
    properties
        dimension
        channel_data                                  % UFF.CHANNEL_DATA class
        filter_freqs % optional: four increasing numbers specifying the passband and stopband edges of the bandpass filter
    end
    
    methods
        function output=go(h)
            % check if we can skip calculation
            if h.check_hash()
                output = h.output; 
                return;
            end            

            assert(~isempty(h.input),'We need some data. Please add some beamformed_data.');
            assert(~isempty(h.channel_data),'We need the channel_data object for some paramters. Please add it.');
                       
            % declare output structure
            h.output=uff.beamformed_data(h.input); % ToDo: instead we should copy everything but the data
            
            switch h.dimension
                case dimension.both
                    str = ['You are trying to run the delay multiply and sum beamformer on both dimensions simultaneously. ',...
                        'This is to my knowledge not been done in the litterature before, and might not make sense. ',...
                        'I also takes forever...'];
                    warning(str);

                    % auxiliary data
                    aux_data=zeros(h.input.N_pixels,1,1,h.input.N_frames);
                    for n_frame = 1:h.input.N_frames
                        data_cube = reshape(h.input.data(:,:,:,n_frame),h.input(1).scan.N_z_axis,h.input(1).scan.N_x_axis,h.input.N_channels*h.input.N_waves);
                        image = delay_multiply_and_sum_implementation(h,real(data_cube),['1/1']);
                        aux_data(:,1,1,n_frame) = image(:);
                    end
                    h.output.data = aux_data;
                case dimension.transmit
                    auxiliary data
                    aux_data=zeros(h.input.N_pixels,h.input.N_channels,1,h.input.N_frames);
                    for n_frame = 1:h.input.N_frames
                        for n_channel = 1:h.input.N_channels
                            
                            data_cube = reshape(h.input.data(:,n_channel,:,n_frame),h.input(1).scan.N_z_axis,h.input(1).scan.N_x_axis,h.input.N_waves);
                            image = simplified_delay_multiply_and_sum_implementation(h,real(data_cube),[num2str(n_channel),'/',num2str(h.input.N_channels)]);
                            aux_data(:,n_channel,:,n_frame) = image(:);
                        end
                    end
                    h.output.data = aux_data;
                case dimension.receive
                    % auxiliary data
                    aux_data=zeros(h.input.N_pixels,1,h.input.N_waves,h.input.N_frames);
                    for n_frame = 1:h.input.N_frames
                        for n_wave = 1:h.input.N_waves
                            data_cube = reshape(h.input.data(:,:,n_wave,n_frame),h.input(1).scan.N_z_axis,h.input(1).scan.N_x_axis,h.input.N_channels);
                            image = simplified_delay_multiply_and_sum_implementation(h,real(data_cube),[num2str(n_wave),'/',num2str(h.input.N_waves)]);
                            aux_data(:,1,n_wave,n_frame) = image(:);
                        end
                    end
                    h.output.data = aux_data;
                otherwise
                    error('Unknown dimension mode; check HELP dimension');
            end
            
            % pass reference
            output = h.output;
            
            % update hash
            h.save_hash();

        end
        
        function y_dmas_signed_img = simplified_delay_multiply_and_sum_implementation(h,data_cube,progress)
            assert(isreal(data_cube),'Expected real data in data_cube for DMAS');
            
            % Design Bandpass-filter
            h.input(1).calculate_sampling_frequency(h.channel_data.sound_speed);
            fs = h.input(1).sampling_frequency;
            %f0 = h.channel_data.pulse.center_frequency;        
            
            %%
            if isempty(h.filter_freqs)
                [f0, bw] = tools.estimate_frequency(2*h.input(1).scan.z_axis/h.channel_data.sound_speed,data_cube);
                f_start = 1.5*f0; 
                f_stop = 2.5*f0 ;
                f_transition = f0/4;

                F = [f_start f_start+f_transition f_stop f_stop+f_transition];
            else
                F=h.filter_freqs;
            end
            
            %Check that the pixel sampling frequency is high enogh to
            %support 2 times the center frequency, aaand the later hilbert
            %transform. Added a extra transition for the Hilbert transform
            assert(fs/2>(F(end)),['We need ',num2str(ceil((F(end))*2/fs)),...
                ' times more samples in the z-direction in the image to be able to do DMAS with filtering around 2 times the center frequency. And for the Hilbert transform']);
            %%
            
            y_dmas_signed = zeros(size(data_cube,1),size(data_cube,2),'single');
            
            tools.workbar(0,sprintf('%s %s (%s)',h.name,h.version,progress),'DMAS');
            for z = 1:size(data_cube,1)
                tools.workbar(z/size(data_cube,1),sprintf('%s %s (%s)',h.name,h.version,progress),'DMAS');
                for x = 1:size(data_cube,2)
                    root_term =  sum(sign(data_cube(z, x, :)).*sqrt(abs(data_cube(z, x, :)))) ;
                    abs_term = sum(abs(data_cube(z,x,:))) ;

                    y_dmas_signed(z,x) = (root_term^2 - abs_term)/2 ;
                end
            end
            tools.workbar(1,sprintf('%s %s (%s)',h.name,h.version,progress),'DMAS');
            
            orig_plot = (abs(fftshift(fft(sum(data_cube,3)))));
            clear data_cube %Save some precious memory
            
            %% filter specification
            
            A=[0 1 0];                % band type: 0='stop', 1='pass'
            dev=[1e-3 1e-3 1e-3];     % ripple/attenuation spec
            [M,Wn,beta,typ]= kaiserord(F,A,dev,fs);  % window parameters
            b=fir1(M,Wn,typ,kaiser(M+1,beta),'noscale'); % filter design
            
            % filtering
            filt_delay=round((length(b)-1)/2);
            filtered_p=filter(b,1,[y_dmas_signed; zeros(filt_delay,size(y_dmas_signed,2),size(y_dmas_signed,3),size(y_dmas_signed,4))],[],1);
            
            % correcting the delay
            filtered_p=filtered_p((filt_delay+1):end,:,:);
            filtered_y_dmas_signed = filtered_p;
            
            warning('If the result looks funky, you might need to tune the filter paramters of DMAS using the filter_freqs property. Use the plot to check that everything is OK.')
            plot_filtering = false;
            if plot_filtering %Plot to check the filtering
                %%
                [freq_resp,f_ax]=freqz(b);
                
                freq_axis = linspace(-fs/2,fs/2,length(filtered_y_dmas_signed));
                ax = fs/2*(2*[0:size(filtered_y_dmas_signed,1)-1]/size(filtered_y_dmas_signed,1)-1);
                figure(100);clf;
                subplot(411)
                plot(freq_axis*10^-6,orig_plot);
                subplot(412)
                F_temp = (abs(fftshift(fft(sum(y_dmas_signed,3)))));
                plot(ax(floor(end/2):end)*10^-6,F_temp(floor(end/2):end,:));hold on
                axis tight
                subplot(413)
                plot(f_ax,db(abs(freq_resp)));
                axis tight
                subplot(414)
                plot(freq_axis*10^-6,db(abs(fftshift(fft(filtered_y_dmas_signed)))));
                axis tight
            end
            
            y_dmas_signed_img = hilbert(filtered_y_dmas_signed);
        end
        
    end
    
    %% set methods
    methods
        % TODO: why defining channel_data if we already have it in input? 
        function h=set.channel_data(h,in_channel_data) 
            assert(isa(in_channel_data,'uff.channel_data'), 'The input is not a UFF.CHANNEL_DATA class. Check HELP UFF.CHANNEL_DATA.');
            h.channel_data=in_channel_data;
        end
    end
end
