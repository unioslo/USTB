% Calling this tool before runFLUST will set s.dr to a recommended value based on the PSF function setup
errThresh = s.interpErrorLimit; % percent

allPos = cat(1, flowField.postab);
flowCentroid = mean( allPos, 1);

nP = 91; % number of display points
dispSpacing = 1e-5;
dispTab = (-(nP-1)/2:1:(nP-1)/2).'*dispSpacing;

%generate lateral and axial lines through PSF
testPos = flowCentroid + [ [dispTab zeros( length( dispTab), 2)]; [zeros( length( dispTab), 2) dispTab ] ];

[PSFstruct,p] = s.PSF_function(testPos, s.PSF_params); % PSFs in uff/beamformed_data format

%% reshape PSF data
noAngs = size( PSFstruct.data, 3);
if isa( PSFstruct.scan, 'uff.sector_scan')
    szZ = length(PSFstruct.scan.depth_axis); % size( PSFs, 1);
    szX = length(PSFstruct.scan.azimuth_axis); % size( PSFs, 2);
elseif isa( PSFstruct.scan, 'uff.linear_scan') || isa( PSFstruct.scan, 'uff.linear_scan_rotated')
    szZ = length(PSFstruct.scan.z_axis); % size( PSFs, 1);
    szX = length(PSFstruct.scan.x_axis); % size( PSFs, 2);
end
PSFs = reshape( PSFstruct.data, [szZ, szX, noAngs, size( testPos,1)] );
s.PSF_params = p;
% [~, indX] = min( abs( flowCentroid(1)-PSFstruct.scan.x_axis) );
% [~, indZ] = min( abs( flowCentroid(3)-PSFstruct.scan.z_axis) );
[~, myInd] = min( (flowCentroid(1)-PSFstruct.scan.x).^2+(flowCentroid(3)-PSFstruct.scan.z).^2 );

% [indZ, indX] = ind2sub( size( PSFs, [1 2] ), myInd);
[indZ, indX] = ind2sub([size(PSFs, 1), size(PSFs,2)], myInd);


%% dev visualization
if 0
    figure, imagesc(PSFstruct.scan.x(:), PSFstruct.scan.z(:),abs(PSFs(:,:,1,1))), title('PSF, angle 1, lat pos 1')
    hold on, plot(testPos(:,1), testPos(:,3),'.r')
    hold on, plot(testPos(1,1), testPos(1,3),'ok')
    hold on, plot(PSFstruct.scan.x(myInd), PSFstruct.scan.z(myInd),'sqy', 'lineWidth',2)
    legend('testpositions PSFs','current position','sampling position IQ signal (slow time signal)')
    
    % IQ without phase correction
    latIQ = permute( PSFs(indZ,indX,:,1:nP), [4 3 1 2] );
    axIQ = permute( PSFs(indZ,indX,:,nP+(1:nP) ), [4 3 1 2] );
    
    figure,subplot(1,2,1)
    plot(real(latIQ))
    hold on, plot(imag(latIQ))
    hold on, plot(abs(latIQ),'-*r')
    legend('in-phase (realIQ) angle 1','in-phase angle 2','quadrature (imagIQ) angle 1','quadrature angle 2','abs(IQ) angle 1','abs(IQ) angle 2')
    title('lateral, slow time')
    xlabel('N (91) spatial sampling points')
    
    subplot(1,2,2), plot(real(axIQ))
    hold on, plot(imag(axIQ))
    hold on, plot(abs(axIQ),'-*r')
    legend('in-phase (realIQ) angle 1','in-phase angle 2','quadrature (imagIQ) angle 1','quadrature angle 2','abs(IQ) angle 1','abs(IQ) angle 2')
    title('axial, slow time')
    xlabel('N (91) spatial sampling points')
    
    figure, subplot(1,2,1), plot(real(latIQ(:,1)), imag(latIQ(:,1)),'*-r'), title('lat IQ angle 1'), xlabel('I'), ylabel('Q'), axis equal
    subplot(1,2,2), plot(real(axIQ(:,1)), imag(axIQ(:,1)),'*-r'), title('ax IQ angle 1'), xlabel('I'), ylabel('Q'), axis equal
    
    figure,subplot(1,2,1), plot(atan2(real(latIQ),imag(latIQ)),'-*r'), title('phase of latIQ')
    subplot(1,2,2),  plot(atan2(real(axIQ),imag(axIQ)),'-*r'), title('phase of axIQ')
    legend('angle 1','angle 2')
end

%% phase correction makes PSF interpolation more robust and allows for smaller s.dr
if isfield(s.PSF_params, 'phaseCorr')
    modPhase = exp(1i*2*pi*s.PSF_params.phaseCorr );
    mPoffset = nP;
    mP = nP;
else
    modPhase = ones(1, noAngs);
    mPoffset = 0;
    mP = 1;
end

%% fill in IQ signals at center of PSFs
latSig = permute( PSFs(indZ,indX,:,1:nP), [4 3 1 2] ).*modPhase(1:mP,:);
axSig = permute( PSFs(indZ,indX,:,nP+(1:nP) ), [4 3 1 2] ).*modPhase(mPoffset+(1:mP),:);

%% generate interpolation filters
maxFact = 40;
filtXax = (-maxFact:maxFact).';
Nfft = length( dispTab)+length( filtXax)-1;
fFact = permute( 1:maxFact, [1 3 2] );
currFilt = (fFact-abs( filtXax ) )./fFact;
currFilt( currFilt < 0) = 0;
cF_norm = sum( abs( currFilt ), 1);
currFilt = currFilt./cF_norm;
filtFFTs = fftshift( fft( currFilt, Nfft, 1 ), 1 );

%% Estimate interpolation errors
latFFTs = fftshift( fft( latSig, Nfft, 1), 1);
axFFTs = fftshift( fft( axSig, Nfft, 1), 1);
filtLatFFTs = latFFTs.*filtFFTs;
filtAxFFTs = axFFTs.*filtFFTs;

latPowFac = max( 1-sum( abs( filtLatFFTs).^2, 1)./sum( abs( latFFTs).^2, 1), [], 2);
axPowFac = max( 1-sum( abs( filtAxFFTs).^2, 1)./sum( abs( axFFTs).^2, 1), [], 2);

figure(11), subplot(2,1,1), 
plot( dispSpacing*(2:maxFact), abs( squeeze( latPowFac(2:end) ) )*1e2, 'k-x'); 
title( 'Lateral interpolation error');
xlabel('s.dr');
ylabel('Relative error [%]')
subplot(2,1,2), 
plot( dispSpacing*(2:maxFact), abs( squeeze( axPowFac(2:end) ) )*1e2, 'k-x'); 
title( 'Axial interpolation error');
xlabel('s.dr');
ylabel('Relative error [%]')

%% determine limits for spatial discretization
[~, sDr_latInd] = find( latPowFac*1e2 < errThresh, 1, 'last');
[~, sDr_axInd] = find( axPowFac*1e2 < errThresh, 1, 'last');
sDr_lat = fFact( sDr_latInd)*dispSpacing;
sDr_ax = fFact( sDr_axInd)*dispSpacing;
s.dr = min( sDr_lat, sDr_ax);

clc
disp(['Suggested upper limit for s.dr for axial interpolation ' num2str( sDr_ax)]);
disp(['Suggested upper limit for s.dr for lateral interpolation ' num2str( sDr_lat)]);
disp(['s.dr changed to ' num2str( s.dr)]);
pause(2);