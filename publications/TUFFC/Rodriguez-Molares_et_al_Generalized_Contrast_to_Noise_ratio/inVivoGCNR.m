function [GCNR CE CNRE] = inVivoGCNR(b_data, mask_o, mask_i,my_title)


img=abs(reshape(b_data.data(:,1,1),[b_data.scan.N_z_axis b_data.scan.N_x_axis]));


figure;
imagesc(b_data.scan.x_axis*1e3,b_data.scan.z_axis*1e3, 20*log10(img)); colormap gray; axis equal tight; colorbar;
caxis(20*log10(prctile(img(:),99)) + [-60 0] )
set(gca,'FontSize', 14);
xlabel('x[mm]');
ylabel('z[mm]');
title(sprintf("%s percentile DR", my_title));


%% classic metrics
mu_i=mean(img(mask_i).^2);
mu_o=mean(img(mask_o).^2);
v_i=var(img(mask_i).^2);
v_o=var(img(mask_o).^2);

CE = mu_i./mu_o;
CNRE = abs(mu_i-mu_o)/sqrt(v_i+v_o);

%% Pmax
x=linspace(min(img(:)),max(img(:)),10000);

[pdf_i]=hist(img(mask_i),x);
[pdf_o]=hist(img(mask_o),x);


%     mask_img_i = reshape(mask_i,size(img,1),size(img,2));
%     figure();
%     subplot(121);
%     imagesc(img.*mask_i);
%     subplot(122);
%     imagesc(img.*mask_o);

%% Plot probability density function

figure()
plot(x,pdf_i./sum(pdf_i),'r-', 'linewidth',2); hold on; grid on;
plot(x,pdf_o./sum(pdf_o),'b-', 'linewidth',2);
hh=area(x,min([pdf_i./sum(pdf_i); pdf_o./sum(pdf_o)]), 'LineStyle','none');
hh.FaceColor = [0.6 0.6 0.6];
xlabel('||s||');
ylabel('Probability');
legend('p_i','p_o','OVL');

set(gca,'FontSize', 14);

idx = find(min([pdf_i./sum(pdf_i); pdf_o./sum(pdf_o)])>0);
xlim([0 x(max(idx))])


OVL =sum(min([pdf_i./sum(pdf_i); pdf_o./sum(pdf_o)]));
MSR  = 1 - OVL/2;
GCNR = 1 - OVL;


