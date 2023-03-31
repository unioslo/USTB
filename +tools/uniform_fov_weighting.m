function [apod,array_gain_compensation,geo_spreading_compensation] = uniform_fov_weighting(mid)
%UNIFORM_FOV_WEIGHTING Calculate weighting to give uniform field of view
%   Compensate for the varying number of elements to go into the sum

assert(isa(mid,'midprocess'),'Input has to be a midprocess object');

% calculate transmit apodization according to 10.1109/TUFFC.2015.007183
mid.transmit_apodization.sequence=mid.channel_data.sequence;
mid.transmit_apodization.focus=mid.scan;
tx_apodization=single(mid.transmit_apodization.data);

% calculate receive apodization
mid.receive_apodization.probe=mid.channel_data.probe;
mid.receive_apodization.focus=mid.scan;
rx_apodization=single(mid.receive_apodization.data);

% Calculate the combination of the apodization 
N=mid.channel_data.N_waves*mid.channel_data.N_channels;
apod_matrix = zeros(mid.scan.N_pixels,1);
for n_wave=1:mid.channel_data.N_waves
    if any(tx_apodization(:,n_wave))
        % receive loop
        for n_rx=1:mid.channel_data.N_channels
            if any(rx_apodization(:,n_rx))
                
                % progress bar
                n=(n_wave-1)*mid.channel_data.N_channels+n_rx;
                if mod(n,round(N/100))==0
                    tools.workbar(n/N,sprintf('Calculate weigting'));
                end
                
                apodization= rx_apodization(:,n_rx).*tx_apodization(:,n_wave);
                
                apod_matrix=apod_matrix+apodization;
            end
        end
    end
end
tools.workbar(1);

array_gain_compensation = reshape(apod_matrix,mid.scan.N_z_axis,mid.scan.N_x_axis);

%Calculate approximate compensation for r^2 geometrical spreading
geo_spreading_compensation = (repmat(mid.scan.z_axis,1,length(mid.scan.x_axis))).^2;


apod = geo_spreading_compensation./array_gain_compensation;

end

