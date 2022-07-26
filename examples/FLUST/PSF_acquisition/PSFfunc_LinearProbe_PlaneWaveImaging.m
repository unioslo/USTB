function [PSFs,p,pipe] = PSFfunc_LinearProbe_PlaneWaveImaging(flowLine, setup) % parameter structure not used in this example

%% Computation of a CPWI dataset with Field II and beamforming with USTB
%
% Creates a Field II simulation of Na plane waves,
% converts into a USTB channel_data object and beamforms
% the image using the USTB routines. 
%
% NBNB: (Return data without compounding? Rx aperture not yet defined.)
%
% date:               08.04.2022
% based on code by :  Ole Marius Hoel Rindal <olemarius@olemarius.net>
%                     Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>
% modified by      :  Joergen Avdal <jorgen.avdal@ntnu.no>
%                     Ingvild Kinn Ekroll <ingvild.k.ekroll@ntnu.no>


%% Transducer definition L11-4v, 128-element linear array transducer
% 
% Our next step is to define the ultrasound transducer array we are using.
% Default values from the L11-4v 128 element Verasonics transducer 
p.trans.f0                = 5.1333e+06;      % Transducer center frequency [Hz]
p.trans.element_height    = 5e-3;            % Height of element [m]
p.trans.pitch             = 0.300e-3;        % probe.pitch [m]
p.trans.kerf              = 0.03e-03;        % gap between elements [m]
p.trans.lens_el           = 20e-3;           % position of the elevation focus
p.trans.N                 = 128;             % Number of elements
p.trans.pulse_duration    = 4.5;             % pulse duration [cycles]
p.trans.c0                = 1540;            % speed of sound [m/s]
p.trans.fs                = 100e6;           % Sampling frequency [Hz]

p.acq.F_number = 1.7;
p.acq.alphaTx = 0; %atan(1/2/p.acq.F_number);
p.acq.alphaRx = 0;

p.scan.xStart = -10e-3;
p.scan.xEnd = 10e-3;
p.scan.Nx = 256;
p.scan.zStart = 10e-3;
p.scan.zEnd = 30e-3;
p.scan.Nz = 256;
p.scan.rx_apod = 'tukey25';

p.run.chunkSize = 101;
p.run.runMode   = 'full';

%% Update parameters

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

p.trans.lambda            = p.trans.c0/p.trans.f0;   % Wavelength [m]
p.trans.element_width     = p.trans.pitch-p.trans.kerf;  % Width of element [m]

RTstart=floor(1.85*p.scan.zStart/p.trans.c0*p.trans.fs);    %minimum time sample, samples before this will be dumped
RTend=ceil(2.4*p.scan.zEnd/p.trans.c0*p.trans.fs);    % maximum time sample, samples after this will be dumped

c0=p.trans.c0;     % Speed of sound [m/s]
fs=p.trans.fs;     % Sampling frequency [Hz]
dt=1/fs;           % Sampling step [s] 
runChOnly = strcmp( p.run.runMode, 'chOnly'); % run FLUST on channel data
 
%% field II initialisation
% 
% Next, we initialize the field II toolbox. Again, this only works if the 
% Field II simulation program (<field-ii.dk>) is in MATLAB's path. We also
% pass our set constants to it.

field_init(0);
set_field('c',c0);              % Speed of sound [m/s]
set_field('fs',fs);             % Sampling frequency [Hz]
set_field('use_rectangles',1);  % use rectangular elements


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
% Th = xdc_linear_array (probe.N, probe.element_width, probe.element_height, p.trans.kerf, noSubAz, noSubEl, [0 0 Inf]); 
% Rh = xdc_linear_array (probe.N, probe.element_width, probe.element_height, p.trans.kerf, noSubAz, noSubEl, [0 0 Inf]); 

% We also set the excitation, impulse response and baffle as below:
xdc_excitation (Th, excitation);
xdc_impulse (Th, impulse_response);
xdc_baffle(Th, 0);
xdc_center_focus(Th,[0 0 0]);
xdc_impulse (Rh, impulse_response);
xdc_baffle(Rh, 0);
xdc_center_focus(Rh,[0 0 0]);

% calculate elevation lag
elementPosEl = linspace(-probe.element_height/2, probe.element_height/2, 2*noSubEl+1);
elementPosEl = elementPosEl(2:2:end-1);
elFocalDelays = sqrt( elementPosEl.^2+p.trans.lens_el.^2)/c0;
txlagEl = (min(elFocalDelays) - max(elFocalDelays)  )*2;

%% Define plane wave sequence
% Define the start_angle and number of angles
F=size(flowLine,1);                        % number of frames
[alphaTx, ~, ia] = unique( p.acq.alphaTx);
alphaRx = p.acq.alphaRx;

%% Define phantom
% Define some points in a phantom for the simulation

if runChOnly
    p.run.chunkSize = size( flowLine,1);
end

for cc = 1:p.run.chunkSize:size(flowLine, 1)

% Set point properties
point_position = flowLine(cc:min( cc+p.run.chunkSize-1, size( flowLine,1) ),: );
point_amplitudes = ones(size(flowLine,1),1);

point_amplitudes = ones(size(point_position,1),1);

