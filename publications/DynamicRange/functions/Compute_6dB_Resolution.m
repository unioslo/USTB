function [res] = Compute_6dB_Resolution(x_axis,y_signal,p,fig,num)

%-- Perform interpolation
coeff = 10;
nb_sample = length(x_axis);
nb_interp = nb_sample * coeff;
x_interp = linspace(x_axis(1),x_axis(end),nb_interp);
y_interp = interp1(x_axis,y_signal,x_interp);

ind = find(y_interp >= (max(y_interp)-6) );
idx1 = min(ind);
idx2 = max(ind);
res = x_interp(idx2) - x_interp(idx1);

%-- Display profil
if (p==1)
    figure(fig); subplot(1,4,num);
    plot(x_interp,y_interp,'linewidth',2);
    hold on; plot([x_interp(idx1) x_interp(idx1)],[-100 0],'-k','linewidth',1);
    hold on; plot([x_interp(idx2) x_interp(idx2)],[-100 0],'-k','linewidth',1);
    hold off; ylabel('Amp [dB]');
    if (num==2)
        title(sprintf('Axial res = %02.2f [mm]',res));
        xlabel('z [mm]');
    else
        xlabel('x [mm]');
        title(sprintf('Lateral res = %02.2f [mm]',res));
    end
end

end
