%% CPWC simulation to compare speeds of the various USTB beamformers.
%
%% 
% In this example, we conduct a simple simulation to compare the speeds 
% achieved with USTB's:
% 
% # MATLAB delay implementation
% # Mex delay implementation
% # MATLAB delay-and-sum implementation 
% # Mex delay-and-sum implementation.
% 
% This tutorial assumes familiarity with the contents of the 
% <./CPWC_linear_array.html 'CPWC simulation with the USTB built-in Fresnel 
% simulator'> tutorial. Please feel free to refer back to that for more 
% details.
% 
% _by Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no> and Arun Asokan 
% Nair <anair8@jhu.edu> 16.05.2017_

clear all;
close all;

%% Phantom
%
% Our first step is to define an appropriate *phantom* structure as input. 
% Our phantom here is simply a collection of point scatterers. 
% USTB's implementation of *phantom* comes with a *plot* method for free!

x_sca=[zeros(1,7) -15e-3:5e-3:15e-3];
z_sca=[5e-3:5e-3:35e-3 20e-3*ones(1,7)];
N_sca=length(x_sca);
pha=uff.phantom();
pha.sound_speed=1540;            % speed of sound [m/s]
pha.points=[x_sca.', zeros(N_sca,1), z_sca.', ones(N_sca,1)];    % point scatterer position [m]
fig_handle=pha.plot();             
             
%% Probe
%
% The next step is to define the *probe* structure which contains
% information about the probe's geometry. This too comes with % a *plot* 
% method that enables visualization of the probe with respect to the phantom.
% The probe we will use in our example is a linear array transducer with
% 128 elements.

prb=uff.linear_array();
prb.N=128;                  % number of elements 
prb.pitch=300e-6;           % probe pitch in azimuth [m]
prb.element_width=270e-6;   % element width [m]
prb.element_height=5000e-6; % element height [m]
prb.plot(fig_handle);

%% Pulse
% 
% We then define the pulse-echo signal which is done here using the 
% *fresnel* simulator's *pulse* structure. We could also use 
% <http://field-ii.dk/ 'Field II'> for a more accurate model.

pul=uff.pulse();
pul.center_frequency=5.2e6;       % transducer frequency [MHz]
pul.fractional_bandwidth=0.6;     % fractional bandwidth [unitless]
pul.plot([],'2-way pulse');

%% Sequence generation
%
% Now, we shall generate our sequence! Keep in mind that the *fresnel* simulator
% takes the same sequence definition as the USTB beamformer. In UFF and
% USTB a sequence is defined as a collection of *wave* structures. 
% 
% For our example here, we define a sequence of 15 plane-waves 
% covering an angle span of $[-0.3, 0.3]$ radians. The *wave* structure has 
% a *plot* method which plots the direction of the transmitted plane-wave.

N_plane_waves=15;
angles=linspace(-0.3,0.3,N_plane_waves);
seq=uff.wave();
for n=1:N_plane_waves 
    seq(n)=uff.wave();
    seq(n).probe=prb;
    seq(n).source.azimuth=angles(n);
    seq(n).source.distance=Inf;
    seq(n).sound_speed=pha.sound_speed;
    
    % show source
    fig_handle=seq(n).source.plot(fig_handle);
end

%% The Fresnel simulator
%
% Finally, we launch the built-in simulator. The simulator takes in a
% *phantom*, *pulse*, *probe* and a sequence of *wave* structures along 
% with the desired sampling frequency, and returns a *channel_data* UFF 
% structure.

sim=fresnel();

% setting input data 
sim.phantom=pha;                % phantom
sim.pulse=pul;                  % transmitted pulse
sim.probe=prb;                  % probe
sim.sequence=seq;               % beam sequence
sim.sampling_frequency=41.6e6;  % sampling frequency [Hz]

% we launch the simulation. Go!
channel_data=sim.go();
 
%% Scan
%
% The scan area is defines as a collection of pixels spanning our region of 
% interest. For our example here, we use the *linear_scan* structure, 
% which is defined with just two axes. *scan* too has a useful *plot*
% method it can call.

