function bf_data = matlab_gpu_beamformer(ch_data, ch_data_time, tx_apodization,...
    rx_apodization, transmit_delay, receive_delay, w0, dim, gpu_id)

[~,N_channels,N_waves,N_frames] = size(ch_data);
N_pixels = size(tx_apodization, 1);

% Allocate RAM
switch dim
    case dimension.none
        bf_data=complex(zeros([N_pixels,N_channels,N_waves,N_frames], 'single'));
    case dimension.receive
        bf_data=complex(zeros([N_pixels,1,N_waves,N_frames], 'single'));
    case dimension.transmit
        bf_data=complex(zeros([N_pixels,N_channels,1,N_frames], 'single'));
    case dimension.both
        bf_data=complex(zeros([N_pixels,1,1,N_frames], 'single'));
end

% Select GPU
gpuDevice(gpu_id);

% transfer data to the GPU
ch_data_time_gpu= gpuArray(ch_data_time);
w0_gpu          = gpuArray(w0);
rx_apod_gpu     = gpuArray(rx_apodization);
tx_apod_gpu     = gpuArray(tx_apodization);
rx_delay_gpu    = gpuArray(receive_delay);
tx_delay_gpu    = gpuArray(transmit_delay);

if N_waves == 1 % Simple trick to avoid unnecessary computations in non-compounded datasets
    apod_gpu  = bsxfun(@times,rx_apod_gpu,  tx_apod_gpu);
    delay_gpu = bsxfun(@plus, rx_delay_gpu, tx_delay_gpu);
    % If IQ data, multiply apod_gpu by a phase correction factor
    if (abs(w0) > eps)
        apod_gpu = exp(1i.*w0_gpu*delay_gpu).*apod_gpu;
    end
end

% frame loop
for n_frame = 1:N_frames

    % transfer channel data to device
    ch_data_gpu = gpuArray(ch_data(:,:,:,n_frame));

    % beamformed data preallocation, needed only if looping along the waves dimension
    switch (dim)
        case dimension.transmit
            bf_data_gpu = complex(zeros([N_pixels, N_channels], 'single', 'gpuArray'));
        case dimension.both
            bf_data_gpu = complex(zeros([N_pixels, 1, N_waves], 'single', 'gpuArray'));
    end

    % wave loop
    for n_wave=1:N_waves

        if (N_waves > 1)
            apod_gpu  = bsxfun(@times,rx_apod_gpu,tx_apod_gpu(:,n_wave));
            delay_gpu = bsxfun(@plus, rx_delay_gpu, tx_delay_gpu(:,n_wave));

            % If IQ data, multiply apod_gpu by a phase correction factor
            if (abs(w0) > eps)
                apod_gpu = exp(1i.*w0_gpu*delay_gpu).*apod_gpu;
            end
        end

        % Preallocate memory for pre-beamformed data
        pre_bf_data = complex(zeros([N_pixels, N_channels], 'single', 'gpuArray'));

        % channel loop
        for n_rx=1:N_channels
            pre_bf_data(:,n_rx) = interp1(ch_data_time_gpu, ch_data_gpu(:,n_rx, n_wave, :), delay_gpu(:,n_rx), 'linear',0);
        end % end channel loop

        % apply apodization and phase correction
        pre_bf_data = apod_gpu .* pre_bf_data;

        switch (dim)
            case dimension.none
                bf_data(:,n_rx,n_wave,n_frame) = gather(pre_bf_data);
            case dimension.receive
                bf_data(:,1,n_wave,n_frame) = gather(sum(pre_bf_data, 2));
            case dimension.transmit
                bf_data_gpu = bf_data_gpu + pre_bf_data;
            case dimension.both
                bf_data_gpu(:,1,n_wave) = sum(pre_bf_data, 2);
        end
    end % end wave loop

    switch (dim)
        case dimension.transmit
            bf_data(:,:,1,n_frame) = gather(sum(bf_data_gpu, 3));
        case dimension.both
            bf_data(:,1,1,n_frame) = gather(sum(bf_data_gpu, 3));
    end
end % end frame loop
end

