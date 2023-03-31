function validate_autocorr(assessParams)
    % Standardized way of showing performance of velocity estimator, using the
    % true velocities from the phantom definition as reference. Function
    % uses a structure with the following fields:
    %
    % - vxEst: estimated velocities in form [Nx, Nz, Nreals]
    % - vzEst: estimated velocities in form [Nx, Nz, Nreals]
    % - scanMask: mask indicating valid estimator pixels (optional). Useful if phantom is only partly covered by valid scan zone (due to steering etc.)
    % - scatterDecimationFac: Decimation factor used in scatterplots
    % - biasPercentage: percentage of (directional) max velocity used in images of bias (default 10 percent)
    % - stdPercentage: percentage of (directional) max velocity used in images of std (default 10 percent)
    % date:               21.06.2022
    % modified by      :  Ingvild Kinn Ekroll <ingvild.k.ekroll@ntnu.no>
                      
    
    %% Input
    GT = evalin( 'base', 'GT');
    vAxEst = assessParams.result.vAxEst;               % [Nx, Nz, Na, Nreals]
    X = evalin( 'base', 'X');               % Grid used as input to phantom function (= scan grid)
    Z = evalin( 'base', 'Z');               % Grid used as input to phantom function (= scan grid)
    s = evalin( 'base', 's');
    
    Na = length(s.PSF_params.acq.alphaTx);  % number of transmits
    PRF = s.firing_rate/Na;
    f_demod = s.PSF_params.trans.f0;
    c = s.PSF_params.trans.c0;
    vNyq = PRF*c/(4*f_demod);

    if isfield( assessParams, 'SNR')
        SNR = assessParams.SNR;                     % SNR used in simulations
    else
        SNR = NaN;
    end
    
    % Scan dependent direction vector
    twoWayDopVec = -(s.PSF_params.phaseVecsTx+s.PSF_params.phaseVecsRx)/2;
        
    % Fields with default values
    if isfield(assessParams,'biasPercentage')
        bP = assessParams.biasPercentage;
    else
        bP = 10;
    end
    
    if isfield(assessParams,'stdPercentage')
        sP = assessParams.stdPercentage;
    else
        sP = 10;
    end
  
    if isfield(assessParams,'scanMask')
        scanMask = assessParams.scanMask;
    else
        scanMask = ones(size(X));
    end
    

    %% Find bias and standard deviation in all pixels
    % True velocities
    GTAx = GT*twoWayDopVec;

    vAxGT = reshape( GTAx, [size(X,1) size(X,2) Na] );    
    vAxGT_aliased = mod( vAxGT+vNyq, 2*vNyq)-vNyq;
    
    for kk = 1:Na
        vAxGTKK = vAxGT(:,:,kk);
        vAxGTKK_aliased = vAxGT_aliased(:,:,kk);
        
        vAxEstKK = squeeze(vAxEst(:,:,kk,:));
        
        % Mask based on true velocities from phantom
        phantomMask  = ones(size(vAxGTKK));
        phantomMask(isnan(vAxGTKK)) = NaN;

        % Combine masks
        myMask = phantomMask.*scanMask;

        % Estimated velocities, vxEst = [Nz,Nx,Nreals], vzEst = [Nz,Nx,Nreals]
        vAxEstMean = mean(vAxEstKK,3);

        if size(vAxEstKK,3)==1
            vAxSTD = NaN*ones(size(vAxEstMean));
        else
            vAxSTD = std(vAxEstKK,0,3,'omitnan');
        end

        vAxBias = vAxEstMean-vAxGTKK;


        %% Plot results
        % Mean and standard deviation of estimates
        %maxVaxGTVal = ceil(sign(max(vAxGTKK(:)))*max(abs(vAxGTKK(:)))*100);
        maxVaxGTVal = max(abs(vAxGTKK(:)))*100;

        % Figure limits
        tempX = X(myMask==1);
        xmin = min(tempX(:));
        xmax = max(tempX(:));

        tempZ = Z(myMask==1);
        zmin = min(tempZ(:));
        zmax = max(tempZ(:));

        figure(200);
