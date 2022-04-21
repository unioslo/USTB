%% FLUST main loop
for kk = 1:length(flowField)

    %% resample along flowlines with density s.dr
    prop = diff( flowField(kk).postab, 1);
    propdist = [0; cumsum( sqrt( sum( prop.^2, 2 ) ), 1 ) ];
    newdists = 0:s.dr:max(propdist);
    newtimetab = interp1( propdist, flowField(kk).timetab, newdists);
    newpostab = interp1( flowField(kk).timetab, flowField(kk).postab, newtimetab);

    %% calculate PSFs
    simStart = tic;
    [PSFstruct,p] = s.PSF_function(newpostab, s.PSF_params); % PSFs in uff/beamformed_data format
    s.PSF_params = p;
    AsimTime = toc(simStart);

    %% make realizations
    noAngs = size( PSFstruct.data, 3);
    for anglectr = 1:noAngs
        if isa( PSFstruct.scan, 'uff.sector_scan')
            szZ = length(PSFstruct.scan.depth_axis); % size( PSFs, 1);
            szX = length(PSFstruct.scan.azimuth_axis); % size( PSFs, 2);
        elseif isa( PSFstruct.scan, 'uff.linear_scan')
            szZ = length(PSFstruct.scan.z_axis); % size( PSFs, 1);
            szX = length(PSFstruct.scan.x_axis); % size( PSFs, 2);
        end

        PSFs = reshape( PSFstruct.data, [szZ, szX, noAngs, length( newtimetab)] );

        if kk == 1 && anglectr == 1
            realTab = complex( zeros( szZ, szX, s.nrSamps, noAngs, s.nrReps, 'single') );
        end

        timetab = gpuArray( newtimetab );

        ts = gpuArray( min(timetab):(1/s.firing_rate)/s.overSampFact:max(timetab) );
        Nfft = 2*length(ts)+s.nrSamps*s.overSampFact*noAngs*s.nrReps+s.overSampFact*noAngs-1;
        if anglectr == 1

            fNoiseTab = randn( [1 length( 1) length(ts)+s.nrSamps*s.overSampFact*noAngs*s.nrReps+s.overSampFact*noAngs ], 'single');

            if contrastMode
                fN_sort = sort( abs( fNoiseTab(:) ) );
                fN_thresh = fN_sort( round( length( fN_sort)*(1-contrastDensity) ) );
                fNoiseTab = single( abs(fNoiseTab) >= fN_thresh );
            end

            fNoiseTab = fNoiseTab/sqrt( length( ts) );
            fNoiseTab = fft( fNoiseTab, Nfft, 3 );

            fNoiseTab_GPU = gpuArray( fNoiseTab);
        end

        for coffset = 1:chunksize:szX
            mm = 1;
            cinds = coffset:min( coffset+chunksize-1, szX );

            myData_GPU = gpuArray( PSFs(:,cinds,anglectr,:) );

            permuteMyData = permute( myData_GPU, [4 1 2 3]);
            permuteMyData = permuteMyData(:, :);

            myData_int = interp1( timetab, permuteMyData, ts, 'linear');
            myData_int = permute( myData_int, [2 1]);
            myData_int = reshape( myData_int, [szZ, length( cinds) size( myData_int,2) ]);

            fft_myData = fft( myData_int, Nfft, 3);

            totdist = sum( sqrt( sum( diff( flowField(kk).postab,1).^2, 2 ) ), 1);
            totsamp = length( ts);
            weight = totdist/sqrt(totsamp);

            fullRealization = ifft( fft_myData .* fNoiseTab_GPU(1,1,:), [], 3);
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