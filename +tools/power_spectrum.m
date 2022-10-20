function [fx, pw] = power_spectrum(data, fs, normalised, N)
    % function [fx, pw] = power_spectrum(data,fs)
    
    if nargin < 3
        normalised = true;
    end
    if nargin < 4    
        N = min(5, size(data, 4));     % number of temporal frames to average
    end
    
    pw = fftshift(fft(data(:,:,:,1:N), [], 1));
    pw = mean(abs(pw).^2, [2, 3, 4]);
    if normalised 
        pw = pw/max(pw); 
    end
    fx = linspace(-fs/2,fs/2, size(data, 1)+1);
    fx(end) = []; 
end

