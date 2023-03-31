% Generating the images for IUS 2017 abstract with USTB built-in Fresnel simulator

%   authors: Alfonso Rodriguez-Molares (alfonso.r.molares@ntnu.no)
%   $Date: 2017/03/16$

clear all;
close all;

z0=20e-3;           % depth of the scatterer [m]
Fs=41.6e6;          % sampling frequency [Hz]
F_number=1.2;       % F-number
uwindow=uff.window.boxcar;

%% PHANTOM
pha=uff.phantom();
pha.sound_speed=1540;         % speed of sound [m/s]
pha.points=[0,  0, z0, 1];    % point scatterer position [m]
fig_handle=pha.plot();             
             
%% PROBE
prb=uff.linear_array();
prb.N=128;                  % number of elements 
prb.pitch=300e-6;           % probe pitch in azimuth [m]
prb.element_width=270e-6;   % element width [m]
prb.element_height=5000e-6; % element height [m]
prb.plot(fig_handle);

%% PULSE
pul=uff.pulse();
pul.center_frequency=5.2e6;       % transducer frequency [MHz]
pul.fractional_bandwidth=0.6;     % fractional bandwidth [unitless]
pul.plot([],'2-way pulse');

%% SCAN
scan=uff.linear_scan('x_axis',linspace(-2e-3,2e-3,200).', 'z_axis',linspace(z0-1e-3,z0+1e-3,100).');
scan.plot(fig_handle,'Scenario');    % show mesh
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% FI
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% SEQUENCE GENERATION
seq=uff.wave();
for n=1:scan.N_x_axis 
    seq(n)=uff.wave();
    seq(n).probe=prb;
    seq(n).source.xyz=[scan.x_axis(n) 0 z0];
    
    seq(n).apodization=uff.apodization();
    seq(n).apodization.window=uwindow;
    seq(n).apodization.f_number=F_number;
    seq(n).apodization.focus=uff.scan('xyz',seq(n).source.xyz);
    
    seq(n).sound_speed=pha.sound_speed;
end

%% fresnel
sim=fresnel();

% setting input data 
sim.phantom=pha;                % phantom
sim.pulse=pul;                  % transmitted pulse
sim.probe=prb;                  % probe
sim.sequence=seq;               % beam sequence
sim.sampling_frequency=Fs;      % sampling frequency [Hz]

% we launch the simulation
channel_data=sim.go();
 
%% PIPELINE
mid=midprocess.das();
mid.dimension = dimension.both;
mid.channel_data=channel_data;
mid.scan=scan;

mid.transmit_apodization.window = uff.window.scanline;

mid.receive_apodization.window=uwindow;
mid.receive_apodization.f_number=F_number;

% beamforming
fi_data=mid.go();

% show
fi_data.plot([],'FI');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% STAI
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% SEQUENCE GENERATION
N=128;                      % number of waves
seq=uff.wave();
for n=1:N 
    seq(n)=uff.wave();
    seq(n).probe=prb;
    seq(n).source.xyz=[prb.x(n) prb.y(n) prb.z(n)];
    seq(n).apodization=uff.apodization('window',uff.window.sta,'origin',seq(n).source);
    
    seq(n).sound_speed=pha.sound_speed;
end

%% fresnel
sim=fresnel();

% setting input data 
sim.phantom=pha;            % phantom
sim.pulse=pul;              % transmitted pulse
sim.probe=prb;              % probe
sim.sequence=seq;           % beam sequence
sim.sampling_frequency=Fs;  % sampling frequency [Hz]

% we launch the simulation
channel_data=sim.go();
  
%% PIPELINE
mid.channel_data=channel_data;

mid.transmit_apodization.window=uwindow;
mid.transmit_apodization.f_number=F_number;

% beamforming
stai_data=mid.go();

% show
stai_data.plot([],'STAI');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% CPWC
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% SEQUENCE GENERATION
angle_max=atan(1/2/F_number);
lambda=pha.sound_speed/pul.center_frequency;
N=round(prb.pitch*prb.N_elements/lambda/F_number);
angles=linspace(-angle_max,angle_max,N);
seq=uff.wave();
for n=1:N 
    seq(n)=uff.wave();
    seq(n).probe=prb;
    seq(n).source.azimuth=angles(n);
    seq(n).source.distance=Inf;
    seq(n).sound_speed=pha.sound_speed;
end

%% fresnel
sim=fresnel();

% setting input data 
sim.phantom=pha;                % phantom
sim.pulse=pul;                  % transmitted pulse
sim.probe=prb;                  % probe
sim.sequence=seq;               % beam sequence
sim.sampling_frequency=Fs;      % sampling frequency [Hz]

% we launch the simulation
channel_data=sim.go();
 
%% PIPELINE
mid.channel_data=channel_data;

% beamforming
cpwc_data=mid.go();

