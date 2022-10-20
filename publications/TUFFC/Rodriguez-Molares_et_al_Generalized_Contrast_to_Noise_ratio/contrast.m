function [CE, CNRE, MSR, GCNR, AUC, nunu, GCNR0, C0]=contrast(M, SNR, b_data, mask_o, mask_i, my_title)

CE=[];
CNRE=[];
MSR=[];
GCNR=[];
AUC=[];
for n=1:b_data.N_frames
    Pf=[];
    Pd=[];
    
    img=abs(reshape(b_data.data(:,1,1,n),[b_data.scan.N_z_axis b_data.scan.N_x_axis]));
    
    if n==20
        if strcmp(my_title,'SLSC')
            figure;
            imagesc(b_data.scan.x_axis*1e3,b_data.scan.z_axis*1e3, img); colormap gray; axis equal tight; colorbar;
            caxis([0 0.95])
            set(gca,'FontSize', 14);
            xlabel('x[mm]');
            ylabel('z[mm]');
            title(sprintf("%s %0.2f dB", my_title, 10*log10(SNR(n))));
        else
            figure;
            imagesc(b_data.scan.x_axis*1e3,b_data.scan.z_axis*1e3, 20*log10(img)); colormap gray; axis equal tight; colorbar;
            caxis(20*log10(prctile(img(:),99)) + [-60 0] )
            set(gca,'FontSize', 14);
            xlabel('x[mm]');
            ylabel('z[mm]');
            title(sprintf("%s %0.2f dB", my_title, 10*log10(SNR(n))));
        end
    end
   
    %% clasic
    mu_i=mean(img(mask_i).^2);
    mu_o=mean(img(mask_o).^2);
    v_i=var(img(mask_i).^2);
    v_o=var(img(mask_o).^2);
    
    CE(n)=mu_i./mu_o;
    CNRE(n)=abs(mu_i-mu_o)/sqrt(v_i+v_o);

    %% Pmax
    x=linspace(min(img(:)),max(img(:)),100);

    [pdf_i]=hist(img(mask_i),x);      
    [pdf_o]=hist(img(mask_o),x);

%     if n==14
%         figure;
%         plot(x,pdf_i./sum(pdf_i),'r-', 'linewidth',2); hold on; grid on;
%         plot(x,pdf_o./sum(pdf_o),'b-', 'linewidth',2); 
%         hh=area(x,min([pdf_i./sum(pdf_i); pdf_o./sum(pdf_o)]));
%         hh.FaceColor = [0.6 0.6 0.6];
%         xlabel('||s||');
%         ylabel('Probability');
%         set(gca,'FontSize', 14);
%         legend('p_i','p_o','OVL');
%     end
    
    OVL(n)=sum(min([pdf_i./sum(pdf_i); pdf_o./sum(pdf_o)]));
    MSR(n) = 1 - OVL(n)/2;
    GCNR(n)= 1 - OVL(n);

    %% area under curve
    
    Pd=1-cumsum(pdf_i)./sum(pdf_i);
    Pf=1-cumsum(pdf_o)./sum(pdf_o);
    
%     % ROC
%     figure(1);
%     plot(Pf,Pd,'b.-','linewidth',2); hold on; grid on; axis equal;
%     xlabel('P_{F}');
%     ylabel('P_{D}');
%     set(gca,'FontSize', 14);
%     xlim([0 1])
%     ylim([0 1])
    
    % PS
    AUC(n)=sum(Pd(1:end-1).*abs(diff(Pf)));
    
end

%% theory
SNRdB=10*log10(SNR);
nunu = 10.^(linspace(min(SNRdB),max(SNRdB),100)/10);

C0 = @(snr) 3./(2*M*snr+3);
CNR0 = @(c) abs(c -1)./sqrt(c.^2+1);
pmax = @(c) 0.5+ 0.5*( c.^-(c./(c-1)) - c.^(-1./(c-1)));
GCNR0 = @(c) c.^-(c./(c-1)) - c.^(-1./(c-1));


