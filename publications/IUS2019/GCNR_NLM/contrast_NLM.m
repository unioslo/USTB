function [CE, CNRE, MSR, GCNR, AUC, nunu, GCNR0, C0]=contrast_NLM(M, SNR, b_data, mask_o, mask_i, my_title,make_movie)

CE=[];
CNRE=[];
MSR=[];
GCNR=[];
AUC=[];

if nargin < 7
    make_movie = 0;
end

if make_movie
    movie_dir = [ustb_path,filesep,'publications',filesep,'IUS2019/GCNR_NLM/Movie/'];
    if ~isfolder(movie_dir)
        mkdir(movie_dir);
    end
    FileNameMovie = [movie_dir, my_title];
    vidObj = VideoWriter(FileNameMovie,'MPEG-4');
    vidObj.Quality = 100;
    vidObj.FrameRate = 5;
    open(vidObj);
    
    
end
figure(101012);clf
for n=1:b_data.N_frames
    Pf=[];
    Pd=[];
    
    img=abs(reshape(b_data.data(:,1,1,n),[b_data.scan.N_z_axis b_data.scan.N_x_axis]));
    
    
    f = figure(101010);clf;
    imagesc(b_data.scan.x_axis*1e3,b_data.scan.z_axis*1e3, 20*log10(img./max(img(:)))); colormap gray; axis equal tight; colorbar;
    caxis([-50 0])
    set(gca,'FontSize', 25);
    xlabel('x[mm]');
    ylabel('z[mm]');
    
    figure_dir = [ustb_path,filesep,'publications',filesep,'IUS2019/GCNR_NLM/Figures/b_mode_images/'];
    if ~isfolder(figure_dir)
        mkdir(figure_dir)
    end
    saveas(f,[figure_dir, my_title, num2str(n)],'eps2c')
    
    
    %% clasic
    mu_i=mean(img(mask_i).^2);
    mu_o=mean(img(mask_o).^2);
    v_i=var(img(mask_i).^2);
    v_o=var(img(mask_o).^2);
    
    CE(n)=mu_i./mu_o;
    CNRE(n)=abs(mu_i-mu_o)/sqrt(v_i+v_o);
    
    %% Pmax
    x=linspace(min(img(:)),max(img(:)),700);
    
    [pdf_i]=hist(img(mask_i),x);
    [pdf_o]=hist(img(mask_o),x);
    
    %if n==to_plot
    f = figure(101011);clf;
    plot(x,pdf_i./sum(pdf_i),'r-', 'linewidth',2); hold on; grid on;
    plot(x,pdf_o./sum(pdf_o),'b-', 'linewidth',2);
    hh=area(x,min([pdf_i./sum(pdf_i); pdf_o./sum(pdf_o)]));
    hh.FaceColor = [0.6 0.6 0.6];
    xlabel('||s||');
    ylabel('Probability');
    set(gca,'FontSize', 25);
    legend('p_i','p_o','OVL');
    %title(['PDFs for SNR=',num2str(10*log10(SNR(n)))]);
    if strcmp(my_title,'PCF')
        xlim([0 10])
    end
    if strcmp(my_title,'SLSC') || strcmp(my_title,'SLSC_2')
        xlim([0 0.75])
        ylim([0 0.03])
    end
    
    pdf_dir = [ustb_path,filesep,'publications',filesep,'IUS2019/GCNR_NLM/Figures/PDFs/',my_title,num2str(n)];
    
    if ~isfolder(pdf_dir)
        mkdir(pdf_dir)
    end
    saveas(f,[pdf_dir,my_title,num2str(n)],'eps2c')
    %end
    
    if make_movie
        %%
        f = figure(101012);clf;
        subplot(121);
        imagesc(b_data.scan.x_axis*1e3,b_data.scan.z_axis*1e3, 20*log10(img./max(img(:)))); colormap gray; axis equal tight; colorbar;
        caxis([-50 0])
        set(gca,'FontSize', 25);
        xlabel('x[mm]');
        ylabel('z[mm]');
        title(['SNR=',num2str(10*log10(SNR(n)))]);
        subplot(122);
        plot(x,pdf_i./sum(pdf_i),'r-', 'linewidth',2); hold on; grid on;
        plot(x,pdf_o./sum(pdf_o),'b-', 'linewidth',2);
        hh=area(x,min([pdf_i./sum(pdf_i); pdf_o./sum(pdf_o)]));
        hh.FaceColor = [0.6 0.6 0.6];
        xlabel('||s||');
        ylabel('Probability');
        set(gca,'FontSize', 25);
        legend('p_i','p_o','OVL');
        if strcmp(my_title,'PCF')
            xlim([0 10])
        end
        if strcmp(my_title,'SLSC') || strcmp(my_title,'SLSC_2')
            xlim([0 0.75])
            ylim([0 0.03])
        end
        
        set(gcf,'Position',[98 143 954 418])
        drawnow();
        pause(0.1)
        writeVideo(vidObj, getframe(f));
        
    end
    
    
    OVL(n)=sum(min([pdf_i./sum(pdf_i); pdf_o./sum(pdf_o)]));
    MSR(n) = 1 - OVL(n)/2;
    GCNR(n)= 1 - OVL(n);

    
end

if make_movie
    close(vidObj)
end


%% theory
SNRdB=10*log10(SNR);
nunu = 10.^(linspace(min(SNRdB),max(SNRdB),100)/10);

C0 = @(snr) 3./(2*M*snr+3);
CNR0 = @(c) abs(c -1)./sqrt(c.^2+1);
pmax = @(c) 0.5+ 0.5*( c.^-(c./(c-1)) - c.^(-1./(c-1)));
GCNR0 = @(c) c.^-(c./(c-1)) - c.^(-1./(c-1));


%% GCNR
f = figure(101019);clf
plot(10*log10(SNR),GCNR,'bo','MarkerSize',7, 'MarkerFaceColor', 'b'); hold on;
plot(10*log10(nunu),GCNR0(C0(nunu)),'r--','linewidth',2); hold on; grid on; axis tight square;
set(gca,'FontSize', 25);
ylim([0 1])
%xlabel('10 log_{10} \nu_S/\nu_N');
xlabel('Channel SNR [dB]');
ylabel('GCNR');
legend('Field II','Eq.(2)','Location','SouthEast')
%title(my_title);
set(gca,'FontSize', 25);
saveas(f,[ustb_path,filesep,'publications',filesep,'IUS2019/GCNR_NLM/Figures/',my_title,'_GCNR'],'eps2c')

