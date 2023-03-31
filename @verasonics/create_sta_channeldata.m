function channel_data = create_sta_channeldata(h)
%%%%
%    Save to channeldata for Synthetic Transmit Aperture imaging

%% Create channel_data object and set some parameters
channel_data = uff.channel_data();
channel_data.sampling_frequency = h.Fs;
channel_data.sound_speed = h.c0;
channel_data.initial_time = 0;
channel_data.probe=create_probe_object(h);


%% SEQUENCE GENERATION
N=length(h.TX);                      % number of waves
for n=1:N
    seq(n)=uff.wave();
    seq(n).probe=channel_data.probe;
    seq(n).source.xyz=[channel_data.probe.x(n) channel_data.probe.y(n) channel_data.probe.z(n)];

    seq(n).sound_speed=channel_data.sound_speed;
end
channel_data.sequence = seq;

% Create Pulse
channel_data.pulse = uff.pulse();
channel_data.pulse.center_frequency = h.f0;

%% Convert channel data from Verasonics format to USTB format
data = int16(zeros(h.Receive(1).endSample, channel_data.N_elements, channel_data.N_waves, h.Resource.RcvBuffer(1).numFrames));

offset_distance = calc_lens_corr_and_center_of_pulse_in_m(h); % Get offset distance for t0 compensation
%Assuming the initial time is the same for all waves
channel_data.initial_time = 2*h.Receive(1).startDepth*h.lambda/channel_data.sound_speed;
plot_delayed_signal=0;
tools.workbar()
n=1;
frame_idx = 0;
for n_frame = h.frame_order
    frame_idx = frame_idx + 1;
    for n_tx = 1:length(channel_data.sequence)
        tools.workbar((n_tx+(frame_idx-1)*length(channel_data.sequence))/(length(h.frame_order)*length(channel_data.sequence)),sprintf('Reading %d frame(s) of STAI data from Verasonics.',length(h.frame_order)),'Reading STAI data from Verasonics.')
        
        % time interval between t0 and acquistion start and compensate for
        % center of puse + lens correction
        channel_data.sequence(n_tx).delay = -(offset_distance-channel_data.probe.r(n_tx))/channel_data.sound_speed;
        
        % read data
        data(:,:,n_tx,frame_idx) = h.RcvData{1}(h.Receive(n).startSample:h.Receive(n).endSample,h.Trans.Connector,n_frame);
        
        % to check delay calculation
        if plot_delayed_signal
            % Point to beamform to (where the scatterer is in the simulation)
            x = 0;
            y = 0;
            z = 20e-3;
            
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
            
            figure(101); hold off;
            pcolor(1:channel_data.probe.N_elements,time,real(data(:,:,n_tx,n_frame))); shading flat; colormap gray; colorbar; hold on;
            plot(1:channel_data.probe.N_elements,delay,'r');
            title(n_tx);
            ylim([0.9*min(delay) 1.1*max(delay)]);
            pause;
        end
        n=n+1;
    end
end
channel_data.data = data;

end
