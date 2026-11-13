function [mls, gradient_energy, entropy] = ulm_image_metrics(img, window, bins)
%ULM_IMAGE_METRICS  Heuristic indices used to rank in vivo ULM images.
%
%   [mls, gradient_energy, entropy] = ulm_image_metrics(img, window, bins)
%
%   img     image with values in [0, 1] (normalized and histogram matched,
%           see match_histogram)
%   window  side of the square window of the local standard deviation
%   bins    number of histogram bins of the entropy
%
%   mls              mean local standard deviation ("local contrast"): the
%                    standard deviation inside every window x window patch
%                    that fits in the image, averaged over the image
%   gradient_energy  mean of Gx^2 + Gy^2, with Gx and Gy the Sobel
%                    derivatives (scaled to unit pixel spacing)
%   entropy          Shannon entropy of the histogram, in nats

% Mean local standard deviation, sigma = sqrt(E[x^2] - E[x]^2) per patch
box = ones(window)/window^2;
local_mean   = conv2(img, box, 'valid');
local_square = conv2(img.^2, box, 'valid');
mls = mean(sqrt(max(local_square - local_mean.^2, 0)), 'all');

% Mean squared gradient
sobel = [1 0 -1; 2 0 -2; 1 0 -1]/8;
gx = conv2(img, sobel, 'valid');
gy = conv2(img, sobel.', 'valid');
gradient_energy = mean(gx.^2 + gy.^2, 'all');

% Shannon entropy
p = histcounts(img(:), linspace(0, 1, bins + 1), 'Normalization', 'probability');
p = p(p > 0);
entropy = -sum(p.*log(p));
end
