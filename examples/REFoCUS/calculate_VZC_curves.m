function [outputArg1,outputArg2] = calculate_VZC_curves(b_data_FI_delayed, b_data_RTB_delayed, b_data_STAI_REFOCUS_delayed, scan)


%CALCULATE_VZC_CURVES Summary of this function goes here
%   Detailed explanation goes here
delayed_FI_data = reshape(b_data_FI_delayed.data,scan.N_depth_axis, scan.N_azimuth_axis, size(b_data_FI_delayed.data,2));
delayed_FI_data = delayed_FI_data./max(delayed_FI_data(:));

delayed_RTB_data = reshape(b_data_RTB_delayed.data,scan.N_depth_axis, scan.N_azimuth_axis,size(b_data_FI_delayed.data,2));
delayed_RTB_data = delayed_RTB_data./max(delayed_RTB_data(:));

%delayed_STAI_data = reshape(b_data_STAI_delayed.data,scan.N_depth_axis, scan.N_azimuth_axis,channel_data_FI_demod.N_channels);
%delayed_STAI_data = delayed_STAI_data./max(delayed_STAI_data(:));

delayed_STAI_REFOCUS_data = reshape(b_data_STAI_REFOCUS_delayed.data,scan.N_depth_axis, scan.N_azimuth_axis,size(b_data_FI_delayed.data,2));
delayed_STAI_REFOCUS_data = delayed_STAI_REFOCUS_data./max(delayed_STAI_REFOCUS_data(:));


%%
% SLSC on Receive Data After Transmit Focusing Everywhere
numLags =  size(b_data_FI_delayed.data,2)-1; % Number of Lags for SLSC
SLSCImg_from_FI = zeros([scan.N_depth_axis, scan.N_azimuth_axis, numLags]);
SLSCImg_from_RTB = zeros([scan.N_depth_axis, scan.N_azimuth_axis, numLags]);
%SLSCImg_from_STAI = zeros([scan.N_depth_axis, scan.N_azimuth_axis, numLags]);
SLSCImg_from_REFOCUS = zeros([scan.N_depth_axis, scan.N_azimuth_axis, numLags]);
SLSC = @(focData, lag) real( mean( ...
    (focData(:,:,1:end-lag).*conj(focData(:,:,lag+1:end))) ./ ...
    ( abs(focData(:,:,1:end-lag)).*abs(focData(:,:,lag+1:end)) ), 3) );
for lag = 1:numLags
    SLSCImg_from_FI(:,:,lag) = SLSC(delayed_FI_data, lag);
    SLSCImg_from_RTB(:,:,lag) = SLSC(delayed_RTB_data, lag);
 %   SLSCImg_from_STAI(:,:,lag) = SLSC(delayed_STAI_data, lag);
    SLSCImg_from_REFOCUS(:,:,lag) = SLSC(delayed_STAI_REFOCUS_data, lag);
    disp(['SLSC Lag = ', num2str(lag)]);
end
%%
[~,x_idx_10mm] = min(abs(scan.depth_axis-10/1000))
[~,x_idx_20mm] = min(abs(scan.depth_axis-20/1000))
[~,x_idx_22mm] = min(abs(scan.depth_axis-22/1000))
[~,x_idx_34mm] = min(abs(scan.depth_axis-34/1000))

% VCZ Curves at Two Depths

%%
VCZ1_FI_10mm = squeeze(mean(mean(SLSCImg_from_FI(x_idx_10mm-10:x_idx_10mm+10,70:110,:),1),2));
VCZ1_RTB_10mm = squeeze(mean(mean(SLSCImg_from_RTB(x_idx_10mm-10:x_idx_10mm+10,70:110,:),1),2));
%VCZ1_STAI_10mm = squeeze(mean(mean(SLSCImg_from_STAI(x_idx_10mm-10:x_idx_10mm+10,70:110,:),1),2));
VCZ1_REFOCUS_10mm = squeeze(mean(mean(SLSCImg_from_REFOCUS(x_idx_10mm-10:x_idx_10mm+10,70:110,:),1),2));

