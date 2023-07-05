function channel_data = create_FI_linear_array_channeldata(h)
%%%%
%    Get channel_data object for Focused Imaging with lienar array imaging
%    from the Verasonics scanner
    
%% Create channel_data object and set some parameters
channel_data = uff.channel_data();
channel_data.sampling_frequency = h.Fs;
channel_data.sound_speed = h.c0;
channel_data.probe=create_probe_object(h);

%% Create UFF PULSE
channel_data.pulse = uff.pulse();
channel_data.pulse.center_frequency = h.f0;


%% DEFINE SEQUENCE
N=length(h.TX);                 % number of focused beams
seq=uff.wave();
for n=1:N
    seq(n)=uff.wave();
    seq(n).probe=channel_data.probe;
    seq(n).source.xyz=[h.TX(n).Origin(1)*h.lambda 0 h.TX(n).focus*h.lambda];
    seq(n).sound_speed=channel_data.sound_speed;
    seq(n).apodization.apodization_vector = h.TX(n).Apod;
    seq(n).origin.x = seq(n).source.x;%mean(channel_data.probe.geometry(1:3,h.TX(n).Apod),1);
end
channel_data.sequence = seq;

%% Convert channel data from Verasonics format to USTB format
data = int16(zeros(h.Receive(1).endSample, channel_data.N_elements, channel_data.N_waves, h.Resource.RcvBuffer(1).numFrames));

offset_distance = calc_lens_corr_and_center_of_pulse_in_m(h); % Get offset distance for t0 compensation
%Assuming the initial time is the same for all waves
channel_data.initial_time = 2*h.Receive(1).startDepth*h.lambda/channel_data.sound_speed;
plot_delayed_signal=0;
tools.workbar()
n=1; % idx for Receive
frame_idx = 0;
for n_frame = h.frame_order
    frame_idx = frame_idx + 1;
    for n_tx = 1:length(channel_data.sequence)
        tools.workbar((n_tx+(frame_idx-1)*length(channel_data.sequence))/(length(h.frame_order)*length(channel_data.sequence)),sprintf('Reading %d frame(s) of FI data from Verasonics.',length(h.frame_order)),'Reading FI data from Verasonics.')          
        
        % compute the offset in time from center of probe to
        % center of transmit wave. We do this by finding the
        % mean between the two center transmit delays for a
        % even numbered probe, and the center transmit delay
        % for a odd elemtn probe. We have to calculate the
        % transmit delays ourselves, since the delays in
        % Tx.Delay is cropped to only the active elements.
        trans_delays_in_m = calculate_trans_delays_in_m(h,channel_data,n_tx);
        t0_comp_in_m = mean(trans_delays_in_m(ceil(channel_data.probe.N_elements/2):ceil((channel_data.probe.N_elements+1)/2)));
        
        % time interval between t0 and acquistion start and compensate for
        % center of puse + lens correction
        channel_data.sequence(n_tx).delay = -(offset_distance+t0_comp_in_m)/channel_data.sound_speed;
        % read data
        data(:,:,n_tx,frame_idx) = h.RcvData{1}(h.Receive(n).startSample:h.Receive(n).endSample,h.Trans.Connector,n_frame);
        %save transmit apodization used
        channel_data.sequence(n_tx).apodization.apodization_vector = h.TX(n_tx).Apod;


        if plot_delayed_signal
            if n_tx == length(channel_data.sequence)/2 %if this is the center scan line
                x = channel_data.sequence(n_tx).source.x;
                y = 0;
                z = channel_data.sequence(n_tx).source.z;
                
                TF=(-1).^(z<channel_data.sequence(n_tx).source.z).*sqrt((channel_data.sequence(n_tx).source.x-x).^2+(channel_data.sequence(n_tx).source.y-y).^2+(channel_data.sequence(n_tx).source.z-z).^2);
                % add distance from source to origin
                TF=TF+channel_data.sequence(n_tx).source.distance;
                %compensate for t0
                TF = TF + channel_data.sequence(n_tx).t0_compensation;
                % receive delay
                RF=sqrt((channel_data.probe.x-x).^2+(channel_data.probe.y-y).^2+(channel_data.probe.z-z).^2);
                % total delay
                delay=(RF+TF)/channel_data.sound_speed;
                
                time = (channel_data.initial_time+(0:h.Receive(1).endSample-1)/channel_data.sampling_frequency);
                
                figure(102); hold off;
                pcolor(1:channel_data.probe.N_elements,time,real(data(:,:,n_tx,n_frame))); shading flat; colormap gray; colorbar; hold on;
                plot(1:channel_data.probe.N_elements,delay,'r');
                title(['Scan line ',num2str(n_tx)]);
                ylim([0.9*min(delay) 1.1*max(delay)]);
            end
        end
        n=n+1;
    end
end
channel_data.data = data;
tools.workbar(1)
end