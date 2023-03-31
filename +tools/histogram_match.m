function [img_out, b_data_out] = histogram_match(b_data_reference,b_data_in)
% HISTOGRAM MATCH
% This function histogram match the images in the input variables
% b_data_reference and b_data_in. The b_data_in is forced to match the
% b_data_reference. The output is in dB scale as an image in img_out and a
% uff.beamformed_data object in b_data_out.
%
% The histogram mathing is done on the images in dB scale.

% Log compressed
img_ref_log = b_data_reference.get_image();
img_in_log = b_data_in.get_image();

%% Histogram matching
% DAS image as the reference for histogram matching
min_data_r = min(img_ref_log(~isinf(img_ref_log)));
max_data_r = max(img_ref_log(~isinf(img_ref_log)));
ref_scaled =  (img_ref_log - min_data_r)/(max_data_r -  min_data_r); %reference image scaled

%%%histogram matching the input image with the reference %%%
min_data_in = min(img_in_log(~isinf(img_in_log)));
max_data_in = max(img_in_log(~isinf(img_in_log)));
in_scaled =  (img_in_log - min_data_in)/(max_data_in -  min_data_in); %image scaled
img_out = imhistmatch(in_scaled,ref_scaled,1024); %histogram matching
img_out = img_out*(max_data_r -  min_data_r) + min_data_r; %back to dB scale

img_out = img_out(:);
b_data_out = uff.beamformed_data(b_data_in)
b_data_out.data = img_out(:);


