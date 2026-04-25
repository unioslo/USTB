function [] = localized_normalization(bf_data, K, T)
%LOCALIZED_NORMALIZATION Summary of this function goes here
%   Detailed explanation goes here
scan = bf_data.scan;

% px_x = scan.x_axis(2) - scan.x_axis(1);
% px_z = scan.z_axis(2) - scan.z_axis(1);
% 
% res_x = 1540*pulse_duration/2;
% disp(strjoin(["Pixel Resolution: " num2str(px_x*1e3, "%.2f") "mm x " num2str(px_z*1e3, "%.2f") "mm"],''))
% disp(strjoin(["X Resolution:" num2str(res_x*1e3, "%.2f") "mm"]))

% for frame_i = 1:size(bf_data.data, 4)
% 
%     original_data = reshape(bf_data.data(:,:,:,frame_i), [scan.N_z_axis, scan.N_x_axis]);
% 
%     K = ones(3,3) ./ 9;
% 
%     avgs = conv2(original_data, K, 'same');
%     new_data = original_data ./ avgs;
%     new_data = avgs;
% 
%     for j = 1:scan.N_z_axis
%         depth = scan.z_axis(j);
%         res_z = lambda * depth / aperture;
%         if frame_i == 1 && j == 1
%             disp(strjoin(["Z Resolution:" num2str(res_z*1e3, "%.2f") "mm"]))
%         end
% 
%         K_x = ceil(res_x / px_x);
%         K_z = ceil(res_z / px_z);
% 
%         if mod(j, 10) == 0 && frame_i == 1
%             D = depth * 1e3;
%             disp(strjoin(["Depth " num2str(D, "%.2f") "mm gives a neighbourhood off " K_x "x" K_z], ''))
%         end
% 
%         for i = 1:scan.N_x_axis
%             K = ones(K_x, K_z);
%             K = K ./ sum(K(:));
% 
%             new_data(i, j) = 
%         end
%     end
%     bf_data.data(:,:,:,frame_i) = reshape(new_data, scan.N_pixels, 1, 1);

reshaped_data = reshape(bf_data.data, [scan.N_z_axis, scan.N_x_axis, bf_data.N_frames]);

% K = 5; % Set based on system's resolution limit
temporal_window = T; % Consider frames before and after
epsilon = 1e-5;

padded_data = padarray(reshaped_data, [floor(K/2), floor(K/2)], 'replicate', 'both');
kernel = ones(K, K) / (K * K);

% Initialize output array
normalized_data = zeros(size(reshaped_data));
% Perform normalization for each frame
for frame = 1:bf_data.N_frames
    % disp(strjoin(["Calculating frame" frame]))

    start_frame = max(1, frame - floor(temporal_window/2));
    end_frame = min(bf_data.N_frames, frame + floor(temporal_window/2));
    local_mean = mean(imfilter(reshaped_data(:,:,start_frame:end_frame), kernel, 'replicate'), 3);
    normalized_data(:,:,frame) = reshaped_data(:,:,frame) ./ (local_mean + epsilon);

end

% Reshape back to original 4D structure if needed
bf_data.data = reshape(normalized_data, [bf_data.N_pixels, 1, 1, bf_data.N_frames]);

end