% show
cpwc_data.plot([],'CPWC');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% DWI
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% SEQUENCE GENERATION
zs=-10e-3;
xs=(z0-zs)*tan(angles);
seq=uff.wave();
for n=1:N 
    seq(n)=uff.wave();
    seq(n).probe=prb;
    seq(n).source.xyz=[xs(n) 0 zs];
    
    seq(n).sound_speed=pha.sound_speed;
end

%% fresnel
sim=fresnel();

% setting input data 
sim.phantom=pha;                % phantom
sim.pulse=pul;                  % transmitted pulse
sim.probe=prb;                  % probe
sim.sequence=seq;               % beam sequence
sim.sampling_frequency=Fs;      % sampling frequency [Hz]

% we launch the simulation
channel_data=sim.go();
 
%% PIPELINE
mid.channel_data=channel_data;

% beamforming
dwi_data=mid.go();

% show
dwi_data.plot([],'DWI');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% RTB
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% SEQUENCE GENERATION
zs=40e-3;
xs=(zs-z0)*tan(angles);
seq=uff.wave();
for n=1:N 
    seq(n)=uff.wave();
    seq(n).probe=prb;
    seq(n).source.xyz=[xs(n) 0 zs];
    
    seq(n).sound_speed=pha.sound_speed;
    
    % show source
    fig_handle=seq(n).source.plot(fig_handle);
end

%% fresnel
sim=fresnel();

% setting input data 
sim.phantom=pha;                % phantom
sim.pulse=pul;                  % transmitted pulse
sim.probe=prb;                  % probe
sim.sequence=seq;               % beam sequence
sim.sampling_frequency=Fs;      % sampling frequency [Hz]

% we launch the simulation
channel_data=sim.go();
 
%% PIPELINE
mid.channel_data=channel_data;

% beamforming
rtb_data=mid.go();

% show
rtb_data.plot([],'RTB');

%%%%%%%%%%%%%%%%%%%%%%%%%
%% Analyze results
%%%%%%%%%%%%%%%%%%%%%%%%%
mask=scan.x>-0.5e-3&scan.x<0.5e-3&scan.z>19.6e-3&scan.z<20.4e-3;
for n=1:5
    switch n
        case 1
            data=reshape(stai_data.data,[scan.N_z_axis scan.N_x_axis]);
        case 2
            data=reshape(fi_data.data,[scan.N_z_axis scan.N_x_axis]);
        case 3
            data=reshape(cpwc_data.data,[scan.N_z_axis scan.N_x_axis]);
        case 4
            data=reshape(dwi_data.data,[scan.N_z_axis scan.N_x_axis]);
        case 5
            data=reshape(rtb_data.data,[scan.N_z_axis scan.N_x_axis]);
    end
    
    %
    temp=sum(abs(data(:,100:200)),1); 
    temp=temp./max(temp);
    temp=20*log10(temp);
    xlat=interp1(temp(2:end),scan.x_axis(101:200),-6);
    lateral_profile(n,:)=temp;
    fwhm(n)=2*xlat;
    
    data_dB=20*log10(abs(data)./max(abs(data(:))));
    data_dB(data_dB<-60)=-60; % crop values smaller than -60 dB
    
    sll(n)=max(data_dB(not(mask)))-max(data_dB(mask));
end

disp(sprintf('FWHM %0.2f±%0.2f',mean(fwhm)*1e6,std(fwhm)*1e6));
disp(sprintf('SLL %0.2f±%0.2f',mean(sll),std(sll)));


figure;
plot(scan.x_axis(100:200)*1e3,lateral_profile,'linewidth',2); grid on; hold on;
legend('STAI','FI','CPWC','DWI','RTB');
xlabel('x [mm]'); axis tight
ylabel('Intensity [dB]');
set(gca,'fontsize', 14);
title('Lateral profile');
c = categorical({'STAI','FI','CPWC','DWI','RTB'});

figure;
subplot(1,2,1);
bar(fwhm*1e6); grid on; hold on; 
ylabel('FWHM [\mum]');
set(gca,'fontsize', 14); 
plot(0:6,ones(1,7)*mean(fwhm)*1e6,'r--','linewidth',2)
plot(0:6,ones(1,7)*mean(fwhm)*1e6+std(fwhm)*1e6,'r-','linewidth',2)
plot(0:6,ones(1,7)*mean(fwhm)*1e6-std(fwhm)*1e6,'r-','linewidth',2)
xlim([0 6]);

subplot(1,2,2);
bar(sll); grid on; hold on; 
ylabel('SSL [dB]');
set(gca,'fontsize', 14);
plot(0:6,ones(1,7)*mean(sll),'r--','linewidth',2)
plot(0:6,ones(1,7)*mean(sll)+std(sll),'r-','linewidth',2)
plot(0:6,ones(1,7)*mean(sll)-std(sll),'r-','linewidth',2)
xlim([0 6]);