VCZ1_FI_20mm = squeeze(mean(mean(SLSCImg_from_FI(x_idx_20mm-10:x_idx_20mm+10,70:110,:),1),2));
VCZ1_RTB_20mm = squeeze(mean(mean(SLSCImg_from_RTB(x_idx_20mm-10:x_idx_20mm+10,70:110,:),1),2));
%VCZ1_STAI_20mm = squeeze(mean(mean(SLSCImg_from_STAI(x_idx_20mm-10:x_idx_20mm+10,70:110,:),1),2));
VCZ1_REFOCUS_20mm = squeeze(mean(mean(SLSCImg_from_REFOCUS(x_idx_20mm-10:x_idx_20mm+10,70:110,:),1),2));

% VCZ1_FI_22mm = squeeze(mean(mean(SLSCImg_from_FI(x_idx_22mm-10:x_idx_22mm+10,70:110,:),1),2));
% VCZ1_RTB_22mm = squeeze(mean(mean(SLSCImg_from_RTB(x_idx_22mm-10:x_idx_22mm+10,70:110,:),1),2));
% VCZ1_STAI_22mm = squeeze(mean(mean(SLSCImg_from_STAI(x_idx_22mm-10:x_idx_22mm+10,70:110,:),1),2));
% VCZ1_REFOCUS_22mm = squeeze(mean(mean(SLSCImg_from_REFOCUS(x_idx_22mm-10:x_idx_22mm+10,70:110,:),1),2));

VCZ1_FI_34mm = squeeze(mean(mean(SLSCImg_from_FI(x_idx_34mm-10:x_idx_34mm+10,70:110,:),1),2));
VCZ1_RTB_34mm = squeeze(mean(mean(SLSCImg_from_RTB(x_idx_34mm-10:x_idx_34mm+10,70:110,:),1),2));
%VCZ1_STAI_34mm = squeeze(mean(mean(SLSCImg_from_STAI(x_idx_34mm-10:x_idx_34mm+10,70:110,:),1),2));
VCZ1_REFOCUS_34mm = squeeze(mean(mean(SLSCImg_from_REFOCUS(x_idx_34mm-10:x_idx_34mm+10,70:110,:),1),2));

figure; 
subplot(311)
plot(VCZ1_FI_10mm, 'Linewidth', 2, 'DisplayName', 'FI'); hold on; 
plot(VCZ1_RTB_10mm, 'Linewidth', 2, 'DisplayName', 'RTB'); hold on; 
%plot(VCZ1_STAI_10mm, 'Linewidth', 2, 'DisplayName', 'STAI'); hold on; 
plot(VCZ1_REFOCUS_10mm,'--','Linewidth', 2, 'DisplayName', 'REFOCUS'); hold on; 
xlabel('lag'); ylabel('Coherence'); legend();title('At 10 mm');
subplot(312)
plot(VCZ1_FI_20mm, 'Linewidth', 2, 'DisplayName', 'FI'); hold on; 
plot(VCZ1_RTB_20mm, 'Linewidth', 2, 'DisplayName', 'RTB'); hold on; 
%plot(VCZ1_STAI_20mm, 'Linewidth', 2, 'DisplayName', 'STAI'); hold on; 
plot(VCZ1_REFOCUS_20mm,'--','Linewidth', 2, 'DisplayName', 'REFOCUS'); hold on; 
xlabel('lag'); ylabel('Coherence');;title('At 20 mm (focus)');
% subplot(413)
% plot(VCZ1_FI_22mm, 'Linewidth', 2, 'DisplayName', 'FI'); hold on; 
% plot(VCZ1_RTB_22mm, 'Linewidth', 2, 'DisplayName', 'RTB'); hold on; 
% plot(VCZ1_STAI_22mm, 'Linewidth', 2, 'DisplayName', 'STAI'); hold on; 
% plot(VCZ1_REFOCUS_22mm,'--','Linewidth', 2, 'DisplayName', 'REFOCUS'); hold on; 
% xlabel('lag'); ylabel('Coherence');
subplot(313)
plot(VCZ1_FI_34mm, 'Linewidth', 2, 'DisplayName', 'FI'); hold on; 
plot(VCZ1_RTB_34mm, 'Linewidth', 2, 'DisplayName', 'RTB'); hold on; 
%plot(VCZ1_STAI_34mm, 'Linewidth', 2, 'DisplayName', 'STAI'); hold on; 
plot(VCZ1_REFOCUS_34mm,'--','Linewidth', 2, 'DisplayName', 'REFOCUS'); hold on;
xlabel('lag'); ylabel('Coherence');;title('At 34 mm');

