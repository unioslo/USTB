function [PSFs,p] = PSFfunc_LinearProbe_SectorScan(flowLine, setup) % parameter structure not used in this example

%% Computation of a CPWI dataset with Field II and beamforming with USTB
%
% This code calculates Field II point scatterers of a sector
% scan using a linear probe, convert into a USTB channel_data object and beamform 
% the image using the USTB routines.
% The Field II simulation program (field-ii.dk) should be in MATLAB's path.
%
% date:     03.10.2017
% based on code written by :  Ole Marius Hoel RIndal <olemarius@olemarius.net>
%                             Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>
% modified by              :  Joergen Avdal <jorgen.avdal@ntnu.no>

%% Set default parameters

p.trans.f0              = 2.5e+06;          % Transducer center frequency [Hz]
p.trans.probe_bandwidth = 0.65;
p.trans.pitch           = 0.200e-3;
p.trans.kerf            = 0.020e-3;         % gap between elements [m]
p.trans.element_height  = 5e-3;
p.trans.lens_el         = 7e-2;             % position of the elevation focus
p.trans.N               = 96;
p.trans.pulse_duration  = 2.5;              % pulse duration [cycles]
p.trans.focal_depth     = 7e-2;
p.trans.c0              = 1540;            % speed of sound [m/s]
p.trans.fs              = 100e6;           % Sampling frequency [Hz]


p.acq.TxSpacingDeg = 0.5; %43/180*pi;
p.acq.noTx=15;                                      % number of angles 
p.acq.noMLA = 2;

p.scan.zStart = 60e-3;
p.scan.zEnd = 80e-3;
p.scan.Nz = 128;

p.run.chunkSize = 30;


%% Import setup parameters
fields = fieldnames(setup.trans);
for k=1:size(fields,1)
    if(isfield(p.trans,fields{k}))
        p.trans.(fields{k}) = setup.trans.(fields{k});
    else
        disp(['Transducer setup: ' fields{k} ' is not a valid parameter...']);
    end
end

fields = fieldnames(setup.acq);
for k=1:size(fields,1)
    if(isfield(p.acq,fields{k}))
        p.acq.(fields{k}) = setup.acq.(fields{k});
    else
        disp(['Acquisition setup: ' fields{k} ' is not a valid parameter...']);
    end
end

fields = fieldnames(setup.scan);
for k=1:size(fields,1)
    if(isfield(p.scan,fields{k}))
        p.scan.(fields{k}) = setup.scan.(fields{k});
    else
        disp(['Scan region setup: ' fields{k} ' is not a valid parameter...']);
    end
end

fields = fieldnames(setup.run);
for k=1:size(fields,1)
    if(isfield(p.run,fields{k}))
        p.run.(fields{k}) = setup.run.(fields{k});
    else
        disp(['Runtime setup: ' fields{k} ' is not a valid parameter...']);
    end
end

%% Dependent parameters
p.trans.lambda          = p.trans.c0/p.trans.f0;    % Wavelength

c0 = p.trans.c0;     % Speed of sound [m/s]
fs = p.trans.fs;    % Sampling frequency [Hz]
dt = 1/fs;     % Sampling step [s] 
 
%% field II initialisation
% 
% Next, we initialize the field II toolbox. Again, this only works if the 
% Field II simulation program (<field-ii.dk>) is in MATLAB's path. We also
% pass our set constants to it.

field_init(0);
set_field('c',c0);              % Speed of sound [m/s]
set_field('fs',fs);             % Sampling frequency [Hz]
set_field('use_rectangles',1);  % use rectangular elements



%% Setup probe object
probe = uff.linear_array();
probe.N                 = p.trans.N;                    % Number of elements
probe.pitch             = p.trans.pitch;                % probe.pitch [m]
probe.element_width     = p.trans.pitch-p.trans.kerf;   %  Width of element [m]
probe.element_height    = p.trans.element_height;       % Height of element [m]

 
%% Pulse definition
% 
% We then define the pulse-echo signal which is done here using the 
% *fresnel* simulator's *pulse* structure. We could also use 
% <http://field-ii.dk/ 'Field II'> for a more accurate model.

pulse = uff.pulse();
pulse.fractional_bandwidth = p.trans.probe_bandwidth; 
pulse.center_frequency = p.trans.f0;
t0 = (-1/pulse.fractional_bandwidth/p.trans.f0): dt : (1/pulse.fractional_bandwidth/p.trans.f0);
impulse_response = gauspuls(t0, p.trans.f0, pulse.fractional_bandwidth);
impulse_response = impulse_response-mean(impulse_response); % To get rid of DC

te = (-p.trans.pulse_duration/2/p.trans.f0): dt : (p.trans.pulse_duration/2/p.trans.f0);
excitation = square(2*pi*p.trans.f0*te+pi/2);
one_way_ir = conv(impulse_response,excitation);
two_way_ir = conv(one_way_ir,impulse_response);
lag = length(two_way_ir)/2+1;   

% calculate elevation lag
noSubAz=round(probe.element_width/(p.trans.lambda/8));        % number of subelements in the azimuth direction
noSubEl=round(probe.element_height/(p.trans.lambda/8));       % number of subelements in the elevation direction

