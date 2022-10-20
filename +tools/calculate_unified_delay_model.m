function [transmit_delay_out] = calculate_unified_delay_model(transmit_delay_temp,mask,scan,source)
% Implementation of the transmit delay model introduced in  Nguyen, N. Q., & Prager, R. W. (2016).
% High-Resolution Ultrasound Imaging With Unified Pixel-Based Beamforming. IEEE Trans. Med. Imaging, 35(1), 98-108.

try
    % Reshape the delays into the size of the scan
    if isa(scan,'uff.linear_scan') || isa(scan, 'uff.steered_scan')
        tx_delay = reshape(transmit_delay_temp,scan.N_z_axis,scan.N_x_axis);
        x_matrix = reshape(scan.x,scan.N_z_axis,scan.N_x_axis);
        z_matrix = reshape(scan.z,scan.N_z_axis,scan.N_x_axis);
        dirtest = scan.x_axis(end)-scan.x_axis(1);
        N_lines = scan.N_x_axis;
    elseif isa(scan,'uff.sector_scan')
        tx_delay = reshape(transmit_delay_temp,scan.N_depth_axis,scan.N_azimuth_axis);
        x_matrix = reshape(scan.x,scan.N_depth_axis,scan.N_azimuth_axis);
        z_matrix = reshape(scan.z,scan.N_depth_axis,scan.N_azimuth_axis);
        dirtest = scan.azimuth_axis(end)-scan.azimuth_axis(1);
        N_lines = scan.N_azimuth_axis;
    end
    % Mask out the valid delays within the "cone" in front of and after the transmit delay
    % The mask is calculated using the uff.apodization class before the TX delay loop.
    
    
    %quick fix to address cases where beam does not cover bottom of image
    botinds = ~mask(end,:);
    maxval = max( tx_delay(end,:).*mask(end,:) );
    
    masked_delays = mask.*tx_delay;
    mask(end,:) = true;
    masked_delays(end, botinds) = maxval;
    
    % Interpolate the delays on the "edge" of the valid region
    % Yes, the code can probably be written more efficiently and intuitive
    interpolated_delay = zeros(size(tx_delay));
    mask_before = zeros(size(tx_delay));
    last_before_idx = [];
    mask_after = zeros(size(tx_delay));
    first_after_idx = [];
    for x = 1:N_lines
        [~,z_idx_focus] = min(abs(z_matrix(:,x)-source.z));
        if sum(mask(z_idx_focus:end,x) > 0)
            ray_of_masked_delays = masked_delays(:,x);
            pos_ray_of_masked_delays = ray_of_masked_delays;
            pos_ray_of_masked_delays(ray_of_masked_delays > 0) = 0;
            pos_ray_of_masked_delays(pos_ray_of_masked_delays == 0) = -inf;
            neg_ray_of_masked_delays = ray_of_masked_delays;
            neg_ray_of_masked_delays(ray_of_masked_delays < 0) = 0;
            neg_ray_of_masked_delays(neg_ray_of_masked_delays == 0) = inf;
            
            [~,idx_a] = max(pos_ray_of_masked_delays);
            [~,idx_b] = min(neg_ray_of_masked_delays);
            
            pos_a = [ x_matrix(idx_a,x) z_matrix(idx_a,x) ];
            pos_b = [ x_matrix(idx_b,x) z_matrix(idx_b,x) ];
            
            % The "weight" vectors needs to normalized a second time to
            % get correct values (0 to 1) for the sector scan. It could be dependent on transmit angle...
            weight_vector_1 = (sqrt((z_matrix(idx_a,x) - z_matrix(:,x)).^2) / norm(pos_b-pos_a));
            weight_vector_1 = weight_vector_1./weight_vector_1(idx_b);
            weight_vector_2 = (sqrt((z_matrix(idx_b,x) - z_matrix(:,x)).^2) / norm(pos_b-pos_a));
            weight_vector_2 = weight_vector_2./weight_vector_2(idx_a);
            interpolated_delay(:,x) = weight_vector_1.* tx_delay(idx_b,x) + weight_vector_2.* tx_delay(idx_a,x);
        elseif  sum(masked_delays(z_idx_focus:end,x) == 0) && (x_matrix(z_idx_focus,x)-source.x)*dirtest < 0
            last_before_idx = x;
            mask_before(:,x) = 1;
        elseif  sum(masked_delays(z_idx_focus:end,x) == 0) && (x_matrix(z_idx_focus,x)-source.x)*dirtest > 0
            if isempty(first_after_idx)
                first_after_idx = x;
            end
            mask_after(:,x) = 1;
        end
    end
    
    if sum(mask_before(:)) > 0
        interpolated_delay(logical(mask_before)) = repmat(interpolated_delay(:,last_before_idx+1),1,sum(mask_before(1,:)));
    end
    if sum(mask_after(:)) > 0
        interpolated_delay(logical(mask_after)) = repmat(interpolated_delay(:,first_after_idx-1),1,sum(mask_after(1,:)));
    end
    
    % Use the virtual source model within the "valid region"
    interpolated_delay(mask) = tx_delay(mask);
    interpolated_delay(isinf(interpolated_delay)) = 0;
    
    transmit_delay_out = interpolated_delay(:) + source.distance;
catch ME
    error_message = sprintf('The transmit_delay_model.unified threw this error: \n %s \n Consider using the transmit_delay_model.hybrid.',ME.message);
    error(error_message);
end
end

