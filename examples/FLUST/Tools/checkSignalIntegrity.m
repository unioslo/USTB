% updated 2022-07-22, Jorgen Avdal
% this script calculates speckle statistics, spatiotemporal correlation and slow
% time frequency content for FLUST realizations. 


%% load data and add noise

addpath('Tools')
tag = 'PWI_demo';
loadBinary(tag);

noisyTab = addNoise( realTab, 20); % add noise with given dB
% noisyTab = realTab; % use this instead if not adding noise

%% settable parameters
rxang = 1; % look at this rx angle
% GTvec = [0 0.5]; % ground truth velocity vector [X Z], determines helper lines in figures
GTvec = [-cosd(90-s.phantom_params.btfAZ) sind(90-s.phantom_params.btfAZ)]*s.phantom_params.vel_1; % ground truth velocity vector [X Z], determines helper lines in figures
GTnorm = s.phantom_params.vel_1;
ROIsize = 15; % size of ROI, odd number
centerX = ceil( size(X,2)/2);
centerZ = ceil( size(X,2)/2);
Nfft = 512; % number of frequency points for Fourier analysis

%% calculations
dx = X(1,2)-X(1,1);
dz = Z(2,1)-Z(1,1);
Nz = size(Z,1);
halfSize = floor( ROIsize/2 );

statData = noisyTab( centerZ-halfSize:centerZ+halfSize, centerX-halfSize:centerX+halfSize,:,rxang,:);
statNorm = sqrt( mean( abs( statData(:) ).^2 ) )/sqrt(2);
normAxis = linspace( -3*statNorm, 3*statNorm, 1000);
normDist = 1/statNorm/sqrt(2*pi)*exp( -0.5*(normAxis./statNorm).^2);

R1phase = mean( conj( noisyTab(:,:,1:end-1,rxang,:) ).*noisyTab(:,:,2:end,rxang,:), 3 );
R1phaseKernel = R1phase( centerZ-halfSize:centerZ+halfSize, centerX-halfSize:centerX+halfSize,:,:,: );

unitVec = GTvec./GTnorm;
newPos = [X(1,centerX) Z(centerZ,1)]+(-floor(Nz/2)+1:floor(Nz/2)).'.*unitVec*dz;
mMode = zeros( length( newPos), size( noisyTab,3), 'like', 1i);
for mm = 1:size( noisyTab,3)
    mMode(:,mm) = interp2( X, Z, noisyTab(:,:,mm,1,1), newPos(:,1), newPos(:,2) );
end
% mMode = squeeze( noisyTab(:,centerX, :,1,1) );
freqtab = linspace( -pi, pi, Nfft+1); freqtab(end) = [];
slowTimeSpec = squeeze( 10*log10( mean( abs( fftshift( fft( noisyTab( centerZ-halfSize:centerZ+halfSize, centerX-halfSize:centerX+halfSize,:,rxang,:), Nfft, 3), 3) ).^2, [1 2 5]) ) );

dopPRF = s.firing_rate/length(s.PSF_params.acq.alphaTx);
slowTimeAxis = (0:size( noisyTab,3)-1)/dopPRF;

GT_rsh = reshape( GT, [s.PSF_params.scan.Nz s.PSF_params.scan.Nx 1 3] );
GTmask = ~isnan(GT_rsh(:,:,1) );
vNyq = s.PSF_params.trans.c0*dopPRF/4/s.PSF_params.trans.f0;
dopVec = 0.5*(s.PSF_params.phaseVecsTx(:,rxang)+s.PSF_params.phaseVecsRx(:,rxang) );
GTphase = mod( GTvec*dopVec([1; 3])./vNyq*pi+pi, 2*pi)-pi;

tLagVec = (-size( noisyTab,3)+1:size( noisyTab,3)-1)/dopPRF;
spatLagVec = (-length(newPos)+1:length(newPos)-1).*dz;
aCorr = conv2( conj(mMode), flip( flip( mMode, 1), 2) );
GTposLine = -tLagVec.*GTnorm;

%% Visualization
figure(201),
set( gcf, 'Position', [10 10 1488 937] )
currIm = 20*log10( abs( noisyTab(:,:,1,1,1) ) );
subplot(2,3,1), hold off, imagesc( X(:)*1e3,Z(:)*1e3, currIm-max( currIm(:) )); caxis([-60 0]); colormap( gray); title( 'Envelope image and kernel');
hold on, rectangle( 'Position', [X(1,centerX-halfSize) Z(centerZ-halfSize,1) 2*halfSize*dx 2*halfSize*dz]*1e3, 'Linewidth', 2);
hold on, plot( newPos(:,1)*1e3, newPos(:,2)*1e3, 'r--', 'Linewidth', 2);
xlabel('[mm]'); ylabel('[mm]');
set( gca, 'FontSize', 18);

subplot(2,3,2), hold off, imagesc( slowTimeAxis*1e3, Z(:)*1e3, 20*log10( abs( mMode) ) ); title( 'M-mode, red line');
xlabel('[ms]'); ylabel('[mm]');
set( gca, 'FontSize', 18);

[Rvals, Redges] = histcounts( real( statData(:) ) ); Rwidth = Redges(2)-Redges(1);
[Ivals, Iedges] = histcounts( imag( statData(:) ) ); Iwidth = Redges(2)-Redges(1);
subplot(2,3,4), hold off, plot( Redges(1:end-1)+Rwidth/2, Rvals./numel( statData)./Rwidth, 'b-', 'Linewidth', 2);
hold on, plot( Iedges(1:end-1)+Iwidth/2, Ivals./numel( statData)./Iwidth, 'r-', 'Linewidth', 2);
hold on, plot( normAxis, normDist, 'k--', 'Linewidth', 2 );
hl = legend( {'Real part', 'Imag part', 'Norm dist'} );
set( hl, 'Position', [0.2515 0.3627 0.0921 0.0886], 'Fontsize', 15 );
title( 'Speckle intensity');
xlabel('Value'); ylabel('Probability density');
set( gca, 'FontSize', 18);

[R1vals, R1edges] = histcounts( angle( R1phaseKernel(:) ) ); R1width = R1edges(2)-R1edges(1);
subplot(2,3,3), hold off, plot( R1edges(1:end-1)+R1width/2, R1vals./numel( R1phaseKernel)./R1width, 'k-', 'Linewidth', 2);
% histogram( angle( R1phaseKernel(:) ) );
xlabel('Value'); ylabel('Probability density');
set( gca, 'FontSize', 18);
yl = ylim;
hold on , plot( [1 1]*GTphase, yl, 'r--', 'LineWidth', 2); title( 'R1 phase angle');

subplot(2,3,5), hold off, imagesc( tLagVec*1e3, spatLagVec*1e3, abs(aCorr) );
hold on, plot( tLagVec*1e3, GTposLine*1e3, 'r--', 'LineWidth', 2); title( '2-D autocorr of M-mode' );
xlabel('Temporal lag [ms]'); ylabel('Spatial lag [mm]');
set( gca, 'FontSize', 18);


subplot(2,3,6), hold off, plot( freqtab, slowTimeSpec, 'k-', 'Linewidth', 2); xlim([-pi pi]); title('Slow time spectrum');
xlabel('Angular frequency'); ylabel('Amplitude [dB]');
set( gca, 'FontSize', 18);
yl = ylim;
hold on , plot( [1 1]*GTphase, yl, 'r--', 'LineWidth', 2);
