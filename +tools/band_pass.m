function [pf, h, w] = band_pass(p, Fs, F)
    %BAND_PASS   Apply a Kaiser-window FIR band-pass filter
    %
    %   [pf, h, w] = tools.band_pass(p, Fs, F)
    %
    %   Parameters:
    %       p       input signal (column-oriented)
    %       Fs      sampling frequency [Hz]
    %       F       frequency band edges [f1 f2 f3 f4] [Hz]
    %
    %   See also TOOLS.LOW_PASS, TOOLS.HIGH_PASS
    
    % Filter specification
    A = [0, 1, 0];                                          % band type: 0='stop', 1='pass'
    dev = [1e-3, 1e-3, 1e-3];                            	% max ripple in pass-band and stop-band
    [N, Wn, beta, ftype] = kaiserord(F, A, dev, Fs);        % window parameters
    b = fir1(N, Wn, ftype, kaiser(N+1,beta), 'noscale');    % filter design
    
    [h, w] = freqz(b);

    % Filtering
    [~, Ns] = max(abs(hilbert(b)));
    if mod(length(b)-1,2)
        warning("In tools.band_pass: Filter length is even. Results in inaccurate group delay compensation")
    end
    pf = filter(b, 1, p, [], 1);  
    
    % Remove invalid samples
    pf(1:Ns, :, :, :) = [];
end