%% C
figure
plot(10*log10(SNR),10*log10(CE),'bo','MarkerSize',7, 'MarkerFaceColor', 'b'); hold on;
plot(10*log10(nunu),10*log10(C0(nunu)),'r--','linewidth',2); hold on; grid on; axis tight square;
set(gca,'FontSize', 12);
%ylim([0 max([max(CNRE) 1])])
xlabel('10 log_{10} \nu_S/\nu_N');
ylabel('C');
legend('Field II','Eq.(25)','Location','SouthWest')
title(my_title);
set(gca,'FontSize', 14);

%% CNR
figure;
plot(10*log10(SNR),CNRE,'bo','MarkerSize',7, 'MarkerFaceColor', 'b'); hold on;
plot(10*log10(nunu),CNR0(C0(nunu)),'r--','linewidth',2); hold on; grid on; axis tight square;
set(gca,'FontSize', 12);
ylim([0 max([max(CNRE) 1])])
xlabel('10 log_{10} \nu_S/\nu_N');
ylabel('CNR');
legend('Field II','Eq.(26)','Location','SouthEast')
title(my_title);
set(gca,'FontSize', 14);

%% Pmax
% figure;
% plot(10*log10(SNR),MSR,'bo','MarkerSize',7, 'MarkerFaceColor', 'b'); hold on;
% plot(10*log10(nunu),pmax(C0(nunu)),'r--','linewidth',2); hold on; grid on; axis tight square;
% set(gca,'FontSize', 12);
% ylim([0.5 1])
% xlabel('10 log_{10} \nu_S/\nu_N');
% ylabel('P_{max}');
% legend('Field II','Eq.(33)','Location','SouthEast')
% title(my_title);
% set(gca,'FontSize', 14);

%% Pmax vs CNR
% figure;
% plot(CNRE,MSR,'bo','MarkerSize',7, 'MarkerFaceColor', 'b'); hold on;
% plot(CNR0(C0(nunu)),pmax(C0(nunu)),'r--','linewidth',2); hold on; grid on; axis tight square;
% set(gca,'FontSize', 12);
% ylim([0.5 1])
% xlabel('CNR');
% ylabel('P_{max}');
% legend('Field II','Eq.(33) vs Eq.(26)','Location','SouthEast')
% title(my_title);
% [rho,pval] = corr(CNRE.',MSR.','Type','Spearman');
% text(0.2, 0.9, sprintf("Spearman's corr= %0.1f%%",rho*100),'FontSize',12);
% set(gca,'FontSize', 14);

%% GCNR
figure;
plot(10*log10(SNR),GCNR,'bo','MarkerSize',7, 'MarkerFaceColor', 'b'); hold on;
plot(10*log10(nunu),GCNR0(C0(nunu)),'r--','linewidth',2); hold on; grid on; axis tight square;
set(gca,'FontSize', 12);
ylim([0 1])
xlabel('10 log_{10} \nu_S/\nu_N');
ylabel('GCNR');
legend('Field II','Eq.(34)','Location','SouthEast')
title(my_title);
set(gca,'FontSize', 14);

%% Area under curve
% figure;
% plot(10*log10(SNR),1-AUC,'bo','MarkerSize',7, 'MarkerFaceColor', 'b'); hold on;
% plot(10*log10(nunu),Pmax,'r--','linewidth',2); hold on; grid on; axis tight square;
% set(gca,'FontSize', 12);
% ylim([0.5 1])
% xlabel('10 log_{10} \nu_S/\nu_N');
% ylabel('Area under curve');
% legend('Field II','Eq.(33)','Location','SouthEast')
% title(my_title);
% set(gca,'FontSize', 14);

% %% Variation
% deviation = (GCNR-GCNR0(C0(SNR)))*100;
% mean(deviation)
% std(deviation)
% max(deviation)
% min(deviation)
% 
% figure;
% plot(10*log10(SNR), deviation, 'bo','MarkerSize',7, 'MarkerFaceColor', 'b'); hold on; grid on;
% plot(10*log10(SNR), mean(deviation)+0.*SNR, 'k-');
% plot(10*log10(SNR), mean(deviation)+std(deviation)+0.*SNR, 'k--');
% plot(10*log10(SNR), mean(deviation)-std(deviation)+0.*SNR, 'k--');
% set(gca,'FontSize', 12);
% xlabel('10 log_{10} \nu_S/\nu_N');
% ylabel('% deviation of P_{max}');
% title(my_title);
% set(gca,'FontSize', 14);
