function res = GPWC_compute_fwhm_6dB(x_axis, y_signal)
%GPWC_COMPUTE_FWHM_6DB Compute the -6dB width (FWHM) for CPWC_double_adaptive_redone.m publish.
coeff = 10;
x_interp = linspace(x_axis(1), x_axis(end), length(x_axis) * coeff);
y_interp = interp1(x_axis, y_signal, x_interp, 'spline');

idx_above = find(y_interp >= -6);

if isempty(idx_above)
    res = NaN;
    warning('Could not find -6dB crossing points');
    return
end

res = x_interp(idx_above(end)) - x_interp(idx_above(1));

end