% %% Figure for abstract
% figure(999);clf
% b_data.plot(subplot(4,5,[1,6]),'(a) Scanline');xlim([-12 12])
% colormap(gca,gray)
% b_data_RTB.plot(subplot(4,5,[2,7]),'(b) RTB');xlim([-12 12])
% b_data_STAI.plot(subplot(4,5,[3,8]),'(c) STAI');xlim([-12 12])
% b_data_STAI_REFOCUS.plot(subplot(4,5,[4,9]),'(d) REFoCUS');xlim([-12 12])
% 
% subplot(4,5,5)
% bar(GCNR)
% ylim([0.97 1])
% xticklabels({'FI','RTB','STAI', 'REFOCUS'})
% title('(e) gCNR');
% xticklabels({'FI','RTB','STAI', 'REFoCUS'})
% a = get(gca,'XTickLabel');  
% set(gca,'XTickLabel',a,'fontsize',8)
% set(gca,'FontSize',12)
% xlim([0.5 4.5])
% cf_FI.CF.plot(subplot(4,5,[11,16]),'(f) CF Scanline',[],'none');xlim([-12 12])
% colormap(gca,parula)
% cf_RTB.CF.plot(subplot(4,5,[12,17]),'(g) CF RTB',[],'none');xlim([-12 12])
% colormap(gca,parula)
% cf_STAI.CF.plot(subplot(4,5,[13,18]),'(h) CF STAI',[],'none');xlim([-12 12])
% colormap(gca,parula)
% cf_REFOCUS.CF.plot(subplot(4,5,[14,19]),'(i) CF REFoCUS',[],'none');xlim([-12 12])
% colormap(gca,parula)
% 
% subplot(4,5,[10])
% plot(VCZ1_FI_10mm, 'Linewidth', 2, 'DisplayName', 'FI'); hold on; 
% plot(VCZ1_RTB_10mm, 'Linewidth', 2, 'DisplayName', 'RTB'); hold on; 
% plot(VCZ1_STAI_10mm, 'Linewidth', 2, 'DisplayName', 'STAI'); hold on; 
% plot(VCZ1_REFOCUS_10mm,'--','Linewidth', 2, 'DisplayName', 'REFoCUS'); hold on; 
% xlabel('lag'); ylabel('Coherence'); legend();title('(j) coherence at 10 mm');
% set(gca,'FontSize',12)
% subplot(4,5,[15])
% plot(VCZ1_FI_20mm, 'Linewidth', 2, 'DisplayName', 'FI'); hold on; 
% plot(VCZ1_RTB_20mm, 'Linewidth', 2, 'DisplayName', 'RTB'); hold on; 
% plot(VCZ1_STAI_20mm, 'Linewidth', 2, 'DisplayName', 'STAI'); hold on; 
% plot(VCZ1_REFOCUS_20mm,'--','Linewidth', 2, 'DisplayName', 'REFoCUS'); hold on; 
% xlabel('lag'); ylabel('Coherence');title('(k) coherence at 20 mm (focus)');
% set(gca,'FontSize',12)
% % subplot(413)
% % plot(VCZ1_FI_22mm, 'Linewidth', 2, 'DisplayName', 'FI'); hold on; 
% % plot(VCZ1_RTB_22mm, 'Linewidth', 2, 'DisplayName', 'RTB'); hold on; 
% % plot(VCZ1_STAI_22mm, 'Linewidth', 2, 'DisplayName', 'STAI'); hold on; 
% % plot(VCZ1_REFOCUS_22mm,'--','Linewidth', 2, 'DisplayName', 'REFOCUS'); hold on; 
% % xlabel('lag'); ylabel('Coherence');
% subplot(4,5,[20])
% plot(VCZ1_FI_34mm, 'Linewidth', 2, 'DisplayName', 'FI'); hold on; 
% plot(VCZ1_RTB_34mm, 'Linewidth', 2, 'DisplayName', 'RTB'); hold on; 
% plot(VCZ1_STAI_34mm, 'Linewidth', 2, 'DisplayName', 'STAI'); hold on; 
% plot(VCZ1_REFOCUS_34mm,'--','Linewidth', 2, 'DisplayName', 'REFoCUS'); hold on;
% xlabel('lag'); ylabel('Coherence');;title('(l) coherence at 34 mm');
% set(gca,'FontSize',12)
end

