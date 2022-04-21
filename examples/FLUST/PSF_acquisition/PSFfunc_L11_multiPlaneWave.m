function PSFs = PSFfunc_L11_multiPlaneWave(flowLine, p) % parameter structure not used in this example

%% Simulation of multi-angle plane wave dataset with Field II and beamforming with USTB
%
% Creates a Field II simulation of plane waves from
% multiple angles, converts into a USTB channel_data object and beamforms
% the image using the USTB routines. Steering angles used for
% both transmit and receive beamforming is specified in the script.

% The Field II simulation program (field-ii.dk) should be in MATLAB's path.
%
% date:               23.10.2020
% based on code by :  Ole Marius Hoel RIndal <olemarius@olemarius.net>
%                     Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>
% modified by      :  Joergen Avdal <jorgen.avdal@ntnu.no>


%% Basic Constants
% 
% Our first step is to define some basic constants for our imaging scenario
% - below, we set the speed of sound in the tissue, sampling frequency and
% sampling step size in time.

c0=1540;     % Speed of sound [m/s]
fs=100e6;    % Sampling frequency [Hz]
dt=1/fs;     % Sampling step [s] 
 
%% field II initialisation
% 
% Next, we initialize the field II toolbox. Again, this only works if the 
% Field II simulation program (<field-ii.dk>) is in MATLAB's path. We also
% pass our set constants to it.

field_init(0);
set_field('c',c0);              % Speed of sound [m/s]
set_field('fs',fs);             % Sampling frequency [Hz]
set_field('use_rectangles',1);  % use rectangular elements

%% Transducer definition L11-4v, 128-element linear array transducer
% 
% Our next step is to define the ultrasound transducer array we are using.
% For this experiment, we shall use the L11-4v 128 element Verasonics
% Transducer and set our parameters to match it.

probe = uff.linear_array();
f0                      = 5.1333e+06;      % Transducer center frequency [Hz]
lambda                  = c0/f0;           % Wavelength [m]
probe.element_height    = 5e-3;            % Height of element [m]
probe.pitch             = 0.300e-3;        % probe.pitch [m]
kerf                    = 0.03e-03;        % gap between elements [m]
probe.element_width     = probe.pitch-kerf;% Width of element [m]
lens_el                 = 20e-3;           % position of the elevation focus
probe.N                 = 128;             % Number of elements
pulse_duration          = 4.5;             % pulse duration [cycles]

 
%% Pulse definition
% 
% We then define the pulse-echo signal which is done here using the 
% *fresnel* simulator's *pulse* structure. We could also use 
% <http://field-ii.dk/ 'Field II'> for a more accurate model.

pulse = uff.pulse();
pulse.fractional_bandwidth = 0.65;        % probe bandwidth [1]
pulse.center_frequency = f0;
t0 = (-1/pulse.fractional_bandwidth/f0): dt : (1/pulse.fractional_bandwidth/f0);
impulse_response = gauspuls(t0, f0, pulse.fractional_bandwidth);
impulse_response = impulse_response-mean(impulse_response); % To get rid of DC

te = (-pulse_duration/2/f0): dt : (pulse_duration/2/f0);
excitation = square(2*pi*f0*te+pi/2);
one_way_ir = conv(impulse_response,excitation);
two_way_ir = conv(one_way_ir,impulse_response);
lag = length(two_way_ir)/2+1;   
 
%% Aperture Objects
% Next, we define the the mesh geometry with the help of Field II's
% *xdc_focused_array* function.

noSubAz=round(probe.element_width/(lambda/8));        % number of subelements in the azimuth direction
noSubEl=round(probe.element_height/(lambda/8));       % number of subelements in the elevation direction
Th = xdc_focused_array (probe.N, probe.element_width, probe.element_height, kerf, lens_el, noSubAz, noSubEl, [0 0 Inf]); 
Rh = xdc_focused_array (probe.N, probe.element_width, probe.element_height, kerf, lens_el, noSubAz, noSubEl, [0 0 Inf]); 

% We also set the excitation, impulse response and baffle as below:
xdc_excitation (Th, excitation);
xdc_impulse (Th, impulse_response);
xdc_baffle(Th, 0);
xdc_center_focus(Th,[0 0 0]);
xdc_impulse (Rh, impulse_response);
xdc_baffle(Rh, 0);
xdc_center_focus(Rh,[0 0 0]);
 
%% Define plane wave sequence
% Define the start_angle and number of angles
F_number = 1.7; %receive F#
alpha_max = 15/180*pi; %atan(1/2/F_number);
Na=2;                                      % number of plane waves 
F=size(flowLine,1);                        % number of frames
alphaTx=linspace(-alpha_max,alpha_max,Na);   % vector of Tx angles [rad]
alphaRx=alphaTx;                             % vector of Rx angles [rad]

 
%% Define phantom
% Define some points in a phantom for the simulation

