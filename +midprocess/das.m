classdef das < midprocess
    %DAS   Implementation of USTB DAS general beamformer
    %
    %   authors:    Alfonso Rodriguez-Molares (alfonso.r.molares@ntnu.no)
    %               Ole Marius Hoel Rindal <olemarius@olemarius.net>
    %               Stefano Fiorentini <stefano.fiorentini@ntnu.no>
    %
    %   $Last updated: 2017/11/14$
    
    %% Additional properties
    properties
        dimension = dimension.receive;      % dimension enumeration class that specifies whether the process will run only on transmit, receive, both, or none.
        code = code.mex;                    % code enumeration class that specifies the code to be run (code.matlab, code.mex)
        % spherical transmit delay model enumeration for deciding model when the source is in front of the transducer
        spherical_transmit_delay_model = spherical_transmit_delay_model.hybrid;  
        pw_margin = 1/1000;                 % The margin of the area around focus in m for the spherical_transmit_delay_model.hybrid
        transmit_delay                      % Variable returning the calculated tx part of the receive delay so that it can be plotted
        receive_delay                       % Variable returning the calculated rx part of the receive delay so that it can be plotted
    end
    
    %% constructor
    methods (Access = public)
        function h=das()
            h.name='USTB DAS General Beamformer';
            h.reference= 'www.ustb.no';
            h.implemented_by={'Stefano Fiorentini <stefano.fiorentini@ntnu.no>', 'Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>','Ole Marius Hoel Rindal <olemarius@olemarius.net>'};
            h.version='v1.0.14';
        end
    end
    
    %% go method
    methods
        function beamformed_data=go(h)
            
            % check if we can skip calculation
            if h.check_hash()
                beamformed_data= h.beamformed_data;
                return;
            end
            
            % short names
            N_pixels = h.scan.N_pixels;
            N_channels = h.channel_data.N_channels;
            N_waves = h.channel_data.N_waves;
            N_frames = h.channel_data.N_frames;
            
            % modulation frequency
            w0=2*pi*h.channel_data.modulation_frequency;
            
            % constants
            sampling_frequency=single(h.channel_data.sampling_frequency);
            initial_time=single(h.channel_data.initial_time);
            modulation_frequency=single(h.channel_data.modulation_frequency);
            
            % calculate transmit apodization according to 10.1109/TUFFC.2015.007183
            h.transmit_apodization.sequence=h.channel_data.sequence;
            h.transmit_apodization.focus=h.scan;
            tx_apodization=single(h.transmit_apodization.data);
            
            % calculate receive apodization
            h.receive_apodization.probe=h.channel_data.probe;
            h.receive_apodization.focus=h.scan;
            rx_apodization=single(h.receive_apodization.data);
            
            % calculate receive delay
            xm=bsxfun(@minus,h.channel_data.probe.x.',h.scan.x);
            ym=bsxfun(@minus,h.channel_data.probe.y.',h.scan.y);
            zm=bsxfun(@minus,h.channel_data.probe.z.',h.scan.z);
            receive_delay=single(sqrt(xm.^2+ym.^2+zm.^2)/h.channel_data.sound_speed);
            h.receive_delay = receive_delay;
            
            % calculate transmit delay
            transmit_delay=zeros(N_pixels,N_waves);
            for n_wave=1:numel(h.channel_data.sequence)
                switch(h.channel_data.sequence(n_wave).wavefront)
                    % point source
                    case uff.wavefront.spherical
                        % check if the point source is at infinity -> for backcompatibility of examples
                        if isinf(h.channel_data.sequence(n_wave).source.distance)
                            transmit_delay(:,n_wave)=h.scan.z*cos(h.channel_data.sequence(n_wave).source.azimuth)*cos(h.channel_data.sequence(n_wave).source.elevation)+h.scan.x*sin(h.channel_data.sequence(n_wave).source.azimuth)*cos(h.channel_data.sequence(n_wave).source.elevation)+h.scan.y*sin(h.channel_data.sequence(n_wave).source.elevation);
                        else
                            % distance between source and elements
                            transmit_delay(:,n_wave)=(-1).^(h.scan.z<h.channel_data.sequence(n_wave).source.z).*sqrt((h.channel_data.sequence(n_wave).source.x-h.scan.x).^2+(h.channel_data.sequence(n_wave).source.y-h.scan.y).^2+(h.channel_data.sequence(n_wave).source.z-h.scan.z).^2);
                            
                            % add distance from source to origin
                            if (h.channel_data.sequence(n_wave).source.z<-1e-3) %Diverging Wave (DW) transmit
                                transmit_delay(:,n_wave)=transmit_delay(:,n_wave)-abs(h.channel_data.sequence(n_wave).source.distance);
                            else % if virtual source in front of transducer
                                switch h.spherical_transmit_delay_model
                                    % Please see the reference below for a documentation and definition of these three models and the differences.
                                    % Rindal, O. M. H., Rodriguez-Molares, A., & Austeng, A. (2018). A simple , artifact-free , virtual source model. 
                                    % IEEE International Ultrasonics Symposium, IUS, 1–4.        
                                    case spherical_transmit_delay_model.spherical
                                        % Use conventional virtual source model
                                        transmit_delay(:,n_wave)=transmit_delay(:,n_wave)+h.channel_data.sequence(n_wave).source.distance;
                                    case spherical_transmit_delay_model.unified
                                        % Transmit delay model introduced in  Nguyen, N. Q., & Prager, R. W. (2016). High-Resolution Ultrasound 
                                        % Imaging With Unified Pixel-Based Beamforming. IEEE Trans. Med. Imaging, 35(1), 98-108.
                                        if n_wave == 1
                                            % Get an apodization mask to identify the four different regions of the transmit wave field
                                            mask_apod = uff.apodization();
                                            mask_apod.window = uff.window.boxcar;
                                            mask_apod.sequence = h.channel_data.sequence;
                                            mask_apod.minimum_aperture = [0 0];
                                            mask_apod.focus = h.scan;
                                            mask_apod.probe = h.channel_data.probe;
                                            if isa(h.scan,'uff.sector_scan')
                                                mask_apod.f_number = 4; %This should be set according to the actually transmitted f number
                                                mask_all_waves = reshape(mask_apod.data,h.scan.N_depth_axis,h.scan.N_azimuth_axis,numel(h.channel_data.sequence));
                                            elseif isa(h.scan,'uff.linear_scan')
                                                mask_apod.f_number = 2; %This should be set according to the actually transmitted f number
                                                mask_all_waves = reshape(mask_apod.data,h.scan.N_z_axis,h.scan.N_x_axis,numel(h.channel_data.sequence));
                                            else
                                                error('Only linear scan and sector scan in 2D is supported for the unified spherical transmit delay model.');
                                            end
                                        end
                                        transmit_delay(:,n_wave) = tools.calculate_unified_delay_model(transmit_delay(:,n_wave),logical(mask_all_waves(:,:,n_wave)),...
                                                                            h.scan,h.channel_data.sequence(n_wave).source);
                                    case spherical_transmit_delay_model.hybrid
                                        % Our hybrid model assume that the transmit wave propagates as a plane-wave in a small region h.pw_margin around the transmit focus
                                        % Calculate the "plane wave" in the transmit direction
                                        if isa(h.scan,'uff.linear_scan')
                                            plane_delay = (-1).^(h.scan.z<h.channel_data.sequence(n_wave).source.z).*sqrt((h.channel_data.sequence(n_wave).source.z-h.scan.z).^2) + h.channel_data.sequence(n_wave).source.distance;
                                        elseif isa(h.scan,'uff.sector_scan')
                                            plane_delay = h.scan.z*cos(h.channel_data.sequence(n_wave).source.azimuth)*cos(h.channel_data.sequence(n_wave).source.elevation)+h.scan.x*sin(h.channel_data.sequence(n_wave).source.azimuth)*cos(h.channel_data.sequence(n_wave).source.elevation)+h.scan.y*sin(h.channel_data.sequence(n_wave).source.elevation);
                                        else
                                            error('Only linear scan and sector scan in 2D is supported for the hybrid spherical transmit delay model.');
                                        end
                                        
                                        % Find region in front of and after the focus with margins given by h.margin_in_m
                                        z_mask = logical(h.scan.z < (h.channel_data.sequence(n_wave).source.z + h.pw_margin)) & logical(h.scan.z > (h.channel_data.sequence(n_wave).source.z - h.pw_margin));
                                        
                                        % Replace the region in the virtual source delay with the plane delay in
                                        % the region indicated by the mask
                                        transmit_delay_temp = transmit_delay(:,n_wave)+h.channel_data.sequence(n_wave).source.distance;
                                        transmit_delay_temp(z_mask) = plane_delay(z_mask);
                                        transmit_delay(:,n_wave) = transmit_delay_temp;
                                end
                            end  
                        end
                    % plane wave
                    case uff.wavefront.plane
                        transmit_delay(:,n_wave)=h.scan.z*cos(h.channel_data.sequence(n_wave).source.azimuth)*cos(h.channel_data.sequence(n_wave).source.elevation)+h.scan.x*sin(h.channel_data.sequence(n_wave).source.azimuth)*cos(h.channel_data.sequence(n_wave).source.elevation)+h.scan.y*sin(h.channel_data.sequence(n_wave).source.elevation);
                        
                    % photoacoustic wave
                    case uff.wavefront.photoacoustic
                        transmit_delay(:,n_wave)=zeros(N_pixels,1);
                        
                    otherwise
                        error('Unknown wavefront. Check available options at uff.wavefront');
                end
                % convert to seconds and include wave delay
                transmit_delay(:,n_wave) = transmit_delay(:,n_wave)./h.channel_data.sequence(n_wave).sound_speed - h.channel_data.sequence(n_wave).delay;
            end
            % convert to single
            transmit_delay = single(transmit_delay);
            
            % Saving receive tx and rx delay to a public parameter to be able to plot it
            h.transmit_delay = transmit_delay;
            
            
            % precalculating hilbert (if needed)
            tools.check_memory(prod([size(h.channel_data.data) 8]));
            data=single(h.channel_data.data);
            if ~(abs(w0)>eps)
                data=single(reshape(hilbert(single(h.channel_data.data(:,:))),size(h.channel_data.data)));
            end
            
            % create beamformed data class
            h.beamformed_data=uff.beamformed_data();
            h.beamformed_data.scan=h.scan;
            
            % auxiliary data
            switch h.dimension
                case dimension.none
                    tools.check_memory(prod([N_pixels N_channels N_waves N_frames 8]));
                    aux_data=zeros(N_pixels,N_channels,N_waves,N_frames);
                case dimension.receive
                    tools.check_memory(prod([N_pixels N_waves N_frames 8]));
                    aux_data=zeros(N_pixels,1,N_waves,N_frames);
                case dimension.transmit
                    tools.check_memory(prod([N_pixels N_channels N_frames 8]));
                    aux_data=zeros(N_pixels,N_channels,1,N_frames);
                case dimension.both
                    tools.check_memory(prod([N_pixels N_frames 8]));
                    aux_data=zeros(N_pixels,1,1,N_frames);
            end
            
            % delay & sum
            if any(data(:)>0) % only process if any data > 0
                
                switch h.code
                    %% MEX
                    case code.mex
                        aux_data=mex.das_c(data,...
                                           sampling_frequency,...
                                           initial_time,...
                                           tx_apodization,...
                                           rx_apodization,...
                                           transmit_delay,...
                                           receive_delay,...
                                           modulation_frequency,...
                                           int32(h.dimension));
                    
                    case code.mexFast
                        aux_data=mex.dasFast_c(data,...
                                           sampling_frequency,...
                                           initial_time,...
                                           tx_apodization,...
                                           rx_apodization,...
                                           transmit_delay,...
                                           receive_delay,...
                                           modulation_frequency,...
                                           int32(h.dimension));
                    
                    %% MATLAB
                    case code.matlab
                        % workbar
                        tools.workbar();
                        N=N_waves*N_channels;
                        
                        % transmit loop
                        for n_wave=1:N_waves
                            if any(tx_apodization(:,n_wave))
                                % receive loop
                                for n_rx=1:N_channels
                                    if any(rx_apodization(:,n_rx))
                                        
                                        % progress bar
                                        n=(n_wave-1)*N_channels+n_rx;
                                        if mod(n,round(N/100))==0
                                            tools.workbar(n/N,sprintf('%s (%s)',h.name,h.version),'USTB MATLAB');
                                        end
                                        
                                        apodization= rx_apodization(:,n_rx).*tx_apodization(:,n_wave);
                                        delay= receive_delay(:,n_rx) + transmit_delay(:,n_wave);
                                        
                                        % beamformed signal
                                        temp = bsxfun(@times,apodization,interp1(h.channel_data.time,data(:,n_rx,n_wave,:),delay,'linear',0));
                                        
                                        % apply phase correction factor to IQ data
                                        if(abs(w0)>eps)
                                            temp = bsxfun(@times,exp(1i.*w0*delay),temp);
                                        end
                                        
                                        % set into auxiliary data
                                        switch h.dimension
                                            case dimension.none %#ok<*PROP>
                                                aux_data(:,n_rx,n_wave,:)=temp;
                                            case dimension.receive
                                                aux_data(:,1,n_wave,:)=aux_data(:,1,n_wave,:)+temp;
                                            case dimension.transmit
                                                aux_data(:,n_rx,1,:)=aux_data(:,n_rx,1,:)+temp;
                                            case dimension.both
                                                aux_data(:,1,1,:)=aux_data(:,1,1,:)+temp;
                                        end
                                    end
                                end
                            end
                        end
                        
                    %% MATLAB GPU FRAMELOOP
                    case code.matlab_gpu_frameloop
                        
                        % clear GPU memory and show basic info
                        gpu_info=gpuDevice();
                        fprintf(1, '=========== DAS GPU FRAMELOOP ===========\n');
                        fprintf(1, 'Selected GPU: %s\n', gpu_info.Name);
                        fprintf(1, 'Available memory: %0.2f MB\n', gpu_info.AvailableMemory*1e-6);
                        
                        % transfer data to the GPU
                        time_gpu        = gpuArray(single(h.channel_data.time));
                        w0_gpu          = gpuArray(single(w0));
                        rx_apod_gpu     = gpuArray(rx_apodization);
                        tx_apod_gpu     = gpuArray(tx_apodization);
                        rx_delay_gpu    = gpuArray(receive_delay);
                        tx_delay_gpu    = gpuArray(transmit_delay);
                        
                        if N_waves == 1 % Simple trick to avoid unnecessary computations in non-compounded datasets
                            apod_gpu  = bsxfun(@times,rx_apod_gpu,  tx_apod_gpu);
                            delay_gpu = bsxfun(@plus, rx_delay_gpu, tx_delay_gpu);
                            % If IQ data, multiply apod_gpu by a phase correction factor
                            if (abs(w0_gpu) > eps)
                                apod_gpu = exp(1i.*w0_gpu*delay_gpu).*apod_gpu;
                            end
                        end
                        
                        % workbar
                        tools.workbar();
                        
                        % frame loop
                        for n_frame = colon(1, N_frames)
                            % update workbar
                            tools.workbar(n_frame/N_frames, sprintf('%s (%s)',h.name, h.version),'USTB');
                            
                            % transfer channel data to device
                            ch_data = gpuArray(data(:,:,:,n_frame));
                            
                            % beamformed data preallocation, needed only if looping along the waves dimension
                            switch (h.dimension)
                                case dimension.transmit
                                    bf_data = complex(zeros([N_pixels, N_channels], 'single', 'gpuArray'));
                                case dimension.both
                                    bf_data = complex(zeros([N_pixels, 1, N_waves], 'single', 'gpuArray'));
                            end
                            
                            % wave loop
                            for n_wave=1:N_waves
                                
                                if (N_waves > 1)
                                    apod_gpu  = bsxfun(@times,rx_apod_gpu,tx_apod_gpu(:,n_wave));
                                    delay_gpu = bsxfun(@plus, rx_delay_gpu, tx_delay_gpu(:,n_wave));
                                    % If IQ data, multiply apod_gpu by a phase correction factor
                                    if (abs(w0_gpu) > eps)
                                        apod_gpu = exp(1i.*w0_gpu*delay_gpu).*apod_gpu;
                                    end
                                end
                                
                                % Preallocate memory for pre-beamformed data
                                pre_bf_data = complex(zeros([N_pixels, N_channels], 'single', 'gpuArray'));
                                
                                % channel loop
                                for n_rx=1:N_channels
                                    pre_bf_data(:,n_rx) = interp1(time_gpu, ch_data(:,n_rx, n_wave, :), delay_gpu(:,n_rx), 'linear',0);
                                end % end channel loop
                                
                                % apply apodization and phase correction
                                pre_bf_data = apod_gpu .* pre_bf_data;
                                
                                switch (h.dimension)
                                    case dimension.none
                                        aux_data(:,n_rx,n_wave,n_frame) = gather(pre_bf_data);
                                    case dimension.receive
                                        aux_data(:,1,n_wave,n_frame) = gather(sum(pre_bf_data, 2));
                                    case dimension.transmit
                                        bf_data = bf_data + pre_bf_data;
                                    case dimension.both
                                        bf_data(:,1,n_wave) = sum(pre_bf_data, 2);
                                end           
                            end % end wave loop
                            
                            switch (h.dimension)
                                case dimension.transmit
                                    aux_data(:,:,1,n_frame) = gather(sum(bf_data, 3));
                                case dimension.both
                                    aux_data(:,1,1,n_frame) = gather(sum(bf_data, 3));
                            end
                        end % end frame loop
                        
                    otherwise
                        error('Unknown code implementation requested');
                end % end switch
                
                % assign phase according to 2 times the receive propagation distance
                if ( abs(w0) > eps )
                    aux_data=bsxfun(@times,aux_data,exp(-1i*w0*2*h.scan.reference_distance/h.channel_data.sound_speed));
                end
                
                tools.workbar(1);
                
            end % end if
            
            % copy data to object
            h.beamformed_data.data = aux_data;
            
            % pass a reference
            beamformed_data = h.beamformed_data;
            
            % update hash
            h.save_hash();
        end % end go()
    end
end
