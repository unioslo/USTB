function result = estimate_LSvectorDoppler( realTab)
% Least Squares Vector Doppler estimator 
% based on Xu et al, 1991, DOI: 10.1109/ULTSYM.1991.234060

% Updated 28/06/2022, Joergen Avdal (jorgen.avdal@ntnu.no) and 
% Ingvild Kinn Ekroll (ingvild.k.ekroll@ntnu.no)

s = evalin( 'base', 's');

Na = length(s.PSF_params.acq.alphaTx);
PRF = s.firing_rate/Na;
f_demod = s.PSF_params.trans.f0;
c = s.PSF_params.trans.c0;
vNyq = PRF*c/(4*f_demod);


R1 = angle( mean(conj(realTab(:,:,1:end-1,:,:)).*realTab(:,:,2:end,:,:),3) );
R1sz = size( R1, [1 2 4 5]);
R1 = permute( R1, [1 2 5 3 4] );
R1 = reshape( R1, R1sz(1)*R1sz(2)*R1sz(4), R1sz(3) );
R1 = R1(:,:);

alphaTx = s.PSF_params.acq.alphaTx;
alphaRx = s.PSF_params.acq.alphaRx;
aMat = [-sin(alphaTx)-sin(alphaRx); -cos(alphaTx)-cos(alphaRx)]./2;

pseudoInv = pinv(aMat);

angVec = R1*pseudoInv;
angVec = reshape( angVec, R1sz( [1 2 4 3] ) );

result.vxEst = angVec(:,:,:,1)/pi*vNyq;
result.vzEst = angVec(:,:,:,2)/pi*vNyq;
