%% FLUST main loop
for kk = 1:length(flowField)

    %% resample along flowlines with density s.dr
    prop = diff( flowField(kk).postab, 1);
    propdist = [0; cumsum( sqrt( sum( prop.^2, 2 ) ), 1 ) ];
    newdists = 0:s.dr:max(propdist);
    newtimetab = interp1( propdist, flowField(kk).timetab, newdists);
    newpostab = interp1( flowField(kk).timetab, flowField(kk).postab, newtimetab);

    %% calculate PSFs at each position (newpostab) along flowline kk
    simStart = tic;
    [PSFstruct,p] = s.PSF_function(newpostab, s.PSF_params); % PSFs in uff/beamformed_data format
    s.PSF_params = p;
    AsimTime = toc(simStart);

    %% reshape PSF data
    noAngs = size( PSFstruct.data, 3);
    if isa( PSFstruct.scan, 'uff.sector_scan')
        szZ = length(PSFstruct.scan.depth_axis); % size( PSFs, 1);
        szX = length(PSFstruct.scan.azimuth_axis); % size( PSFs, 2);
    elseif isa( PSFstruct.scan, 'uff.linear_scan') || isa( PSFstruct.scan, 'uff.linear_scan_rotated')
        szZ = length(PSFstruct.scan.z_axis); % size( PSFs, 1);
        szX = length(PSFstruct.scan.x_axis); % size( PSFs, 2);
    end
    PSFs = reshape( PSFstruct.data, [szZ, szX, noAngs, length( newtimetab)] );
    
    %% AS, temp - Visually check PSFs for both angles
    if 0
        % Create beamform grids (again)
        % Center of rotation
        xc = p.scan.xStart+((p.scan.xEnd-p.scan.xStart)/2);
        zc = p.scan.zStart + ((p.scan.zEnd-p.scan.zStart)/2);
        % Create scan
        sca = cell(1,noAngs);
        for a = 1:noAngs
            sca{a} = uff.linear_scan_rotated('x_axis',linspace(p.scan.xStart,p.scan.xEnd,p.scan.Nx).', 'z_axis', linspace(p.scan.zStart,p.scan.zEnd,p.scan.Nz).', 'rotation_angle', p.acq.alphaTx(a) ,'center_of_rotation',[xc,0,zc]');
        end
        
        
        for a = 1: noAngs
            figure()
%             subplot(1,noAngs,a)
            pcolor(reshape(sca{a}.x*1000, [sca{a}.N_x_axis sca{a}.N_z_axis]), reshape(sca{a}.z*1000,[sca{a}.N_x_axis sca{a}.N_z_axis] ), abs(PSFs(:,:,a,30))), shading interp
            set(gca,'ydir','reverse')
            xlabel('X (mm)'), ylabel('Z (mm)')
            axis image
            title(['Single PSF, angle ', num2str(a), '/', num2str(noAngs)])
        end
    end

    %% make realizations
 
    
    % Prep for regular temporal grid with interval (1/PRFfiring/overSampleFactor). 
    % Temp res should be high enough to avoid aliasing of the signal for the highest velocities
    % present, for which the overSamplingFactor is used.
    % 'Original' time-vector
    timetab = gpuArray( newtimetab );
    % New (slow) time-vector
    ts = gpuArray( min(timetab):(1/s.firing_rate)/s.overSampFact:max(timetab) );

    Nfft = 2*length(ts)+s.nrSamps*s.overSampFact*noAngs*s.nrReps+s.overSampFact*noAngs-1;
    
    
    % phase correction makes PSF interpolation more robust and less
    % dependent on small s.dr
    if isfield(s.PSF_params, 'phaseCorr')
        demodPhaseRad = interp1( timetab, s.PSF_params.phaseCorr, ts);
        modPhase = gpuArray(exp(1i*2*pi*s.PSF_params.phaseCorr ) );
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
            fNoiseTab = randn( [length(ts)+s.nrSamps*s.overSampFact*noAngs*s.nrReps+s.overSampFact*noAngs 1], 'single');

            if contrastMode
                fN_sort = sort( abs( fNoiseTab(:) ) );
                fN_thresh = fN_sort( round( length( fN_sort)*(1-contrastDensity) ) );
                fNoiseTab = single( abs(fNoiseTab) >= fN_thresh );
            end

            fNoiseTab = fNoiseTab/sqrt( length( ts) );
            fNoiseTab = fft( fNoiseTab, Nfft, 1 );

            fNoiseTab_GPU = gpuArray( fNoiseTab);
        end

        for coffset = 1:chunksize:szX
%             mm = 1; % not used?
            
            % chunking of scanlines/columns
            cinds = coffset:min( coffset+chunksize-1, szX );

            myData_GPU = gpuArray( PSFs(:,cinds,anglectr,:) );

            % interpolate to regular grid with interval ts.
            % myData_int = hF(r,t), function hF of time and space
            % describing the received signal from an single scatterer
            % moving along F
            permuteMyData = permute( myData_GPU, [4 1 2 3]);
            permuteMyData = permuteMyData(:, :);            
%             myData_int = interp1( timetab, permuteMyData, ts, 'linear');

            myData_int = interp1( timetab, permuteMyData.*modPhase(:,anglectr), ts, 'linear').*demodPhase(:,anglectr);

            
            % FFT of function hF

            % 1) convolution between hF and a noise function n
            % 2) IFT --> result: signal from a collection of point
            % scatterers following flowline kk
            fft_myData = fft( myData_int, Nfft, 1);
            fullRealization = ifft( fft_myData .* fNoiseTab_GPU, [], 1);

            fullRealization = permute( fullRealization, [2 1]);
            fullRealization = reshape( fullRealization, [szZ, length( cinds) size( fullRealization,2) ]);

            
            % Adding of resulting signals to produce a full realization
            totdist = sum( sqrt( sum( diff( flowField(kk).postab,1).^2, 2 ) ), 1);
            totsamp = length( ts);
            weight = totdist/sqrt(totsamp);
            realTab(:,cinds,:, anglectr, : ) = realTab(:,cinds,:, anglectr, : )+...
                gather( weight*reshape( fullRealization(:,:,length(ts)+(anglectr-1)*s.overSampFact+(0:s.overSampFact*noAngs:s.nrReps*s.nrSamps*s.overSampFact*noAngs-1),:), ...
                [szZ, length( cinds), s.nrSamps, 1, s.nrReps]) );

            clc
            disp(['Flow line ' num2str(kk) '/' num2str(length( flowField) )] );
            disp(['Firing nr ' num2str(anglectr) '/' num2str(noAngs)] );
            disp(['Image line ' num2str( coffset ) '/' num2str( szX) ] );
        end
    end
end
clc
disp('Finished!')