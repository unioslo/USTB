function new_scan = scan_integer_upscale(scan, upscale_factor)
% Resample a scan with an integer size factor.

scan_upsampled = uff.linear_scan();
scan_upsampled.x_axis = linspace(scan.x_axis(1), scan.x_axis(end), scan.N_x_axis*upscale_factor-upscale_factor+1)';
scan_upsampled.z_axis = linspace(scan.z_axis(1), scan.z_axis(end), scan.N_z_axis*upscale_factor-upscale_factor+1)';

new_scan = scan_upsampled;
end

