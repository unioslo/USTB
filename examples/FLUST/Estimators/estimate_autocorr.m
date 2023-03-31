function result = estimate_autocorr( realTab)
% Basic autocorrelation estimator 
% based on Kasai et al, 1985, DOI: 10.1109/T-SU.1985.31615

% Updated 28/06/2022, Joergen Avdal (jorgen.avdal@ntnu.no) and 
% Ingvild Kinn Ekroll (ingvild.k.ekroll@ntnu.no)

s = evalin( 'base', 's');

Na = length(s.PSF_params.acq.alphaTx);
PRF = s.firing_rate/Na;
f_demod = s.PSF_params.trans.f0;
c = s.PSF_params.trans.c0;

R1 = squeeze(mean(conj(realTab(:,:,1:end-1,:,:)).*realTab(:,:,2:end,:,:),3));
result.vAxEst = angle(R1)*PRF*c/(4*f_demod*pi);
