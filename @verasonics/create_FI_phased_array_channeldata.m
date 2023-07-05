function channel_data = create_FI_phased_array_channeldata(h,number_of_frames)

%%%%
%    Save to channeldata for Focused Imaging with phased array imaging
%% Create channel_data object and set some parameters
channel_data = uff.channel_data();
channel_data.sampling_frequency = h.Fs;
channel_data.sound_speed = h.c0;
channel_data.initial_time = 0;
channel_data.probe=create_probe_object(h);

if nargin < 2
    h.number_of_frames = h.Resource.RcvBuffer(1).numFrames;
else
    h.number_of_frames = number_of_frames;
end

%% SEQUENCE GENERATION
N=length(h.TX);                      % number of focused beams
azimuth_axis=h.angles.';
seq=uff.wave();
for n=1:N
    seq(n)=uff.wave();
    seq(n).probe=channel_data.probe;
    seq(n).source=uff.point();
    seq(n).source.azimuth=azimuth_axis(n);
    seq(n).source.distance=h.TX(n).focus*h.lambda;
    seq(n).sound_speed=channel_data.sound_speed;
    seq(n).apodization.apodization_vector = h.TX(n).Apod;
    seq(n).origin.xyz = mean(channel_data.probe.geometry(h.TX(n).Apod,1:3),1);
end
channel_data.sequence = seq;

channel_data.pulse = uff.pulse();
channel_data.pulse.center_frequency = h.f0;

%% Convert channel data from Verasonics format to USTB format
data = int16(zeros(h.Receive(1).endSample, channel_data.N_elements, channel_data.N_waves, h.number_of_frames));

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
        tools.workbar((n_tx+(frame_idx-1)*length(channel_data.sequence))/(length(h.frame_order)*length(channel_data.sequence)),sprintf('Reading %d frame(s) of FI data from Verasonics.',length(h.frame_order)),'Reading FI data from Verasonics.')          
        
        % compute the offset in time from center of probe to
        % center of transmit wave. We do this by finding the
        % mean between the two center transmit delays for a
        % even numbered probe, and the center transmit delay
        % for a odd elemtn probe
        t0_comp_in_m = mean(h.TX(n_tx).Delay(ceil(channel_data.probe.N_elements/2):ceil((channel_data.probe.N_elements+1)/2)))*h.lambda;
    
        % time interval between t0 and acquistion start and compensate for
        % center of puse + lens correction
        channel_data.sequence(n_tx).delay = -(offset_distance+t0_comp_in_m)/channel_data.sound_speed;
        data(:,:,n_tx,frame_idx) = h.RcvData{1}(h.Receive(n).startSample:h.Receive(n).endSample,h.Trans.Connector,n_frame);

        %%
        % to check delay calculation
        % NB! For phased array this is only correct when you
        % are firing at angle=0
        if plot_delayed_signal
            if n_tx == length(channel_data.sequence)/2
                % Point to beamform to (where the scatterer is in the simulation)
                % Need to change to correct scatter setup in the
                % Verasonics script, see FI_phase_array_p4.m for
                % example. This seems to be correct, but the delays
                % are slighty off for transmit angles > 0 but not
                % for angles < 0. Strange. Is there somthing wrong
                % with the Verasonics simulation?? :)
                
                [z_all,x_all] = pol2cart(h.angles,ones(1,length(h.angles))*40e-3);
                x = x_all(n_tx);
                y = 0;
                z = z_all(n_tx);
                
               
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
                
                %%
                figure(101); hold off;
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

%%

end