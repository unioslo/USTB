function channel_data = create_cpw_superframe_channeldata(h)
%% Create channel_data object and set some parameters
channel_data = uff.channel_data();
channel_data.sampling_frequency = h.Fs;
channel_data.sound_speed = h.c0;
channel_data.initial_time = 0;
channel_data.probe=create_probe_object(h);

%% SEQUENCE GENERATION

for n=1:length(h.TX)
    seq(n)=uff.wave();
    seq(n).probe=channel_data.probe;
    seq(n).source.azimuth=h.angles(n);
    seq(n).source.distance=Inf;
    seq(n).sound_speed=channel_data.sound_speed;
end
channel_data.sequence = seq;


%% Save Pulse
channel_data.pulse = uff.pulse();
channel_data.pulse.center_frequency =h.f0;

%% Convert channel data from Verasonics format to USTB format
data = int16(zeros(h.Receive(1).endSample, channel_data.N_elements, channel_data.N_waves, h.Resource.RcvBuffer(1).numFrames));

offset_distance = calc_lens_corr_and_center_of_pulse_in_m(h); % Get offset distance for t0 compensation
%Assuming the initial time is the same for all waves
channel_data.initial_time = 2*h.Receive(1).startDepth*h.lambda/channel_data.sound_speed;

tools.workbar()
plot_delayed_signal=0;
frame_number = 1;
for n_frame = 1:h.number_of_superframes
    for n_tx = 1:h.frames_in_superframe
        tools.workbar((n_tx+(n_frame-1)*h.frames_in_superframe)/(h.number_of_superframes*h.frames_in_superframe),sprintf('Reading %d superframe(s) of CPWC data from Verasonics.',length(h.number_of_superframes)),'Reading CPWC data from Verasonics.')          
        
        % Find t_0, when the plane wave "crosses" the center of
        % the probe
        for s=1:length(channel_data.sequence)% loop on sequence of angles
            D = abs(h.Trans.ElementPos(1,1)-h.Trans.ElementPos(end,1))*1e-3;
            q = abs((D/2)*sin(channel_data.sequence(s).source.azimuth));
            t0_1 = q;
        
            %t_in=linspace(t_ini,t_end,no_t)-offset_time-t0_1;
            if length(h.Resource.RcvBuffer) == 1
                RcvIdx=(n_tx-1)*length(seq)+s;
            else % Received data of interest start after First buffer data
                RcvIdx=h.Resource.RcvBuffer(1).numFrames+(n_tx-1)*length(seq)+s;
            end
            
            % time interval between t0 and acquistion start and compensate for
            % center of puse + lens correction
            channel_data.sequence(s).delay = -(offset_distance+t0_1)/channel_data.sound_speed;
            
            %% read data
            data(:,:,s,frame_number)=h.RcvData(h.Receive(RcvIdx).startSample:h.Receive(RcvIdx).endSample,h.Trans.Connector,n_frame);
         
            %%
            % to check delay calculation
            if plot_delayed_signal
                %%
                z = 20e-3;
                x = 0;
                y = 0;
                TF = z*cos(channel_data.sequence(n_tx).source.azimuth)*cos(channel_data.sequence(n_tx).source.elevation)+x*sin(channel_data.sequence(n_tx).source.azimuth)*cos(channel_data.sequence(n_tx).source.elevation)
                %compensate for t0
                TF = TF + channel_data.sequence(n_tx).t0_compensation;
                % receive delay
                RF=sqrt((channel_data.probe.x-x).^2+(channel_data.probe.y-y).^2+(channel_data.probe.z-z).^2);
                % total delay
                delay=(RF+TF)/channel_data.sound_speed;
                
                time = (channel_data.initial_time+(0:h.Receive(1).endSample-1)/channel_data.sampling_frequency);
                
                figure(101); hold off;
                pcolor(1:length(channel_data.probe.x),time,abs(data(:,:,n_tx,n_frame))); shading flat; colormap gray; colorbar; hold on;
                plot(1:length(channel_data.probe.x),delay,'r');
                title(n_tx);
                ylim([0.95*min(delay) 1.05*max(delay)]);
                pause();
            end
        end
        frame_number = frame_number + 1;
    end
end
tools.workbar(1)
channel_data.data = data;

end