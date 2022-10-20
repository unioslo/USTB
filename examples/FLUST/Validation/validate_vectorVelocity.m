function validate_vectorVelocity(assessParams)
    % Standardized way of showing performance of velocity estimator, using the
    % true velocities from the phantom definition as reference. Function
    % uses a structure with the following fields:
    %
    % - vxEst: estimated velocities in form [Nz, Nx, Nreals]
    % - vzEst: estimated velocities in form [Nz, Nx, Nreals]
    % - scanMask: mask indicating valid estimator pixels (optional). Useful if phantom is only partly covered by valid scan zone (due to steering etc.)
    % - scatterDecimationFac: Decimation factor used in scatterplots
    % - biasPercentage: percentage of (directional) max velocity used in images of bias (default 10 percent)
    % - stdPercentage: percentage of (directional) max velocity used in images of std (default 10 percent)
    % date:               21.06.2022
    % modified by      :  Ingvild Kinn Ekroll <ingvild.k.ekroll@ntnu.no>
                      
    
    %% Input
    GT = evalin( 'base', 'GT');
    vxEst = assessParams.result.vxEst;               % [Nz, Nx, Nreals]
    vzEst = assessParams.result.vzEst;               % [Nz, Nx, Nreals]

    X = evalin( 'base', 'X');               % Grid used as input to phantom function (= scan grid)
    Z = evalin( 'base', 'Z');               % Grid used as input to phantom function (= scan grid)
    
    SNR = assessParams.SNR;      % SNR used in simulations
    
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
  

    %% Find bias and standard deviation in all pixels
    % True velocities
    GT_rsh = reshape( GT, [size(X,1) size(X,2) 1 3] );

    vxGT = GT_rsh(:,:,1,1);
    vzGT = GT_rsh(:,:,1,3);
    vMagGT = sqrt(vxGT.^2 +vzGT.^2);

    % Mask based on true velocities from phantom
    phantomMask  = ones(size(vMagGT));
    phantomMask(isnan(vMagGT)) = NaN;

    if isfield(assessParams,'scanMask')
        scanMask = assessParams.scanMask;
    else
        scanMask = ones(size(phantomMask));
    end

    % Combine masks
    myMask = phantomMask.*scanMask;


    % Estimated velocities, vxEst = [Nz,Nx,Nreals], vzEst = [Nz,Nx,Nreals]
    vxMean = mean(vxEst,3);
    vzMean = mean(vzEst,3);

    vMag = sqrt(vxMean.^2 +vzMean.^2);


    if size(vxEst,3)==1
        vxSTD = NaN*ones(size(vMag));
        vzSTD = NaN*ones(size(vMag));
    else
        vxSTD = std(vxEst,0,3,'omitnan');
        vzSTD = std(vzEst,0,3,'omitnan');
    end

    vxBias = vxMean-vxGT;
    vzBias = vzMean-vzGT;
    
    
    %% Plot results
    % Mean and standard deviation of estimates
    maxVzVal = ceil(sign(max(vzGT(:)))*max(abs(vzGT(:)))*100);
    maxVxVal = ceil(sign(max(vxGT(:)))*max(abs(vxGT(:)))*100);
    maxVmagVal = max(abs(vMagGT(:)))*100;
    
    % Figure limits
    tempX = X(myMask==1);
    xmin = min(tempX(:));
    xmax = max(tempX(:));
    
    tempZ = Z(myMask==1);
    zmin = min(tempZ(:));
    zmax = max(tempZ(:));
    
    
    figure(300);
