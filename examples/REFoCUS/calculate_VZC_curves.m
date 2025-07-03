function calculate_VZC_curves(b_data_FI_delayed, b_data_RTB_delayed, b_data_STAI_REFOCUS_delayed, scan)
%CALCULATE_VZC_CURVES
delayed_FI_data = reshape(b_data_FI_delayed.data,scan.N_depth_axis, scan.N_azimuth_axis, size(b_data_FI_delayed.data,2));
delayed_FI_data = delayed_FI_data./max(delayed_FI_data(:));

delayed_RTB_data = reshape(b_data_RTB_delayed.data,scan.N_depth_axis, scan.N_azimuth_axis,size(b_data_RTB_delayed.data,2));
delayed_RTB_data = delayed_RTB_data./max(delayed_RTB_data(:));

delayed_STAI_REFOCUS_data = reshape(b_data_STAI_REFOCUS_delayed.data,scan.N_depth_axis, scan.N_azimuth_axis,size(b_data_STAI_REFOCUS_delayed.data,2));
delayed_STAI_REFOCUS_data = delayed_STAI_REFOCUS_data./max(delayed_STAI_REFOCUS_data(:));


%%
% SLSC on Receive Data After Transmit Focusing Everywhere
numLags =  size(b_data_FI_delayed.data,2)-1; % Number of Lags for SLSC
SLSCImg_from_FI = zeros([scan.N_depth_axis, scan.N_azimuth_axis, numLags]);
SLSCImg_from_RTB = zeros([scan.N_depth_axis, scan.N_azimuth_axis, numLags]);
SLSCImg_from_REFOCUS = zeros([scan.N_depth_axis, scan.N_azimuth_axis, numLags]);
SLSC = @(delayed_data, lag) real( mean( ...
    (delayed_data(:,:,1:end-lag).*conj(delayed_data(:,:,lag+1:end))) ./ ...
    ( abs(delayed_data(:,:,1:end-lag)).*abs(delayed_data(:,:,lag+1:end)) ), 3) );
for lag = 1:numLags
    SLSCImg_from_FI(:,:,lag) = SLSC(delayed_FI_data, lag);
    SLSCImg_from_RTB(:,:,lag) = SLSC(delayed_RTB_data, lag);
    SLSCImg_from_REFOCUS(:,:,lag) = SLSC(delayed_STAI_REFOCUS_data, lag);
    disp(['SLSC Lag = ', num2str(lag)]);
end
%%
[~,x_idx_20mm] = min(abs(scan.depth_axis-20/1000))
[~,x_idx_45mm] = min(abs(scan.depth_axis-45/1000))

% VCZ Curves at Two Depths
VCZ1_FI_20mm = squeeze(mean(mean(SLSCImg_from_FI(x_idx_20mm-10:x_idx_20mm+10,70:110,:),1),2));
VCZ1_RTB_20mm = squeeze(mean(mean(SLSCImg_from_RTB(x_idx_20mm-10:x_idx_20mm+10,70:110,:),1),2));
VCZ1_REFOCUS_10mm = squeeze(mean(mean(SLSCImg_from_REFOCUS(x_idx_20mm-10:x_idx_20mm+10,70:110,:),1),2));

VCZ1_FI_45mm = squeeze(mean(mean(SLSCImg_from_FI(x_idx_45mm-10:x_idx_45mm+10,70:110,:),1),2));
VCZ1_RTB_45mm = squeeze(mean(mean(SLSCImg_from_RTB(x_idx_45mm-10:x_idx_45mm+10,70:110,:),1),2));
VCZ1_REFOCUS_45mm = squeeze(mean(mean(SLSCImg_from_REFOCUS(x_idx_45mm-10:x_idx_45mm+10,70:110,:),1),2));
%%
figure; 
subplot(211)
plot(VCZ1_FI_20mm, 'Linewidth', 2, 'DisplayName', 'FI'); hold on; 
plot(VCZ1_RTB_20mm, 'Linewidth', 2, 'DisplayName', 'RTB'); hold on; 
plot(VCZ1_REFOCUS_10mm,'--','Linewidth', 2, 'DisplayName', 'REFOCUS'); hold on; 
xlabel('lag'); ylabel('Coherence'); legend();title('At 20 mm');

subplot(212)
plot(VCZ1_FI_45mm, 'Linewidth', 2, 'DisplayName', 'FI'); hold on; 
plot(VCZ1_RTB_45mm, 'Linewidth', 2, 'DisplayName', 'RTB'); hold on;  
plot(VCZ1_REFOCUS_45mm,'--','Linewidth', 2, 'DisplayName', 'REFOCUS'); hold on;
xlabel('lag'); ylabel('Coherence');title('At 45 mm (focus)');
end

