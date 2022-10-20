%% STA simulation on a matrix array with the USTB built-in Fresnel simulator
%
% In this example we show how to use the built-in fresnel simulator in USTB
% to generate a Synthetic Transmit Aperture (STA) dataset using a 2D 
% matrix array probe and illustrate how it can be beamformed with USTB.
%
% This tutorial assumes familiarity with the contents of the 
% <../../linear_array/html/CPWC_linear_array.html 'CPWC simulation with the 
% USTB built-in Fresnel simulator'> tutorial. Please feel free to refer 
% back to that for more details.
% 
% by Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no> and Arun 
% Asokan Nair <anair8@jhu.edu> 25.03.2017_

%%
% 
% Clear the memory of any lingering settings and data, close all 
% previously opened plots and define the F-Number we will be using.

clear all;
close all;

F_number=1.0;

%% Phantom
%
% We start off defining an appropriate *phantom* structure to image. 
% Our phantom here is a set of three point scatterers about a set depth. 
% USTB's implementation of *phantom* comes with a *plot* method to 
% visualize the phantom for free!

z0=10e-3;                                   % Depth of middle scatterer
pha=uff.phantom();
pha.sound_speed=1540;                       % speed of sound [m/s]
pha.points=[0e-3, 0, z0-2e-3, 1;...         % point scatterer positions [m]
            0, -2e-3, z0, 1;...    
            -3e-3, 0, z0+2e-3, 1];      
fig_handle=pha.plot();             
             
%% Probe
%
% The next UFF structure we look at is *probe*. It contains information 
% about the probe's geometry. USTB's implementation of *probe* comes with a 
% *plot* method too. When combined with the previous figure we can see the
% position of the probe respect to the phantom.
% Here, we shall set the probe to be a *matrix_array* type.

prb=uff.matrix_array();
prb.N_x=32;                 % number of elements 
prb.N_y=4;                  % number of elements 
prb.pitch_x=400e-6;         % probe pitch in azimuth [m]
prb.pitch_y=400e-6;         % probe pitch in elevation [m]
prb.element_width=370e-6;   % element width [m]
prb.element_height=370e-6;  % element height [m]
prb.plot(fig_handle);

%% Pulse
% 
% We then define the pulse-echo signal which is done here using the 
% *fresnel* simulator's *pulse* structure. We could also use 
% <http://field-ii.dk/ 'Field II'> for a more accurate model.

pul=uff.pulse();
pul.center_frequency=3e6;         % transducer frequency [MHz]
pul.fractional_bandwidth=0.6;     % fractional bandwidth [unitless]
pul.plot([],'2-way pulse');

%% Sequence generation
%
% Now, we shall generate our sequence! Keep in mind that the *fresnel* simulator
% takes the same sequence definition as the USTB beamformer. In UFF and
% USTB a sequence is defined as a collection of *wave* structures. 
% 
% For our example here, we define a sequence of 128 (= number of elements) 
% waves each emanating from a single element on the probe aperture.
% An appropriate apodization window is enforced through setting 
% *apodization.window = uff.window.sta*. The *wave* structure too has a
% *plot* method.

seq=uff.wave();
for n=1:prb.N_elements 
    seq(n)=uff.wave();
    seq(n).probe=prb;
    seq(n).source.xyz=[prb.x(n) prb.y(n) prb.z(n)];
    
    seq(n).apodization=uff.apodization();
    seq(n).apodization.window=uff.window.sta;
    seq(n).apodization.origin=seq(n).source;
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

% we launch the simulation
channel_data=sim.go();
 
%% Scan
%
% The scan area is defines as a collection of pixels spanning our region of 
% interest. For our example here, we use the *linear_3D_scan* option, 
% which is defined with three components: the x-dimension range, the 
% z-dimension range and the y-dimension range. *scan* too has a useful 
% *plot* method it can call.

sca=uff.linear_3D_scan('radial_axis',linspace(-6.4e-3,6.4e-3,200).','axial_axis',linspace(z0-3.2e-3,z0+3.2e-3,100).','roll',0);
sca.plot(fig_handle,'Scenario');    % show mesh
 
%% Pipeline
%
% With *channel_data* and a *scan* we have all we need to produce an
% ultrasound image. We now use a USTB structure *beamformer*, that takes an
% *apodization* structure in addition to the *channel_data* and *scan*.

pipe=pipeline();
pipe.channel_data=channel_data;
pipe.scan=sca;

pipe.receive_apodization.window=uff.window.tukey50;
pipe.receive_apodization.f_number=F_number;

pipe.transmit_apodization.window=uff.window.tukey50;
pipe.transmit_apodization.f_number=F_number;

%% 
%
% The *pipeline* structure allows you to implement different beamformers 
% by combination of multiple built-in *processes*. By changing the *process*
% chain other beamforming sequences can be implemented. It returns yet 
% another *UFF* structure: *beamformed_data*.

% To achieve the goal of this example, we use delay-and-sum (implemented in 
% the *das_matlab()* process) as well as coherent compounding.

% Since we are doing 3D imaging with a 3D scan we need to use the spherical
% transmit delay model
das = midprocess.das();
das.spherical_transmit_delay_model = spherical_transmit_delay_model.spherical();
%%
b_data=pipe.go({das postprocess.coherent_compounding});

% show
fig_plot=pha.plot();
b_data.plot(fig_plot); 