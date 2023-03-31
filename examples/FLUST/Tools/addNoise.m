function realTab_wNoise = addNoise( realTab, SNR, sigPow)
if nargin < 3
    try
        GT = evalin( 'base', 'GT');
    catch
        disp( 'GT not found in base, call function with three parameters');
        return
    end
    sigPow = calcMeanPow( realTab, GT);
end
myNoise = (randn( size( realTab) ) + 1i*randn( size( realTab ) ) )/sqrt(2)*sqrt(sigPow)*10^(-SNR/20);
realTab_wNoise = realTab + myNoise;
end