%         set(gcf, 'units','normalized','outerposition',[0 0.5 1 0.5])
        set(gcf,'Position',[10 10 1420 837]);
        fontSz = 12;

        subplot(Na,5,1+(kk-1)*5);imagesc(X(:)*1000,Z(:)*1000,vAxGTKK.*myMask*100); axis equal tight; 
        title(sprintf('Angle %i: NReals %i, SNR %i dB \n \n GT [cm/s]',kk,size(vAxEst,3),SNR));
        colorbar
        xlabel('[mm]'); ylabel('[mm]')
        xlim([xmin,xmax]*1000)
        ylim([zmin,zmax]*1000)
        caxis([-maxVaxGTVal maxVaxGTVal])
        set(gca,'FontSize',fontSz);
        
        subplot(Na,5,2+(kk-1)*5);imagesc(X(:)*1000,Z(:)*1000,vAxGTKK_aliased.*myMask*100); axis equal tight; 
        title(sprintf('GT w/aliasing [cm/s]'));
        colorbar
        xlabel('[mm]'); ylabel('[mm]')
        xlim([xmin,xmax]*1000)
        ylim([zmin,zmax]*1000)
        caxis([-vNyq vNyq]*100)
        set(gca,'FontSize',fontSz);

        subplot(Na,5,3+(kk-1)*5);imagesc(X(:)*1000,Z(:)*1000,vAxEstMean.*myMask*100); axis equal tight; 
        title(sprintf('vAxEst [cm/s]')); 
        colorbar
        xlabel('[mm]'); ylabel('[mm]')
        xlim([xmin,xmax]*1000)
        ylim([zmin,zmax]*1000)
        caxis([-vNyq vNyq]*100)
        set(gca,'FontSize',fontSz);

        subplot(Na,5,4+(kk-1)*5);imagesc(X(:)*1000,Z(:)*1000,vAxBias.*myMask*100); axis equal tight; 
        title(sprintf('Bias: \n Mean = %0.2f cm/s',mean(vAxBias(:).*myMask(:),'omitnan')*100')); 
        colorbar
        xlabel('[mm]'); ylabel('[mm]')
        xlim([xmin,xmax]*1000)
        ylim([zmin,zmax]*1000)
        caxis(vNyq*100*[-bP/2 bP/2]./100)
        set(gca,'FontSize',fontSz);

        
        subplot(Na,5,5+(kk-1)*5);imagesc(X(:)*1000,Z(:)*1000,vAxSTD.*myMask*100); axis equal tight; 
        title(sprintf('Std: \n Mean = %0.2f cm/s',mean(vAxSTD(:).*myMask(:),'omitnan')*100));
        colorbar
        xlim([xmin,xmax]*1000)
        ylim([zmin,zmax]*1000)
        xlabel('[mm]'); ylabel('[mm]')
        caxis(vNyq*100*[0 sP]./100)
        set(gca,'FontSize',fontSz);


        % Scatterplots
        figure(201);
%         set(gcf, 'units','normalized','outerposition',[0.5 0 0.5 0.5])
        set(gcf,'Position',[10 10 772 764])
        decFac = assessParams.scatterDecimationFac;

        temp = vAxEstMean.*myMask;
        tempGT = vAxGTKK.*myMask;
        subplot(2,Na,1+(kk-1)*Na); hold off; plot(tempGT(1:decFac:end)*100,temp(1:decFac:end).*100,'x');
        axis equal tight
        xlim([-1 1]*abs(maxVaxGTVal))
        ylim([-1 1]*abs(maxVaxGTVal))
        hold on
        plot(xlim,ylim,'--k')
        xlabel('GT [cm/s]')
        ylabel('Estimate [cm/s]')
        title(sprintf('Angle %i: NReals %i, SNR %i dB \n \n',kk,size(vAxEstKK,3),SNR));
        set(gca,'FontSize',fontSz);
        grid on;
        
        temp = vAxEstMean.*myMask;
        tempGT = vAxGTKK_aliased.*myMask;
        subplot(2,Na,2+(kk-1)*Na); hold off; plot(tempGT(1:decFac:end)*100,temp(1:decFac:end).*100,'x');
        axis equal tight
        xlim([-1 1]*vNyq*100)
        ylim([-1 1]*vNyq*100)
        hold on
        plot(xlim,ylim,'--k')
        xlabel('Aliased GT [cm/s]')
        ylabel('Estimate [cm/s]')
%        title(sprintf('NReals %i, SNR %i dB \n \n',size(vAxEstKK,3),SNR));
        set(gca,'FontSize',fontSz);
        grid on;
        
    end
    
end
    