chunkSize = 50;
for cc = 1:chunkSize:size(flowLine, 1)
    
point_position = flowLine(cc:min( cc+chunkSize-1, size( flowLine,1) ),: );

% Set point amplitudes
point_amplitudes = ones(size(point_position,1),1);

%% output data
point_zdists = abs( point_position(:,3) );
point_dists = sqrt( sum( point_position.^2, 2) );
cropstart=floor(1.7*min(point_zdists(:))/c0/dt);    %minimum time sample, samples before this will be dumped
cropend=ceil(1.2*2*max(point_dists)/c0/dt);    % maximum time sample, samples after this will be dumped
CPW=zeros(cropend-cropstart+1,probe.N,Na,chunkSize);  % impulse response channel data
 
%% Compute CPW signals
disp('Field II: Computing CPW dataset');
for f=1:size(point_position,1)
    for n=1:Na
        clc
        disp( [num2str(f+cc-1) '/' num2str(F)]);
         
        % transmit aperture
        xdc_apodization(Th,0,ones(1,probe.N));
        xdc_times_focus(Th,0,probe.geometry(:,1)'.*sin(alphaTx(n))/c0);
        
        % receive aperture
        xdc_apodization(Rh, 0, ones(1,probe.N));
        xdc_focus_times(Rh, 0, zeros(1,probe.N));

        % do calculation
        [v,t]=calc_scat_multi(Th, Rh, point_position(f,:), point_amplitudes(f));
         
        % build the dataset
        toffset = round(t/dt)-cropstart+1;
        numinds = min( size(v,1), size( CPW,1)-toffset );
        CPW( toffset+(1:numinds),:,n,f)=v(1:numinds,:);
        
         
        % Save transmit sequence
        seq(n)=uff.wave();
        seq(n).probe=probe;
        seq(n).source.azimuth=alphaTx(n);
        seq(n).source.distance=Inf;
        seq(n).sound_speed=c0;
        seq(n).delay = -lag*dt;
    end
end

%% Channel Data
% 
% In this part of the code, we creat a uff data structure to specifically
% store the captured ultrasound channel data.

channel_data = uff.channel_data();
channel_data.sampling_frequency = fs;
channel_data.sound_speed = c0;
channel_data.initial_time = (cropstart-1)*dt;
channel_data.pulse = pulse;
channel_data.probe = probe;
channel_data.sequence = seq;
channel_data.data = CPW/1e-26; %


%% Scan
%
% The scan area is defines as a collection of pixels spanning our region of 
% interest. For our example here, we use the *linear_scan* structure, 
% which is defined with two components: the lateral range and the 
% depth range. *scan* too has a useful *plot* method it can call.

sca=uff.linear_scan('x_axis',linspace(-10e-3,10e-3,256).', 'z_axis', linspace(10e-3,30e-3,256).');

%% Pipeline
%
% With *channel_data* and a *scan* we have all we need to produce an
% ultrasound image. We now use a USTB structure *pipeline*, that takes an
% *apodization* structure in addition to the *channel_data* and *scan*.

pipe=pipeline();


pipe.channel_data=channel_data;

myDemodulation=preprocess.fast_demodulation;
myDemodulation.modulation_frequency = f0;
myDemodulation.downsample_frequency = fs/4; % at least 4 times f0 recommended

demod_channel_data=pipe.go({myDemodulation});

demodData = demod_channel_data.data;

pipe.channel_data=demod_channel_data;
pipe.scan=sca;
pipe.receive_apodization.window=uff.window.tukey25;
pipe.receive_apodization.f_number=F_number;

%% 
%
% The *pipeline* structure allows you to implement different beamformers 
% by combination of multiple built-in *processes*. By changing the *process*
% chain other beamforming sequences can be implemented. It returns yet 
% another *UFF* structure: *beamformed_data*.
% 
% To achieve the goal of this example, we use delay-and-sum (implemented in 
% the *das_mex()* process) as well as coherent compounding.

for aa = 1:length( alphaRx)
    pipe.receive_apodization.tilt = [alphaRx(aa) 0];
    pipe.channel_data.data = demodData(:,:,aa,:);
    pipe.channel_data.sequence = seq(aa);
    b_data=pipe.go({midprocess.das()});
    if aa == 1
        dsize = size( b_data.data);
        bfData = single( zeros( dsize(1), dsize(2), length( alphaRx), dsize(4) ) );
    end
    bfData(:,:,aa,:) = b_data.data;
end
b_data.modulation_frequency = f0;

if cc == 1
    PSFs = b_data;
    if F > chunkSize
        PSFs.data(:,:,Na,F) = zeros; % trick to allocate data matrix
    else
        PSFs.data = bfData(:,:,:,1:F);
    end
end
PSFs.data(:,:,:,cc:cc+size(point_position,1)-1) = bfData(:,:,:,1:size(point_position,1));


end
