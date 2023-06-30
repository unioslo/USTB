function bf_data = matlab_beamformer(ch_data, ch_data_time, tx_apodization,...
                                        rx_apodization, transmit_delay, receive_delay, w0, dim)

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

% transmit loop
for n_wave=1:N_waves
    if any(tx_apodization(:,n_wave))
        % receive loop
        for n_rx=1:N_channels
            if any(rx_apodization(:,n_rx))

                apodization = rx_apodization(:,n_rx).*tx_apodization(:,n_wave);
                delay = receive_delay(:,n_rx) + transmit_delay(:,n_wave);

                % beamformed signal
                temp = bsxfun(@times,apodization,interp1(ch_data_time,ch_data(:,n_rx,n_wave,:),delay,'linear',0));

                % apply phase correction factor to IQ data
                if(abs(w0)>eps)
                    temp = bsxfun(@times,exp(1i.*w0*delay),temp);
                end

                % set into auxiliary data
                switch dim
                    case dimension.none
                        bf_data(:,n_rx,n_wave,:)=temp;
                    case dimension.receive
                        bf_data(:,1,n_wave,:)=bf_data(:,1,n_wave,:)+temp;
                    case dimension.transmit
                        bf_data(:,n_rx,1,:)=bf_data(:,n_rx,1,:)+temp;
                    case dimension.both
                        bf_data(:,1,1,:)=bf_data(:,1,1,:)+temp;
                end
            end
        end
    end
end

