function [PSFs,p] = PSFfunc_L11_singlePlaneWave(flowLine, setup) % parameter structure not used in this example

%% Computation of a CPWI dataset with Field II and beamforming with USTB
%
% Creates a Field II simulation of single plane waves,
% converts into a USTB channel_data object and beamforms
% the image using the USTB routines. 
%
% date:               23.10.2020
% based on code by :  Ole Marius Hoel Rindal <olemarius@olemarius.net>
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

p.trans.f0                = 5.1333e+06;      % Transducer center frequency [Hz]
p.trans.lambda            = c0/p.trans.f0;         % Wavelength [m]
p.trans.element_height    = 5e-3;            % Height of element [m]
p.trans.pitch             = 0.300e-3;        % probe.pitch [m]
p.trans.kerf              = 0.03e-03;        % gap between elements [m]
p.trans.element_width     = p.trans.pitch-p.trans.kerf;  % Width of element [m]
p.trans.lens_el           = 20e-3;           % position of the elevation focus
p.trans.N                 = 128;             % Number of elements
p.trans.pulse_duration    = 4.5;             % pulse duration [cycles]

fields = fieldnames(setup.trans);
for k=1:size(fields,1)
    if(isfield(p.trans,fields{k}))
        p.trans.(fields{k}) = setup.trans.(fields{k});
    else
        disp(['Transducer setup: ' fields{k} ' is not a valid parameter...']);
    end
end

probe = uff.linear_array();
probe.element_height = p.trans.element_height;
probe.pitch = p.trans.pitch;
probe.element_width = p.trans.element_width;
probe.N     = p.trans.N;
%% Pulse definition
% 
% We then define the pulse-echo signal which is done here using the 
% *fresnel* simulator's *pulse* structure. We could also use 
% <http://field-ii.dk/ 'Field II'> for a more accurate model.

pulse = uff.pulse();
pulse.fractional_bandwidth = 0.65;        % probe bandwidth [1]
pulse.center_frequency = p.trans.f0;
t0 = (-1/pulse.fractional_bandwidth/p.trans.f0): dt : (1/pulse.fractional_bandwidth/p.trans.f0);
impulse_response = gauspuls(t0, p.trans.f0, pulse.fractional_bandwidth);
impulse_response = impulse_response-mean(impulse_response); % To get rid of DC

te = (-p.trans.pulse_duration/2/p.trans.f0): dt : (p.trans.pulse_duration/2/p.trans.f0);
excitation = square(2*pi*p.trans.f0*te+pi/2);
one_way_ir = conv(impulse_response,excitation);
two_way_ir = conv(one_way_ir,impulse_response);
lag = length(two_way_ir)/2+1;   

%% Aperture Objects
% Next, we define the the mesh geometry with the help of Field II's
% *xdc_focused_array* function.

noSubAz=round(probe.element_width/(p.trans.lambda/8));        % number of subelements in the azimuth direction
noSubEl=round(probe.element_height/(p.trans.lambda/8));       % number of subelements in the elevation direction
Th = xdc_focused_array (probe.N, probe.element_width, probe.element_height, p.trans.kerf, p.trans.lens_el, noSubAz, noSubEl, [0 0 Inf]); 
Rh = xdc_focused_array (probe.N, probe.element_width, probe.element_height, p.trans.kerf, p.trans.lens_el, noSubAz, noSubEl, [0 0 Inf]); 

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
F=size(flowLine,1);                        % number of frames
p.acq.F_number = 1.7;
p.acq.alpha_max = 0; %atan(1/2/p.acq.F_number);
p.acq.Na=1;                                      % number of plane waves 

fields = fieldnames(setup.acq);
for k=1:size(fields,1)
    if(isfield(p.acq,fields{k}))
        p.acq.(fields{k}) = setup.acq.(fields{k});
    else
        disp(['Acquisition setup: ' fields{k} ' is not a valid parameter...']);
    end
end

alpha=linspace(-p.acq.alpha_max,p.acq.alpha_max,p.acq.Na);   % vector of angles [rad]

%% Define phantom
% Define some points in a phantom for the simulation

p.run.chunkSize = 100;
fields = fieldnames(setup.run);
for k=1:size(fields,1)
    if(isfield(p.run,fields{k}))
        p.run.(fields{k}) = setup.run.(fields{k});
    else
        disp(['Runtime setup: ' fields{k} ' is not a valid parameter...']);
    end
end


for cc = 1:p.run.chunkSize:size(flowLine, 1)
    
point_position = flowLine(cc:min( cc+p.run.chunkSize-1, size( flowLine,1) ),: );

% Set point amplitudes
point_amplitudes = ones(size(point_position,1),1);

%% output data
point_zdists = abs( point_position(:,3) );
point_dists = sqrt( sum( point_position.^2, 2) );
cropstart=floor(1.7*min(point_zdists(:))/c0/dt);    %minimum time sample, samples before this will be dumped
cropend=ceil(1.2*2*max(point_dists)/c0/dt);    % maximum time sample, samples after this will be dumped
CPW=zeros(cropend-cropstart+1,probe.N,1,p.run.chunkSize);  % impulse response channel data
 
%% Compute CPW signals
disp('Field II: Computing CPW dataset');
for f=1:size(point_position,1)
    for n=1:p.acq.Na
        clc
        disp( [num2str(f+cc-1) '/' num2str(F)]);
         
        % transmit aperture
        xdc_apodization(Th,0,ones(1,probe.N));
        xdc_times_focus(Th,0,probe.geometry(:,1)'.*sin(alpha(n))/c0);
        
        % receive aperture
        xdc_apodization(Rh, 0, ones(1,probe.N));
        xdc_focus_times(Rh, 0, zeros(1,probe.N));

        % do calculation
        [v,t]=calc_scat_multi(Th, Rh, point_position(f,:), point_amplitudes(f));
         
        toffset = round(t/dt)-cropstart+1;
        numinds = min( size(v,1), size( CPW,1)-toffset );
        CPW( toffset+(1:numinds),:,n,f)=v(1:numinds,:);
                 
        % Save transmit sequence
        seq(n)=uff.wave();
        seq(n).probe=probe;
        seq(n).source.azimuth=alpha(n);
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
myDemodulation.modulation_frequency = p.trans.f0;
myDemodulation.downsample_frequency = fs/4; %at least 4*f0 recommended

demod_channel_data=pipe.go({myDemodulation});

pipe.channel_data=demod_channel_data;
pipe.scan=sca;
pipe.receive_apodization.window=uff.window.tukey25;
pipe.receive_apodization.f_number=p.acq.F_number;

%% 
%
% The *pipeline* structure allows you to implement different beamformers 
% by combination of multiple built-in *processes*. By changing the *process*
% chain other beamforming sequences can be implemented. It returns yet 
% another *UFF* structure: *beamformed_data*.
% 
% To achieve the goal of this example, we use delay-and-sum (implemented in 
% the *das_mex()* process) as well as coherent compounding.

b_data=pipe.go({midprocess.das()});
b_data.modulation_frequency = p.trans.f0; %myDemodulation.modulation_frequency;


if cc == 1
    PSFs = b_data;
    if F > p.run.chunkSize
        PSFs.data(:,:,:,F) = zeros; % trick to allocate data matrix
    else
        PSFs.data = PSFs.data(:,:,:,1:F);
    end
else
    PSFs.data(:,:,:,cc:cc+size(point_position,1)-1) = b_data.data(:,:,:,1:size(point_position,1)); %reshape( b_data.data, length( sca.z_axis), length( sca.x_axis), size( flowLine, 1) );
end

end

end