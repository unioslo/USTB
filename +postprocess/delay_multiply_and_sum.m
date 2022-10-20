classdef delay_multiply_and_sum < postprocess
    %DELAY MULTIPLY AND SUM  Matlab implementation of Delay Multiply And Sum
    %
    %    Matlab implementation of Delay Multiply And Sum as described in 
    %    the paper:
    %   
    %   Matrone, G., Savoia, A. S., & Magenes, G. (2015). The Delay 
    %   Multiply and Sum Beamforming Algorithm in Ultrasound B-Mode Medical
    %   Imaging, 34(4), 940?949.
    %
    %   The implementation computes coherence either on transmit, receive, 
    %   or both. However, doing "both" takes a looong time, and might not
    %   make sense. Haven't seen it published :)
    %
    %   implementers: Ole Marius Hoel Rindal <olemarius@olemarius.net>
    %
    %   $Last updated: 2017/09/10$
    
    %% constructor
    methods (Access = public)
        function h=delay_multiply_and_sum()
            h.name='Delay Multiply and Sum';
            h.reference= 'Matrone, G., Savoia, A. S., & Magenes, G. (2015). The Delay Multiply and Sum Beamforming Algorithm in Ultrasound B-Mode Medical Imaging, 34(4), 940?949.';
            h.implemented_by={'Ole Marius Hoel Rindal <olemarius@olemarius.net>'};
            h.version='v1.0.3';
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
            
            % check if we have information about apodization
            rx_apodization=ones([h.input(1).N_pixels,h.input.N_channels]);
            tx_apodization=ones([h.input(1).N_pixels,h.input.N_waves]);
            if ~isempty(h.transmit_apodization)&~isempty(h.receive_apodization)&~isempty(h.channel_data.probe)
                % receive
                if h.input.N_channels > 1
                    h.receive_apodization.focus=h.input(1).scan;
                    h.receive_apodization.probe=h.channel_data.probe;
                    rx_apodization=h.receive_apodization.data();
                end
                
                % transmit
                if h.input.N_waves > 1
                    h.transmit_apodization.sequence = h.channel_data.sequence;
                    h.transmit_apodization.focus=h.input(1).scan;
                    h.transmit_apodization.probe=h.channel_data.probe;
                    tx_apodization=h.transmit_apodization.data();
                end
            else
                warning('Missing probe and apodization data; full aperture is assumed.');
            end
            
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
                        apod_matrix = zeros(size(tx_apodization,1),h.input.N_waves*h.input.N_channels);
                        for i = 1:h.input.N_waves
                            apod_matrix(:,1+(i-1)*h.input.N_channels:h.input.N_channels*i) = tx_apodization(:,i).*rx_apodization;
                        end
                        apod_matrix = reshape(apod_matrix,h.input(1).scan.N_z_axis,h.input(1).scan.N_x_axis,h.input.N_waves*h.input.N_channels);
                        %
                        % Apodization matrix indicating active elements
                        data_cube = reshape(h.input.data(:,:,:,n_frame),h.input(1).scan.N_z_axis,h.input(1).scan.N_x_axis,h.input.N_channels*h.input.N_waves);
                        image = delay_multiply_and_sum_implementation(h,real(data_cube),apod_matrix,['1/1']);
                        aux_data(:,1,1,n_frame) = image(:);
                    end
                    h.output.data = aux_data;
                case dimension.transmit
                    % auxiliary data
                    aux_data=zeros(h.input.N_pixels,h.input.N_channels,1,h.input.N_frames);
                    for n_frame = 1:h.input.N_frames
                        for n_channel = 1:h.input.N_channels
                            % Apodization matrix indicating active elements
                            apod_matrix = reshape(bsxfun(@times,tx_apodization,rx_apodization(n_channel)),h.input(1).scan.N_z_axis,h.input(1).scan.N_x_axis,h.input.N_waves);
                            data_cube = reshape(h.input.data(:,n_channel,:,n_frame),h.input(1).scan.N_z_axis,h.input(1).scan.N_x_axis,h.input.N_waves);
                            image = delay_multiply_and_sum_implementation(h,real(data_cube),apod_matrix,[num2str(n_channel),'/',num2str(h.input.N_channels)]);
                            aux_data(:,n_channel,:,n_frame) = image(:);
                        end
                    end
                    h.output.data = aux_data;
                case dimension.receive
                    % auxiliary data
                    aux_data=zeros(h.input.N_pixels,1,h.input.N_waves,h.input.N_frames);
                    for n_frame = 1:h.input.N_frames
                        for n_wave = 1:h.input.N_waves
                            % Apodization matrix indicating active elements
                            apod_matrix = reshape(bsxfun(@times,tx_apodization(:,n_wave),rx_apodization),h.input(1).scan.N_z_axis,h.input(1).scan.N_x_axis,h.input.N_channels);
                            data_cube = reshape(h.input.data(:,:,n_wave,n_frame),h.input(1).scan.N_z_axis,h.input(1).scan.N_x_axis,h.input.N_channels);
                            %A hack to set non active elements to zero for the
                            %alpinion scanner FI who only use 64 active
                            %elements
                            if ~isempty(h.channel_data.N_active_elements) && sum(h.channel_data.N_active_elements ~= h.channel_data.N_elements)
                                apod_matrix(abs(data_cube)<eps) = 0;
                            end
                            image = delay_multiply_and_sum_implementation(h,real(data_cube),apod_matrix,[num2str(n_wave),'/',num2str(h.input.N_waves)]);
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
        
        function y_dmas_signed_img = delay_multiply_and_sum_implementation(h,data_cube,apod_matrix,progress)
            assert(isreal(data_cube),'Expected real data in data_cube for DMAS');
            
            
            % Design Bandpass-filter
            h.input(1).calculate_sampling_frequency(h.channel_data.sound_speed);
            fs = h.input(1).sampling_frequency;
            %f0 = h.channel_data.pulse.center_frequency;        
            
            %%
            if isempty(h.filter_freqs)
                [f0, bw] = tools.estimate_frequency(2*h.input(1).scan.z_axis/h.channel_data.sound_speed,data_cube);
                f_start = 1.5*f0; 
                f_stop = 2.5*f0
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
                    %Find idx with valid data according to expanding aperture
                    idx = find(logical(squeeze(apod_matrix(z,x,:))));
                    count = 0;
                    for i = idx(1:end-1)'
                        count = count + 1;
                        j_idx = idx(1+count:end)'; %Get all j indices                 
                        y_dmas_signed(z,x) = y_dmas_signed(z,x) + sum(sign(data_cube(z,x,i).*data_cube(z,x,j_idx)).*sqrt(abs(data_cube(z,x,i).*data_cube(z,x,j_idx))));
                    end                    
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