%% output data
Ndown = 4; %downsampling rate
point_zdists = abs( point_position(:,3) );
point_dists = sqrt( sum( point_position.^2, 2) );
cropstart= max( floor(1.9*min(point_zdists(:))/c0/dt), RTstart);    %minimum time sample, samples before this will be dumped
cropend= min( ceil(2.4*max(point_dists)/c0/dt), RTend);    % maximum time sample, samples after this will be dumped
cropstart = cropstart-mod(cropstart-RTstart-1, Ndown)+Ndown-1; % to avoid downsampling issues
CPW=zeros(cropend-cropstart+1,probe.N,1,p.run.chunkSize);  % impulse response channel data

%% Compute CPW signals
disp('Field II: Computing CPW dataset');
for f=1:size(point_position,1)
    for n=1:length(alphaTx)
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

        toffset = round(t/dt)-cropstart+1;
        vstart = 1;
        if toffset < 0
            vstart = vstart-toffset;
            toffset = 0;
        end
        numinds = min( size(v,1)-vstart+1, size( CPW,1)-toffset );
        CPW( toffset+(1:numinds),:,n,f)=v(vstart:vstart+numinds-1,:);
    end
end

%% Channel Data
% 
% In this part of the code, we creat a uff data structure to specifically
% store the captured ultrasound channel data.
for n=1:length(alphaTx)
    seq(n)=uff.wave();
    seq(n).probe=probe;
    seq(n).source.azimuth=alphaTx(n);
    seq(n).source.distance=Inf;
    seq(n).sound_speed=c0;
    seq(n).delay = txlagEl-lag*dt;
end

channel_data = uff.channel_data();
channel_data.sampling_frequency = fs;
channel_data.sound_speed = c0;
if runChOnly
    channel_data.initial_time = (RTstart-1)*dt;
else
    channel_data.initial_time = (cropstart-1)*dt;
end
channel_data.pulse = pulse;
channel_data.probe = probe;
channel_data.sequence = seq;
channel_data.data = CPW/1e-26; %

%% 
for aa = 1:length( alphaRx)
    
    pipe(aa)=pipeline();
    pipe(aa).channel_data=channel_data;
    if aa == 1
        myDemodulation=preprocess.fast_demodulation;
        myDemodulation.modulation_frequency = p.trans.f0;
        myDemodulation.downsample_frequency = fs/Ndown; %at least 4*f0 recommended
        demod_channel_data=pipe(aa).go({myDemodulation});
        demodData=demod_channel_data.data;
        demod_channel_data.data = [];
    end
    pipe(aa).channel_data = demod_channel_data;
    pipe(aa).scan = uff.linear_scan('x_axis',linspace(p.scan.xStart,p.scan.xEnd,p.scan.Nx).', 'z_axis', linspace(p.scan.zStart,p.scan.zEnd,p.scan.Nz).');

    try
        pipe(aa).receive_apodization.window=uff.window.(p.scan.rx_apod);
    catch
        [memb, winNames] = enumeration('uff.window');
        disp('The rx apodization window is not valid. Use one of the following window functions:')
        winNames
    end
    pipe(aa).receive_apodization.f_number=p.acq.F_number;

    pipe(aa).receive_apodization.tilt = [alphaRx(aa) 0];
    pipe(aa).channel_data.sequence = seq(ia(aa));
    if ~runChOnly
        bmf = midprocess.das();
        bmf.code = code.mexFast;
        pipe(aa).channel_data.data = demodData(:,:,ia(aa),:);
        b_data=pipe(aa).go({bmf});
        if aa == 1
            dsize = size( b_data.data);
            bfData = single( zeros( dsize(1), dsize(2), length( alphaRx), dsize(4) ) );
        end
        bfData(:,:,aa,:) = b_data.data;
    end
end
b_data.modulation_frequency = p.trans.f0;

if runChOnly
    PSFs.data = demodData;
    PSFs.nSamps = length( RTstart:Ndown:RTend);
    PSFs.nChannels = size( PSFs.data, 2);
    PSFs.currinds = ( (cropstart:Ndown:cropend)-RTstart )./Ndown+1;
    for aa = 1:length( alphaRx)
        pipe(aa).channel_data.data = [];
    end
else
    if cc == 1
        PSFs = b_data;
        if F > p.run.chunkSize
            PSFs.data = bfData;
            PSFs.data(:,:,length(alphaRx),F) = zeros; % trick to allocate data matrix
        else
            PSFs.data = bfData(:,:,:,1:F);
        end
    else
        PSFs.data(:,:,:,cc:cc+size(point_position,1)-1) = bfData(:,:,:,1:size(point_position,1)); %reshape( b_data.data, length( sca.z_axis), length( sca.x_axis), size( flowLine, 1) );
    end
end

% add phase correction for FLUST interpolation step, improves numerical stability
p.phaseVecsTx = [sin(alphaTx); zeros( size( alphaTx) ); cos(alphaTx)];
p.phaseVecsRx = [sin(alphaRx); zeros( size( alphaRx) ); cos(alphaRx)];
refDists = flowLine*(p.phaseVecsTx+p.phaseVecsRx);
p.phaseCorr = refDists./c0*p.trans.f0;

end