sca=uff.linear_scan('x_axis',linspace(-20e-3,20e-3,256).', 'z_axis', linspace(0e-3,40e-3,256).');
sca.plot(fig_handle,'Scenario');    % show mesh
 
%% Pipeline
%
% With *channel_data* and a *scan* we have all we need to produce an
% ultrasound image. We now use a USTB structure *pipeline*, that takes an
% *apodization* structure in addition to the *channel_data* and *scan*.

pipe=pipeline();
pipe.channel_data=channel_data;
pipe.scan=sca;

pipe.receive_apodization.window=uff.window.tukey50;
pipe.receive_apodization.f_number=1.0;
pipe.receive_apodization.origin=uff.point('xyz',[0 0 -Inf]);

pipe.transmit_apodization.window=uff.window.tukey50;
pipe.transmit_apodization.f_number=1.0;
pipe.transmit_apodization.origin=uff.point('xyz',[0 0 -Inf]);

%% 
%
% The *pipeline* structure allows you to implement different beamformers 
% by combination of multiple built-in *processes*. By changing the *process*
% chain other beamforming sequences can be implemented. It returns yet 
% another *UFF* structure: *beamformed_data*.

% To achieve the goal of this example, we combine 4 pairs of *processes* 
% # *das_matlab* and % *coherent_compounding*
% # *delay_matlab* and % *coherent_compounding*
% # *das_mex* and % *coherent_compounding*
% # *delay_mex* and % *coherent_compounding*
% to produce coherently compounded images and examine each one's speed with
% respect to the others for increasing amounts of data.

