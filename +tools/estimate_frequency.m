function [fc, bw] = estimate_frequency(time,data)
    %ESTIMATE_FREQUENCY   Estimate center frequency and bandwidth of a signal
    %
    %   [fc, bw] = tools.estimate_frequency(time, data)
    %
    %   See also TOOLS.POWER_SPECTRUM
    Fs=1/mean(diff(time));                      % sampling frequency
    [fx pw]=tools.power_spectrum(data,Fs);
    fpw=filter(ones(1,26)./26,1,pw);fpw=[fpw(13:end); zeros(12,1)];
    [dc ic]=max(fpw.*(fx>0).'); fc=fx(ic);
    bw_up=min(fx((fx>fc)&(fpw<dc/2).'));        % -6dB upper limit
    bw_do=max(fx((fx<fc)&(fpw<dc/2).'));        % -6dB down limit
    fc=(bw_up+bw_do)/2;                         % center frequency
    bw=2*(bw_up-fc);                            % bandwidth
end