elementPosEl = linspace(-probe.element_height/2, probe.element_height/2, 2*noSubEl+1);
elementPosEl = elementPosEl(2:2:end-1);
elFocalDelays = sqrt( elementPosEl.^2+p.trans.lens_el.^2)/c0;
txlagEl = (min(elFocalDelays) - max(elFocalDelays)  )*2;

%% Aperture Objects
% Next, we define the the mesh geometry with the help of Field II's
% *xdc_focused_array* function.

Th = xdc_focused_array( probe.N, probe.element_width, probe.element_height, p.trans.kerf, p.trans.lens_el, noSubAz, noSubEl, [0 0 Inf] );
Rh = xdc_focused_array( probe.N, probe.element_width, probe.element_height, p.trans.kerf, p.trans.lens_el, noSubAz, noSubEl, [0 0 Inf] );

% We also set the excitation, impulse response and baffle as below:
xdc_excitation (Th, excitation);
xdc_impulse (Th, impulse_response);
xdc_baffle(Th, 0);
xdc_center_focus(Th,[0 0 0]);
xdc_impulse (Rh, impulse_response);
xdc_baffle(Rh, 0);
xdc_center_focus(Rh,[0 0 0]);
 
 
%% Main loop
unitVec = [0 1].';
F=size(flowLine,1); % number of frames
% alpha=linspace(-p.acq.alpha_max,p.acq.alpha_max,p.acq.noTx); % vector of angles [rad]

TxSpacingRad = p.acq.TxSpacingDeg/180*pi;
alpha = ( -(p.acq.noTx-1)/2:1:(p.acq.noTx-1)/2 )*TxSpacingRad;

for cc = 1:p.run.chunkSize:size(flowLine, 1)
    
point_position = flowLine(cc:min( cc+p.run.chunkSize-1, size( flowLine,1) ),: );

% Set point amplitudes
point_amplitudes = ones(size(point_position,1),1);

%% output data
point_zdists = abs( point_position(:,3) );
point_dists = sqrt( sum( point_position.^2, 2) );
cropstart=floor(1.7*min(point_zdists(:))/c0/dt);    %minimum time sample, samples before this will be dumped
cropend=ceil(1.2*2*max(point_dists)/c0/dt);    % maximum time sample, samples after this will be dumped
CPW=zeros(cropend-cropstart+1,probe.N,p.acq.noTx,p.run.chunkSize);  % impulse response channel data
 
%% Compute CPW signals
disp('Field II: Computing CPW dataset');
for f=1:size( point_position,1)
    for n=1:p.acq.noTx
        clc
        disp( [num2str(f+cc-1) '/' num2str(F)]);

        rotMat = [cos( alpha(n) ) sin( alpha(n) ); -sin( alpha(n) ) cos( alpha(n) ) ];
        rotVec = rotMat*unitVec;
        focVec = rotVec*p.trans.focal_depth;
        
        % transmit aperture
        xdc_apodization(Th,0,ones(1,probe.N));
        xdc_focus(Th, 0, [focVec(1) 0 focVec(2)]);
        
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
        seq(n).source.azimuth=alpha(n);
        seq(n).source.distance=p.trans.focal_depth;
        seq(n).sound_speed=c0;
        seq(n).delay = txlagEl-lag*dt;
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

x_axis = linspace(alpha(1)-TxSpacingRad*(p.acq.noMLA-1)/2, alpha(end)+TxSpacingRad*(p.acq.noMLA-1)/2, p.acq.noMLA*p.acq.noTx);
z_axis = linspace(p.scan.zStart,p.scan.zEnd,p.scan.Nz);
sca=uff.sector_scan('azimuth_axis',x_axis.', 'depth_axis', z_axis.');


%% Pipeline
%
% With *channel_data* and a *scan* we have all we need to produce an
% ultrasound image. We now use a USTB structure *pipeline*, that takes an
% *apodization* structure in addition to the *channel_data* and *scan*.

pipe=pipeline();
pipe.channel_data=channel_data;

myDemodulation=preprocess.fast_demodulation;
myDemodulation.modulation_frequency = p.trans.f0;
myDemodulation.downsample_frequency = fs/4; % at least 4*p.trans.f0 recommended

demod_channel_data=pipe.go({myDemodulation});

pipe.channel_data=demod_channel_data;
pipe.scan=sca;
pipe.receive_apodization.window=uff.window.boxcar;
pipe.receive_apodization.f_number=0;

%% 
%
% The *pipeline* structure allows you to implement different beamformers 
% by combination of multiple built-in *processes*. By changing the *process*
% chain other beamforming sequences can be implemented. It returns yet 
% another *UFF* structure: *beamformed_data*.
% 
% To achieve the goal of this example, we use delay-and-sum (implemented in 
% the *das_mex()* process) as well as coherent compounding.
bmf = midprocess.das();
bmf.code = code.mexFast;
bmf.receive_apodization = uff.apodization();
bmf.transmit_apodization = uff.apodization();
bmf.transmit_apodization.window = uff.window.scanline;
bmf.transmit_apodization.MLA = p.acq.noMLA;
bmf.dimension = dimension.both;
b_data=pipe.go({bmf});
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

refDists = sqrt( (flowLine(:,1)-PSFs.scan.apex.x ).^2+(flowLine(:,3)-PSFs.scan.apex.z ).^2 );
p.phaseCorr = 2*refDists./c0*p.trans.f0;

end
