%%
if ~(exist( 'removeDisclaimer', 'var') && removeDisclaimer)
    msg{1} = 'If using FLUST for scientific publications, please cite the original paper';
    msg{2} = 'Avdal et al: Fast Flow-Line-Based Analysis of Ultrasound Spectral and';
    msg{3} = 'Vector Velocity Estimators, tUFFC, 2019. DOI: 10.1109/TUFFC.2018.2887398';
    msg{4} = '';
    msg{5} = 'How to use FLUST:';
    msg{6} = '1) Provide/select function to calculate PSFs from a vector of spatial positions. ';
    msg{7} = '2) Run FLUST on phantom of interest.';
    msg{8} = '3) Apply your favorite velocity estimator to realizations. ';
    msg{9} = '4) Assess statistical properties of estimator, optimize estimator.';
    msg{10} = '5) Publish results, report statistical properties, make results';
    msg{11} = '   reproducible, cite original paper DOI: 10.1109/TUFFC.2018.2887398';

    waitfor( msgbox( msg) );
    removeDisclaimer = 1;
end

%%
if ~isfield( s, 'useGPU'), s.useGPU = 0; end 

if isfield( s, 'interpErrorLimit')
    % Get recommended spatial distance ?r between scatterer positions along
    % flowlines
    suggestSpacing;
end
overSampFactTab = zeros( length( flowField), 1 );

%% FLUST main loop
for kk = 1:length(flowField)

    %% resample along flowlines with density s.dr (?r)
    prop = diff( flowField(kk).postab, 1);
    propdist = [0; cumsum( sqrt( sum( prop.^2, 2 ) ), 1 ) ];
    newdists = (0:s.dr:max(propdist)).';
    newtimetab = interp1( propdist, flowField(kk).timetab, newdists);
    newpostab = interp1( flowField(kk).timetab, flowField(kk).postab, newtimetab);

    %% calculate PSFs at each position (newpostab) along flowline kk
    simStart = tic;
    if isfield( s.PSF_params, 'run') && isfield( s.PSF_params.run, 'runMode') && strcmp( s.PSF_params.run.runMode, 'chOnly')
        [PSFstruct,p,pipe] = s.PSF_function(newpostab, s.PSF_params); % PSFs in channel data format
    else
        [PSFstruct,p] = s.PSF_function(newpostab, s.PSF_params); % PSFs in uff/beamformed_data format
    end
    s.PSF_params = p;
    AsimTime = toc(simStart);

    %% reshape PSF data
    noAngs = size( PSFstruct.data, 3);
    if isa( PSFstruct, 'uff.beamformed_data') || ( isfield(PSFstruct, 'isMUST') && PSFstruct.isMUST)      % beamformed data
        if isa( PSFstruct.scan, 'uff.sector_scan')
            szZ = length(PSFstruct.scan.depth_axis); % size( PSFs, 1);
            szX = length(PSFstruct.scan.azimuth_axis); % size( PSFs, 2);
        elseif isa( PSFstruct.scan, 'uff.linear_scan') || isa( PSFstruct.scan, 'uff.linear_scan_rotated')
            szZ = length(PSFstruct.scan.z_axis); % size( PSFs, 1);
            szX = length(PSFstruct.scan.x_axis); % size( PSFs, 2);
        end
        PSFs = reshape( PSFstruct.data, [szZ, szX, noAngs, length( newtimetab)] );
        currinds = 1:szZ;
    else                                % channel data
        PSFs = PSFstruct.data;
        szZ = PSFstruct.nSamps;
        szX = PSFstruct.nChannels;
        currinds = PSFstruct.currinds;
    end
    
    
    %% find max velocity and oversampling factor (?t,F)
    % according to: (?t,F < (?r/vmax))
    timeDiffVec = diff(flowField( kk).timetab);
    posDiffVec = sqrt( sum( diff(flowField( kk).postab, 1).^2, 2) );
    maxVel = max( posDiffVec./timeDiffVec);
    minFR = maxVel/s.dr; 
    currFact = ceil( minFR/s.firing_rate);
    overSampFactTab( kk ) = currFact;
    
    %% make realizations
    % Prep for regular temporal grid with interval (1/PRFfiring/overSampleFactor). 
    % Temp res should be high enough to avoid aliasing of the signal for the highest velocities
    % present, for which the overSamplingFactor is used.

    
    if s.useGPU
        try 
            timetab = gpuArray( newtimetab ); % 'Original' time-vector
            ts = gpuArray( (min(timetab):(1/s.firing_rate)/currFact:max(timetab) ).' ); % New (slow) time-vector
        catch gpuError
            disp( 'GPU error detected, you may set s.useGPU to 0 to run on CPU');
            throw( gpuError);
        end
    else
        timetab = newtimetab;
        ts = ( min(timetab):(1/s.firing_rate)/currFact:max(timetab) ).';
    end
    
    Nfft = 2*length(ts)+s.nrSamps*currFact*noAngs*s.nrReps+currFact*noAngs-1;
    
    % phase correction makes PSF interpolation more robust and less
    % dependent on small s.dr
    if isfield(s.PSF_params, 'phaseCorr')
        demodPhaseRad = interp1( timetab, s.PSF_params.phaseCorr, ts);
        if s.useGPU
            modPhase = gpuArray( exp(1i*2*pi*s.PSF_params.phaseCorr ) );
        else
            modPhase = exp(1i*2*pi*s.PSF_params.phaseCorr );
        end
        demodPhase = exp( -1i*2*pi*demodPhaseRad);
    else
        modPhase = ones(1, noAngs);
        demodPhase = ones( 1, noAngs);
    end
    
    

    for anglectr = 1:noAngs

        if kk == 1 && anglectr == 1
            realTab = complex( zeros( szZ, szX, s.nrSamps, noAngs, s.nrReps, 'single') ); % pre-allocate
        end
    
        if anglectr == 1
            % Create noise function n(t)
            % Each value n(t) is a real valued random variable with Gaussian distribution and represents the amplitude of
            % scatterers with a time lag t
            fNoiseTab = randn( [length(ts)+s.nrSamps*currFact*noAngs*s.nrReps+currFact*noAngs 1], 'single');

            if isfield(s, 'contrastMode') && s.contrastMode
                fN_sort = sort( abs( fNoiseTab(:) ) );
                fN_thresh = fN_sort( round( length( fN_sort)*(1-s.contrastDensity) ) );
                fNoiseTab = single( abs(fNoiseTab) >= fN_thresh );
            end

            fNoiseTab = fNoiseTab/sqrt( length( ts) );
            
            if s.useGPU
                fNoiseTab = fft( fNoiseTab, Nfft, 1 );
                fNoiseTab_GPU = gpuArray( fNoiseTab);
            end
        end

        for coffset = 1:s.chunksize:szX
            
            % chunking of scanlines/columns
            cinds = coffset:min( coffset+s.chunksize-1, szX );

            % interpolate to regular grid with interval ?t,F.
            % myData_int = hF(r,t), function hF of time and space
            % describing the received signal from an single scatterer
            % moving along F
            permuteMyData = permute( PSFs(:,cinds,anglectr,:), [4 1 2 3]);
            permuteMyData = permuteMyData(:, :);
%             myData_int = interp1( timetab, permuteMyData, ts, 'linear');
            myData_int = interp1( timetab, permuteMyData.*modPhase(:,anglectr), ts, 'linear').*demodPhase(:,anglectr);

            % FFT of function hF

            % 1) convolution between hF and a noise function n
            % 2) IFT --> result: signal from a collection of point
            % scatterers following flowline kk
