%% Estimate SNR
muo = squeeze(mean(abs(b_das.data(mask_o>0,:,:,:)).^2,1));
sigmao = squeeze(std(abs(b_das.data(mask_o>0,:,:,:)).^2,1));
mui = squeeze(mean(abs(b_das.data(mask_i>0,:,:,:)).^2,1));
sigmai = squeeze(std(abs(b_das.data(mask_i>0,:,:,:)).^2,1));

figure;
plot(10*log10(mui),'r.-'); hold on;
plot(10*log10(muo),'b.-'); 
legend('inside','outside');

figure;
plot(10*log10(muo./mui),'r.-'); hold on;

channel_SNR=(3./reshape(mui./muo,[4 5])-3)/2/M