% beamforming
n_frame=1:2:10;
for n=1:length(n_frame)
    % replicate frames
    channel_data.data=repmat(channel_data.data(:,:,:,1),[1 1 1 n_frame(n)]);

    %%% - MATLAB
    
    % Time USTB's MATLAB delay implementation
    proc=midprocess.das();
    proc.code = code.matlab;
    proc.dimension = dimension.none;
    tic
    b_data=pipe.go({proc postprocess.coherent_compounding()});
    delay_matlab_time(n)=toc
    
    %b_data.plot()
    
    % Time USTB's MATLAB delay implementation
    proc=midprocess.das();
    proc.code = code.matlab_gpu;
    proc.dimension = dimension.none;
    tic
    b_data=pipe.go({proc postprocess.coherent_compounding()});
    delay_matlab_gpu_time(n)=toc
    
    %b_data.plot()
    
    
    
    % Time USTB's MATLAB delay-and-sum implementation
    proc=midprocess.das();
    proc.code = code.matlab;
    proc.dimension = dimension.receive;
    tic
    b_data=pipe.go({proc postprocess.coherent_compounding()}); 
    das_rx_matlab_time(n)=toc;
    
    % Time USTB's MATLAB delay-and-sum transmit implementation
    proc=midprocess.das();
    proc.code = code.matlab;
    proc.dimension = dimension.transmit;
    tic
    b_data=pipe.go({proc postprocess.coherent_compounding()}); 
    das_tx_matlab_time(n)=toc;
    
    % Time USTB's MATLAB delay-and-sum transmit implementation
    proc=midprocess.das();
    proc.code = code.matlab;
    proc.dimension = dimension.both;
    tic
    b_data=pipe.go({proc}); 
    das_both_matlab_time(n)=toc;
    
    %%% - MATLAB GPU
    
    % Time USTB's MATLAB delay implementation
    proc=midprocess.das_matlab_gpu_nvidia();
    proc.dimension = dimension.none;
    tic
    b_data=pipe.go({proc postprocess.coherent_compounding()});
    delay_matlab_gpu_time(n)=toc;
    
    % Time USTB's MATLAB delay-and-sum implementation
    proc=midprocess.das_matlab_gpu_nvidia();
    proc.dimension = dimension.receive;
    tic
    b_data=pipe.go({proc postprocess.coherent_compounding()}); 
    das_rx_matlab_gpu_time(n)=toc;
    
    % Time USTB's MATLAB delay-and-sum transmit implementation
    proc=midprocess.das_matlab_gpu_nvidia();
    proc.dimension = dimension.transmit;
    tic
    b_data=pipe.go({proc postprocess.coherent_compounding()}); 
    das_tx_matlab_gpu_time(n)=toc;
    
    % Time USTB's MATLAB delay-and-sum transmit implementation
    proc=midprocess.das_matlab_gpu_nvidia();
    proc.dimension = dimension.both;
    tic
    b_data=pipe.go({proc}); 
    das_both_matlab_gpu_time(n)=toc;
    
    %%% - MEX
    
    % Time USTB's MATLAB delay implementation
    proc=midprocess.das();
    proc.code = code.mex;
    proc.dimension = dimension.none;
    tic
    b_data=pipe.go({proc postprocess.coherent_compounding()});
    delay_mex_time(n)=toc;
    
    % Time USTB's MATLAB delay-and-sum implementation
    proc=midprocess.das();
    proc.code = code.mex;
    proc.dimension = dimension.receive;
    tic
    b_data=pipe.go({proc postprocess.coherent_compounding()}); 
    das_rx_mex_time(n)=toc;
    
    % Time USTB's MATLAB delay-and-sum transmit implementation
    proc=midprocess.das();
    proc.code = code.mex;
    proc.dimension = dimension.transmit;
    tic
    b_data=pipe.go({proc postprocess.coherent_compounding()}); 
    das_tx_mex_time(n)=toc;
    
    % Time USTB's MATLAB delay-and-sum transmit implementation
    proc=midprocess.das();
    proc.code = code.mex;
    proc.dimension = dimension.both;
    tic
    b_data=pipe.go({proc}); 
    das_both_mex_time(n)=toc;
    
    % Plot the runtimes
    figure(101);
    plot(n_frame(1:n),delay_matlab_time(1:n),'bs--','linewidth',2);  hold on; grid on;
    plot(n_frame(1:n),das_rx_matlab_time(1:n),'ro--','linewidth',2);
    plot(n_frame(1:n),das_tx_matlab_time(1:n),'gx--','linewidth',2); 
    plot(n_frame(1:n),das_both_matlab_time(1:n),'k^--','linewidth',2); 
    
    plot(n_frame(1:n),delay_mex_time(1:n),'bs-','linewidth',2); 
    plot(n_frame(1:n),das_rx_mex_time(1:n),'ro-','linewidth',2); 
    plot(n_frame(1:n),das_tx_mex_time(1:n),'gx-','linewidth',2); 
    plot(n_frame(1:n),das_both_mex_time(1:n),'k^-','linewidth',2); 

    text(n_frame(n)+0.2,delay_matlab_time(n),sprintf('%0.2f s',delay_matlab_time(n))); 
    text(n_frame(n)+0.2,delay_mex_time(n),sprintf('%0.2f s',delay_mex_time(n))); 

    text(n_frame(n)+0.2,das_rx_matlab_time(n),sprintf('%0.2f s',das_rx_matlab_time(n))); 
    text(n_frame(n)+0.2,das_rx_mex_time(n),sprintf('%0.2f s',das_rx_mex_time(n))); 
    
    text(n_frame(n)+0.2,das_tx_matlab_time(n),sprintf('%0.2f s',das_tx_matlab_time(n))); 
    text(n_frame(n)+0.2,das_tx_mex_time(n),sprintf('%0.2f s',das_tx_mex_time(n))); 
    
    text(n_frame(n)+0.2,das_both_matlab_time(n),sprintf('%0.2f s',das_both_matlab_time(n))); 
    text(n_frame(n)+0.2,das_both_mex_time(n),sprintf('%0.2f s',das_both_mex_time(n))); 

    
    legend('delay MATLAB','das RX MATLAB','das TX MATLAB','das RX&TX MATLAB','delay mex','das RX mex','das TX mex','das RX&TX mex','Location','NorthWest');
    xlabel('Frames');
    ylabel('Elapsed time [s]');
    set(gca,'fontsize',14)
    ylim([0 80]);
    xlim([0 10]);
end

