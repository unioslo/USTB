function [b_data_out] = scan_convert_all_frames(b_data_in,dynamic_range,gain)
%% Example code on how to easily convert data from uff.beamformed_data.data to gray scale image

if ~isreal(b_data_in.data)
    %img = reshape(b_data_in.data,b_data_in.scan.N_depth_axis,b_data_in.scan.N_azimuth_axis,b_data_in.N_frames);% Get raw reshaped image data in dB (withouth log compression)
    img_dB = b_data_in.get_image(); %Log compress, and normalize on max for all images
else
    img_dB = b_data_in.get_image('none');
end
%%
% Scan convert all image frames
for f = 1:b_data_in.N_frames
    [img_scan_converted(:,:,f),Xs,Zs] = tools.scan_convert(img_dB(:,:,f),b_data_in.scan.azimuth_axis,b_data_in.scan.depth_axis,512,512);
end

% Normalize from dB image to 0 - 255 image and apply gain and dynamic range
img_sc_reject = img_scan_converted + gain;
img_sc_reject((img_sc_reject) < -dynamic_range) = -dynamic_range; %Reject everything below dynamic range
img_sc_reject((img_sc_reject) > 0) = 0; %Everything above 0 dB should be saturated
img_gray_scale = round(255*(img_sc_reject+dynamic_range)/dynamic_range);

%% Get a linear scan for the scan converted data
sca_scan_converted = uff.linear_scan('x_axis',Xs,'z_axis',Zs);

%% Create a beamformed object to hold the scan converted gray level images
b_data_out = uff.beamformed_data();
b_data_out.scan = sca_scan_converted;
b_data_out.data = single(reshape(img_gray_scale,sca_scan_converted.N_z_axis*sca_scan_converted.N_x_axis,b_data_in.N_channels,b_data_in.N_waves,b_data_in.N_frames));
