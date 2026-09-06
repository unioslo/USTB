function y = pad_post_samples(x, n)
%PAD_POST_SAMPLES  Append N zero rows along first dimension (no IPT padarray).
%   Same as padarray(x, n, 'post') for padding along dim 1 when IPT unavailable.

if n <= 0
    y = x;
    return
end
sz = size(x);
pad = zeros([n, sz(2:end)], 'like', x);
y = cat(1, x, pad);
end