%     set(gcf, 'units','normalized','outerposition',[0.5 0.5 0.5 0.5])
    set(gcf,'Position',[10 10 1188 626]);
    fontSz = 12;
    
    subplot(2,3,1);imagesc(X(:)*1000,Z(:)*1000,vxMean.*myMask*100); axis equal tight; 
    title(sprintf('NReals %i, SNR %i dB \n \n VxEst [cm/s]',size(vxEst,3),SNR));
    colorbar
    xlabel('[mm]'); ylabel('[mm]')
    xlim([xmin,xmax]*1000)
    ylim([zmin,zmax]*1000)
    caxis([0 maxVxVal])
    set(gca,'FontSize',fontSz);

    subplot(2,3,2);imagesc(X(:)*1000,Z(:)*1000,vxBias.*myMask*100); axis equal tight; 
    title(sprintf('Mean vx bias: %0.2f cm/s',mean(vxBias(:).*myMask(:),'omitnan')*100')); 
    colorbar
    xlabel('[mm]'); ylabel('[mm]')
    xlim([xmin,xmax]*1000)
    ylim([zmin,zmax]*1000)
    caxis(maxVxVal*[-bP/2 bP/2]./100)
    set(gca,'FontSize',fontSz);

    subplot(2,3,3);imagesc(X(:)*1000,Z(:)*1000,vxSTD.*myMask*100); axis equal tight; 
    title(sprintf('Mean vx std: %0.2f cm/s',mean(vxSTD(:).*myMask(:),'omitnan')*100));
    colorbar
    xlim([xmin,xmax]*1000)
    ylim([zmin,zmax]*1000)
    xlabel('[mm]'); ylabel('[mm]')
    caxis(maxVxVal*[0 sP]./100)
    set(gca,'FontSize',fontSz);

    subplot(2,3,4);imagesc(X(:)*1000,Z(:)*1000,vzMean.*myMask*100); axis equal tight; 
    title(sprintf('VzEst [cm/s]'));  
    colorbar
    xlim([xmin,xmax]*1000)
    ylim([zmin,zmax]*1000)
    xlabel('[mm]'); ylabel('[mm]')
    caxis([maxVzVal 0])
    set(gca,'FontSize',fontSz);


    subplot(2,3,5);imagesc(X(:)*1000,Z(:)*1000,vzBias.*myMask*100); axis equal tight; 
    title(sprintf('Mean vz bias: %0.2f cm/s',mean(vzBias(:).*myMask(:),'omitnan')*100))
    colorbar
    xlim([xmin,xmax]*1000)
    ylim([zmin,zmax]*1000)
    xlabel('[mm]'); ylabel('[mm]')
    caxis(abs(maxVzVal)*[-bP/2 bP/2]./100)
    set(gca,'FontSize',fontSz);

    
    subplot(2,3,6);imagesc(X(:)*1000,Z(:)*1000,vzSTD.*myMask*100); axis equal tight; 
    title(sprintf('Mean vz std: %0.2f cm/s',mean(vzSTD(:).*myMask(:),'omitnan')*100)); colorbar
    xlim([xmin,xmax]*1000)
    ylim([zmin,zmax]*1000)
    xlabel('[mm]'); ylabel('[mm]')
    caxis(abs(maxVzVal)*[0 sP]./100)

    set(gca,'FontSize',fontSz);
    
    % Scatterplots
    
    figure(301);
%     set(gcf, 'units','normalized','outerposition',[0.5 0 0.5 0.5])
    set(gcf,'Position',[10 10 958 373])
    decFac = assessParams.scatterDecimationFac;
    
    temp = vMag.*myMask;
    tempGT = vMagGT.*myMask;
    subplot(1,3,1); hold off; plot(tempGT(1:decFac:end)*100,temp(1:decFac:end).*100,'x');
    axis equal tight
    xlim([0 1]*maxVmagVal)
    ylim([0 1]*maxVmagVal)
    hold on
    plot(xlim,ylim,'--k')
    xlabel('GT [cm/s]')
    ylabel('Estimate [cm/s]')
    title(sprintf('NReals %i, SNR %i dB \n \n VMag',size(vxEst,3),SNR));
    set(gca,'FontSize',fontSz);
    grid on;

    temp = vxMean.*myMask;
    tempGT = vxGT.*myMask;
    subplot(1,3,2); hold off; plot(tempGT(1:decFac:end)*100,temp(1:decFac:end).*100,'x');
    axis equal tight
    xlim([-1 1]*maxVxVal)
    ylim([-1 1]*maxVxVal)
    hold on
    plot(xlim,ylim,'--k')
    xlabel('GT [cm/s]')
    ylabel('Estimate [cm/s]')
    title('Vx')
    set(gca,'FontSize',fontSz);
    grid on;

    temp = vzMean.*myMask;
    tempGT = vzGT.*myMask;
    subplot(1,3,3); hold off; plot(tempGT(1:decFac:end)*100,temp(1:decFac:end).*100,'x');
    axis equal tight
    xlim([-1 1]*abs(maxVzVal))
    ylim([-1 1]*abs(maxVzVal))
    hold on
    plot(xlim,ylim,'--k')
    xlabel('GT [cm/s]')
    ylabel('Estimate [cm/s]')
    title('Vz')
    set(gca,'FontSize',fontSz);
    grid on;


    
end
    
