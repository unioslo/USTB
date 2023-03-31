function [C_, CNR_, MSR_, GCNR_, AUC_, nunu, GCNR0, C0]=errorBarContrast(M, SNR, b_data, mask_o, mask_i, my_title,fgr_handls)

matlab_blue = [0 0.4470 0.7410];

CE=[];
CNRE=[];
MSR=[];
GCNR=[];
AUC=[];

for n=1:b_data.N_frames
    Pf=[];
    Pd=[];
    
    img=abs(reshape(b_data.data(:,1,1,n),[b_data.scan.N_z_axis b_data.scan.N_x_axis]));
    
    if n==b_data.N_frames%ismember(n,1:10:100)
        figure;
        imagesc(b_data.scan.x_axis*1e3,b_data.scan.z_axis*1e3, 20*log10(img)); colormap gray; axis equal tight; colorbar;
        caxis(20*log10(prctile(img(:),99)) + [-60 0] )
        set(gca,'FontSize', 14);
        xlabel('x[mm]');
        ylabel('z[mm]');
        title(sprintf("%s %0.2f dB", my_title, 10*log10(SNR(n))));
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

%     if n==71
%         figure;
%         plot(x,pdf_i./sum(pdf_i),'r-', 'linewidth',2); hold on; grid on;
%         plot(x,pdf_o./sum(pdf_o),'b-', 'linewidth',2); 
%         hh=area(x,min([pdf_i./sum(pdf_i); pdf_o./sum(pdf_o)]), 'LineStyle','none');
%         hh.FaceColor = [0.6 0.6 0.6];
%         xlabel('||s||');
%         ylabel('Probability');
%         legend('p_i','p_o','OVL');
%         title(sprintf("%s %0.2f dB", my_title, 10*log10(SNR(n))));
%         set(gca,'FontSize', 14);
%     end
    
    OVL(n)=sum(min([pdf_i./sum(pdf_i); pdf_o./sum(pdf_o)]));
    MSR(n) = 1 - OVL(n)/2;
    GCNR(n)= 1 - OVL(n);

    %% area under curve
    Pd=cumsum(pdf_i)./sum(pdf_i); % oposite because the cysts is black
    Pf=cumsum(pdf_o)./sum(pdf_o);
    
    % ROC
%     if(n==90)
%         figure(1);
%         plot(Pf,Pd,'b.-','linewidth',2); hold on; grid on; axis equal;
%         xlabel('P_{F}');
%         ylabel('P_{D}');
%         set(gca,'FontSize', 14);
%         xlim([0 1])
%         ylim([0 1])
%     end
    
    % PS
    AUC(n)=sum(Pd(1:end-1).*abs(diff(Pf)));
    
end

CEm = 10*log10(reshape(CE,size(SNR)));
C_ = [mean(CEm,1); std(CEm,1)];

CNREm = reshape(CNRE,size(SNR));
CNR_ = [mean(CNREm,1); std(CNREm,1)];

MSRm = reshape(MSR,size(SNR));
MSR_ = [mean(MSRm,1); std(MSRm,1)];

GCNRm = reshape(GCNR,size(SNR));
GCNR_ = [mean(GCNRm,1); std(GCNRm,1)];

AUCm = reshape(AUC,size(SNR));
AUC_ = [mean(AUCm,1); std(AUCm,1)];


%% theory
SNRdB=10*log10(SNR(1,:));
nunu = 10.^(linspace(min(SNRdB),max(SNRdB),100)/10);

C0 = @(snr) 3./(2*M*snr+3);
CNR0 = @(c) abs(c -1)./sqrt(c.^2+1);
pmax = @(c) 0.5+ 0.5*( c.^-(c./(c-1)) - c.^(-1./(c-1)));
GCNR0 = @(c) c.^-(c./(c-1)) - c.^(-1./(c-1));


%% C
figure;
plot(10*log10(nunu),10*log10(C0(nunu)),'r--','linewidth',2); hold on; grid on; axis tight square;
errorbar(SNRdB,C_(1,:),C_(2,:) ,'o','linewidth',2, 'MarkerFaceColor', matlab_blue); 
set(gca,'FontSize', 12);
xlabel('SNR_1 [dB]');
ylabel('C');
legend('Eq.(25)','Field II','Location','SouthWest')
title(my_title);
set(gca,'FontSize', 14);

%% CNR
figure;
plot(10*log10(nunu),CNR0(C0(nunu)),'r--','linewidth',2); hold on; grid on; axis tight square;
errorbar(SNRdB,CNR_(1,:),CNR_(2,:) ,'o','linewidth',2, 'MarkerFaceColor', matlab_blue); 
set(gca,'FontSize', 12);
ylim([0 max([max(CNRE) 1])])
xlabel('SNR_1 [dB]');
ylabel('CNR');
legend('Eq.(26)','Field II','Location','SouthEast')
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
plot(10*log10(nunu),GCNR0(C0(nunu)),'r--','linewidth',2); hold on; grid on; axis tight square;
errorbar(SNRdB,GCNR_(1,:),GCNR_(2,:) ,'o','linewidth',2, 'MarkerFaceColor', matlab_blue); 
set(gca,'FontSize', 12);
ylim([0 1])
xlabel('SNR_1 [dB]');
ylabel('GCNR');
legend('Eq.(34)','Field II','Location','SouthEast')
title(my_title);
set(gca,'FontSize', 14);

%% Area under curve
% figure;
% errorbar(SNRdB,AUC_(1,:),AUC_(2,:) ,'bo','linewidth',2, 'MarkerFaceColor', 'b'); hold on; grid on; axis tight square;
% errorbar(SNRdB,MSR_(1,:),MSR_(2,:) ,'ro','linewidth',2, 'MarkerFaceColor', 'r');
% plot(10*log10(nunu),pmax(C0(nunu)),'k--','linewidth',2); hold on; grid on; axis tight square;
% set(gca,'FontSize', 12);
% ylim([0.5 1])
% xlabel('SNR_1 [dB]');
% title(my_title);
% set(gca,'FontSize', 14);
% legend('Area under ROC','1-OVL/2','P_{max} theory','Location','SouthEast');

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
