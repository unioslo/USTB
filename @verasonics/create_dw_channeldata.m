function channel_data = create_dw_channeldata(h)
%%%%%%
%
%   Get channel_data object for DW (diwerging wave) imaging from the Verasonics scanner
%   

%% Create channel_data object and set some parameters
channel_data = uff.channel_data();
channel_data.sampling_frequency = h.Fs;
channel_data.sound_speed = h.c0;
channel_data.probe=create_probe_object(h);

%% SEQUENCE GENERATION
N=size(h.TX,2);             % number of diverging waves
for n=1:N
    seq(n)=uff.wave();
    seq(n).probe=channel_data.probe;
    source = [h.TX(n).focus*h.lambda*sin(h.angles(n)) 0 h.TX(n).focus*h.lambda*cos(h.angles(n))]; 
    seq(n).source.xyz = source;
    seq(n).sound_speed=channel_data.sound_speed;
    seq(n).apodization.apodization_vector = h.TX(n).Apod;
    seq(n).origin.x = seq(n).source.x;
end
channel_data.sequence = seq;


%% Save Pulse
channel_data.pulse = uff.pulse();
channel_data.pulse.center_frequency = h.f0;

%% Convert channel data from Verasonics format to USTB format
data = int16(zeros(h.Receive(1).endSample, channel_data.N_elements, channel_data.N_waves, h.Resource.RcvBuffer(1).numFrames));
offset_distance = calc_lens_corr_and_center_of_pulse_in_m(h); % Get offset distance for t0 compensation
%Assuming the initial time is the same for all waves
channel_data.initial_time = 2*h.Receive(1).startDepth*h.lambda/channel_data.sound_speed;
plot_delayed_signal=0;
tools.workbar()
n=1;% idx for Receive
frame_idx = 0;
for n_frame = h.frame_order
    frame_idx = frame_idx + 1;
    for n_tx = 1:length(channel_data.sequence)
        tools.workbar((n_tx+(frame_idx-1)*length(channel_data.sequence))/(length(h.frame_order)*length(channel_data.sequence)),sprintf('Reading %d frame(s) of CPWC data from Verasonics.',length(h.frame_order)),'Reading  CPWC data from Verasonics.')          
        
        % time interval between t0 and acquistion start and compensate for
        % center of puse + lens correction
        %source = [h.TX(n_tx).focus*h.lambda*sin(h.angles(n_tx)) 0 h.TX(n_tx).focus*h.lambda*cos(h.angles(n_tx))]; 
        %dst = sqrt(sum(bsxfun(@plus,source,-channel_data.probe.geometry(:,1:3)).^2,2));
        %dst0 = sqrt(sum(bsxfun(@plus,source,[0 0 0]).^2,2));
        %channel_data.sequence(n_tx).delay = -(offset_distance + dst0-min(dst))/channel_data.sound_speed;

        % time interval between t0 and acquistion start and compensate for
        % center of puse + lens correction
        t0_comp_in_m = mean(h.TX(n_tx).Delay(ceil(channel_data.probe.N_elements/2):ceil((channel_data.probe.N_elements+1)/2)))*h.lambda;
        channel_data.sequence(n_tx).delay = -(offset_distance + t0_comp_in_m)/channel_data.sound_speed;

        % read data
        data(:,:,n_tx,frame_idx)=h.RcvData{1}(h.Receive(n).startSample:h.Receive(n).endSample,h.Trans.Connector,n_frame);

        %%
        % to check delay calculation
        if plot_delayed_signal
            %%
            z = 20e-3;
            x = 0;
            y = 0;
            
            % distance between source and elements
            TF=(-1).^(z<channel_data.sequence(n_tx).source.z).*sqrt((channel_data.sequence(n_tx).source.x-x).^2+(channel_data.sequence(n_tx).source.y-y).^2+(channel_data.sequence(n_tx).source.z-z).^2);
            % add distance from source to origin
            TF=TF-channel_data.sequence(n_tx).source.distance;
            %compensate for t0
            TF = TF - channel_data.sequence(n_tx).delay*channel_data.sound_speed;
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
        n=n+1;
    end
end
channel_data.data = data;
tools.workbar(1);
end