%             fft_myData = fft( myData_int, Nfft, 1);
            if s.useGPU
                fft_myData = fft( myData_int, Nfft, 1);
                fullRealization = ifft( fft_myData .* fNoiseTab_GPU, [], 1);
            else
                fullRealization = conv2( fNoiseTab, myData_int, 'full');
            end
            fullRealization = permute( fullRealization, [2 1]);
            fullRealization = reshape( fullRealization, [], length( cinds), size( fullRealization,2));

            
            % Adding of resulting signals to produce a full realization,
            % and apllying flowline weighting
            totdist = sum( sqrt( sum( diff( flowField(kk).postab,1).^2, 2 ) ), 1); % D(k), length of flowline
            totsamp = length( ts); % represents T(k), time it takes for one scatterer to pass through flowline
            weight = totdist/sqrt(totsamp); % weighting factor for flowline k, W(k)
            realTab(currinds,cinds,:, anglectr, : ) = realTab(currinds,cinds,:, anglectr, : )+...
                gather( weight*reshape( fullRealization(:,:,length(ts)+(anglectr-1)*currFact+(0:currFact*noAngs:s.nrReps*s.nrSamps*currFact*noAngs-1),:), ...
                [], length( cinds), s.nrSamps, 1, s.nrReps) );

            clc
            disp(['Flow line ' num2str(kk) '/' num2str(length( flowField) )] );
            disp(['Firing nr ' num2str(anglectr) '/' num2str(noAngs)] );
            disp(['Image line ' num2str( coffset ) '/' num2str( szX) ] );
        end
    end
end
clc
disp('Finished!')