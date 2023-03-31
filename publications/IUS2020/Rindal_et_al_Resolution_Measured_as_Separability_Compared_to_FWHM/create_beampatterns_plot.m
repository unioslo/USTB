% Create the array geometry plot and beampattern plots used in the paper
clear all;
close all;

lambda_division = [2];
pitch_signs = {'\lambda/2'};
Ns = [32 64];
for i = 1:length(Ns)
    for j = 1:length(lambda_division)
        c0                      = 1540;           % Speed of sound 
        f0                      = 2*10^6;         % Center frequency [Hz]
        lambda                  = c0/f0;          % Wavelength [m]
        
        % Create UFF linear array object as probe
        probe = uff.linear_array();
        pitch_sign = pitch_signs{j};
        probe.pitch = lambda/lambda_division(j);      %Pitch
        probe.N = Ns(i);                              %Number of elemens
        probe.element_height = probe.pitch;
        
        
        % Calculate aperture smoothing function
        %Creating Kx vector
        theta = linspace(-pi/2,pi/2,3000);
        kx = -(2*pi*sin(theta)/lambda);
        d = probe.pitch;
        D = probe.N_elements * d;
        elemt_size = probe.element_width;
        w_m = ones(1,probe.N_elements);
        
        W = zeros(length(kx),1);
        for t = 1:length(kx)
            W(t) = sum(w_m.*exp(-1i*kx(t).*probe.x'));
        end
        W = W./max(W);
        
        %% Create plot of array geometry
        probe.plot();
        view(2);
        title(['Array (N=', num2str((Ns(i))),', width = ',num2str(D*1000,'%.2f'),' mm, pitch = ',pitch_signs{1}]);

        %% Create plot of beampattern
        R = 60/1000;
        x_axis_mm = R.*sin(theta);
        res = R*(1.2*lambda/(D))*10^3;
        [~,est_6db] = min(abs(db(W)+6));
        
        figure();
        subplot(211);hold all;
        plot(x_axis_mm*10^3,db((W)),'LineWidth',2,'DisplayName','Beam Pattern');
        plot([x_axis_mm(est_6db)*10^3 x_axis_mm(est_6db)*10^3],[-60 0],'r','LineWidth',2,'DisplayName','-6 dB');
        plot([-x_axis_mm(est_6db)*10^3 -x_axis_mm(est_6db)*10^3],[-60 0],'r','LineWidth',2,'HandleVisibility','off');
        plot([-res/2 -res/2],[-60 0],'k--','LineWidth',2,'DisplayName','Res Approx Formula')
        plot([res/2 res/2],[-60 0],'k--','LineWidth',2,'HandleVisibility','off')
        set(gca,'FontSize',14);xlabel('x [mm]');ylabel('Amplitude [dB]')
        xlim([-10 10]);title(['FWHM = ',num2str(res), ' mm']);xlabel('x [mm]')
        legend();
    end
end