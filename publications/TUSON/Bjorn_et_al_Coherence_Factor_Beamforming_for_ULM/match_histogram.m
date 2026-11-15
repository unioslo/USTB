function matched = match_histogram(img, reference, bins)
%MATCH_HISTOGRAM  Normalize an image to [0, 1] and match its histogram to
%   that of a reference image.
%
%   matched = match_histogram(img, reference, bins)
%
%   Both images are first min-max normalized. Every gray level v of img is
%   then mapped to the level of the reference with the same cumulative
%   probability, v -> F_ref^-1(F_img(v)), with the cumulative distributions
%   estimated on a histogram of |bins| bins (Gonzalez & Woods, Digital
%   Image Processing, histogram specification). ULM density images count
%   tracks per pixel, so two images can only be compared after this step.

normalize = @(x) (x - min(x(:)))/(max(x(:)) - min(x(:)));
img = normalize(double(img));
reference = normalize(double(reference));

edges = linspace(0, 1, bins + 1);
cdf_img = cumsum(histcounts(img(:), edges, 'Normalization', 'probability'));
cdf_ref = cumsum(histcounts(reference(:), edges, 'Normalization', 'probability'));

% For every level of img, the first reference level whose CDF reaches it
level = zeros(1, bins);
for k = 1:bins
    level(k) = find(cdf_ref >= cdf_img(k) - 1e-12, 1, 'first');
end
centers = (edges(1:end-1) + edges(2:end))/2;
bin = min(floor(img*bins) + 1, bins);
matched = reshape(centers(level(bin)), size(img));
matched = normalize(matched);
end
