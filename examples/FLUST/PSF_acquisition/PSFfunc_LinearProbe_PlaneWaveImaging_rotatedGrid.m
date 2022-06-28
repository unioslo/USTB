function [PSFs,p] = PSFfunc_LinearProbe_PlaneWaveImaging_rotatedGrid(flowLine, setup) % parameter structure not used in this example

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
%                     Anne Saris, for usage of rotated linear_array grid


%% Transducer definition L11-4v, 128-element linear array transducer
% 
% Our next step is to define the ultrasound transducer array we are using.
% Default values from the L11-4v 128 element Verasonics transducer 

p.trans.f0                = 5.1333e+06;      % Transducer center frequency [Hz]
p.trans.element_height    = 5e-3;            % Height of element [m]
p.trans.pitch             = 0.300e-3;        % probe.pitch [m]
p.trans.kerf              = 0.03e-03;        % gap between elements [m]
p.trans.lens_el           = 20e-3;           % position of the elevation focus
p.trans.N                 = 288;             % Number of physical elements
p.trans.Na                = 128;             % Number of active elements
p.trans.pulse_duration    = 4.5;             % pulse duration [cycles]
p.trans.c0                = 1540;            % speed of sound [m/s]
p.trans.fs                = 100e6;           % Sampling frequency [Hz]

fields = fieldnames(setup.trans);
for k=1:size(fields,1)
    if(isfield(p.trans,fields{k}))
        p.trans.(fields{k}) = setup.trans.(fields{k});
    else
        disp(['Transducer setup: ' fields{k} ' is not a valid parameter...']);
    end
end

p.trans.lambda            = p.trans.c0/p.trans.f0;   % Wavelength [m]
p.trans.element_width     = p.trans.pitch-p.trans.kerf;  % Width of element [m]


%% Basic Constants
% 
% Our first step is to define some basic constants for our imaging scenario
% - below, we set the speed of sound in the tissue, sampling frequency and
% sampling step size in time.

c0=p.trans.c0;     % Speed of sound [m/s]
fs=p.trans.fs;    % Sampling frequency [Hz]
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




probe = uff.linear_array();
probe.element_height = p.trans.element_height;
probe.pitch = p.trans.pitch;
probe.element_width = p.trans.element_width;
probe.N     = p.trans.N;


%% Calculate active aperture position
elemS = zeros(size(setup.acq.alphaTx));
elemE = zeros(size(setup.acq.alphaTx));
apodPos = zeros(size(setup.acq.alphaTx));

if p.trans.N ~= p.trans.Na
    for i = 1:size(setup.acq.alphaTx,2)
        elempos = linspace(-(p.trans.N-1)/2,(p.trans.N-1)/2,p.trans.N)*p.trans.pitch;              % x-coordinates of the elements                    
        apodCenter = ((setup.scan.zEnd-setup.scan.zStart)/2 + setup.scan.zStart) * tan(-1*setup.acq.alphaTx(i));         % calculate active centre element
        [~,centerElement]   = min(abs(elempos-apodCenter));

        % calculating elements used 
        if (elempos(centerElement)-apodCenter) > 0
            leftmostElement     = centerElement-p.trans.Na/2;
            rightmostElement    = centerElement+p.trans.Na/2-1;
        else
            leftmostElement     = centerElement-p.trans.Na/2+1;
            rightmostElement    = centerElement+p.trans.Na/2;
        end

        if leftmostElement < 1
            leftmostElement     = 1;
            rightmostElement    = p.trans.Na;      
        end

        if rightmostElement > probe.N
            leftmostElement     = probe.N - p.trans.Na + 1;
            rightmostElement    = probe.N;
        end  

        elemS(i) = leftmostElement;
        elemE(i) = rightmostElement;
        apodPos(i) = apodCenter;
    end
else
    % full probe is used for each transmit
    elemS = zeros(size(setup.acq.alphaTx,2)) + 1;
    elemE = zeros(size(setup.acq.alphaTx,2)) + p.trans.N;
    apodPos = zeros(size(setup.acq.alphaTx,2));
end

p.trans.elemStart = elemS;
p.trans.elemEnd = elemE;
p.trans.apodCenter = apodPos;
    
clear elemS elemE apodPos

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
p.acq.F_number = 1.7;
p.acq.alphaTx = 0; %atan(1/2/p.acq.F_number);
p.acq.alphaRx = 0;

fields = fieldnames(setup.acq);
for k=1:size(fields,1)
    if(isfield(p.acq,fields{k}))
        p.acq.(fields{k}) = setup.acq.(fields{k});
    else
        disp(['Acquisition setup: ' fields{k} ' is not a valid parameter...']);
    end
end

[alphaTx, ~, ia] = unique( p.acq.alphaTx);
alphaRx = p.acq.alphaRx;
nA = length(alphaTx);

%% Define phantom
% Define some points in a phantom for the simulation

p.run.chunkSize = 101;
fields = fieldnames(setup.run);
for k=1:size(fields,1)
    if(isfield(p.run,fields{k}))
        p.run.(fields{k}) = setup.run.(fields{k});
    else
        disp(['Runtime setup: ' fields{k} ' is not a valid parameter...']);
    end
end


for cc = 1:p.run.chunkSize:F
    
% Select chuncks of positions (ie frames)   
point_position = flowLine(cc:min( cc+p.run.chunkSize-1, size( flowLine,1) ),: );

% Set point amplitudes
point_amplitudes = ones(size(point_position,1),1);

%% output data
point_zdists = abs( point_position(:,3) );  % depth position
point_dists = sqrt( sum( point_position.^2, 2) );  % distance between point and center TD (0,0,0)
% cropstart=floor(1.7*min(point_zdists(:))/c0/dt);    %minimum time sample, samples before this will be dumped
cropstart=floor(1*min(point_zdists(:))/c0/dt);    %minimum time sample, samples before this will be dumped
cropend=ceil(1.5*2*max(point_dists)/c0/dt);    % maximum time sample, samples after this will be dumped
CPW=zeros(cropend-cropstart+1,probe.N,nA,p.run.chunkSize);  % impulse response channel data
 
%% Compute CPW signals
disp('Field II: Computing CPW dataset');
for f=1:size(point_position,1)
    for n=1:nA
        clc
        disp( [num2str(f+cc-1) '/' num2str(F)]);
         
        % transmit aperture
        apod = zeros(1,probe.N);
        apod(p.trans.elemStart(n):p.trans.elemEnd(n)) = 1;
        xdc_apodization(Th,0,apod);
%         xdc_apodization(Th,0,ones(1,probe.N));
        xdc_times_focus(Th,0,probe.geometry(:,1)'.*sin(alphaTx(n))/c0);
        
        % receive aperture
        xdc_apodization(Rh, 0, apod);
%         xdc_apodization(Rh, 0, ones(1,probe.N));
        xdc_focus_times(Rh, 0, zeros(1,probe.N));
        
        % do calculation
        [v,t]=calc_scat_multi(Th, Rh, point_position(f,:), point_amplitudes(f));
         
        toffset = round(t/dt)-cropstart+1;
        numinds = min( size(v,1), size( CPW,1)-toffset );
        CPW( toffset+(1:numinds),:,n,f)=v(1:numinds,:);
                 
        % Save transmit sequence
        seq(n)=uff.wave();
        seq(n).probe=probe;
        seq(n).source.azimuth=alphaTx(n);
        seq(n).source.distance=Inf;
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
% interest. For our example here, we use the *linear_scan_rotated* structure, 
% which is defined with four components: the lateral range and the 
% depth range, rotation angle and center of rotation. *scan* too has a useful *plot* method it can call.

p.scan.xStart = -10e-3;
p.scan.xEnd = 10e-3;
p.scan.Nx = 256;
p.scan.zStart = 10e-3;
p.scan.zEnd = 30e-3;
p.scan.Nz = 256;
p.scan.rx_apod = 'tukey25';

fields = fieldnames(setup.scan);
for k=1:size(fields,1)
    if(isfield(p.scan,fields{k}))
        p.scan.(fields{k}) = setup.scan.(fields{k});
    else
        disp(['Scan region setup: ' fields{k} ' is not a valid parameter...']);
    end
end

% Center of rotation
xc = p.scan.xStart+((p.scan.xEnd-p.scan.xStart)/2);
zc = p.scan.zStart + ((p.scan.zEnd-p.scan.zStart)/2);

% Create scan
sca = cell(1,nA);
for a = 1:length(alphaTx)
    sca{a} = uff.linear_scan_rotated('x_axis',linspace(p.scan.xStart,p.scan.xEnd,p.scan.Nx).', 'z_axis', linspace(p.scan.zStart,p.scan.zEnd,p.scan.Nz).', 'rotation_angle', alphaTx(a) ,'center_of_rotation',[xc,0,zc]');
end

% visualize rotated grids
if 0
    figure, plot(sca{1}.x*1000, sca{1}.z*1000,'.b'),
    hold on, plot(sca{2}.x*1000, sca{2}.z*1000,'.g'), axis image
    c = axis; xlabel('X (mm)'), ylabel('Z (mm)'), set(gca,'ydir','reverse'), title('Rotated linear scan')

%     figure, pcolor(reshape(sca{1}.x*1000, [sca{1}.N_x_axis sca{1}.N_z_axis]) , reshape(sca{1}.z*1000,[sca{1}.N_x_axis sca{1}.N_z_axis] ),reshape(sca{1}.reference_distance,[sca{1}.N_x_axis sca{1}.N_z_axis])), shading interp
%     axis(c), xlabel('X (mm)'), ylabel('Z (mm)'), title('reference distance angle 1')
%     axis image, set(gca,'ydir','reverse')
end



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
pipe.channel_data = demod_channel_data;
demodData=demod_channel_data.data;

% pipe.scan=sca;
try
    pipe.receive_apodization.window=uff.window.(p.scan.rx_apod);
catch
    [memb, winNames] = enumeration('uff.window');
    disp('The rx apodization window is not valid. Use one of the following window functions:')
    winNames
end
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


% The actual beamforming
for aa = 1:length( alphaRx)
    % Scan, (x,y) position of pixels
    pipe.scan = sca{aa};
        
    pipe.receive_apodization.tilt = [alphaRx(aa) 0];
    pipe.channel_data.data = demodData(:,:,ia(aa),:);
    pipe.channel_data.sequence = seq(ia(aa));
    myDas = midprocess.das();
    myDas.code = code.mexFast;
    b_data=pipe.go({myDas});
    if aa == 1
        dsize = size( b_data.data);
        bfData = single( zeros( dsize(1), dsize(2), length( alphaRx), dsize(4) ) );
    end
    bfData(:,:,aa,:) = b_data.data;
end
b_data.modulation_frequency = p.trans.f0;

% Store beamformed data in PSF.data
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
p.phaseVecsTx = [sin(p.acq.alphaTx); zeros( size( p.acq.alphaTx) ); cos(p.acq.alphaTx)];
p.phaseVecsRx = [sin(p.acq.alphaRx); zeros( size( p.acq.alphaRx) ); cos(p.acq.alphaRx)];
refDists = flowLine*(p.phaseVecsTx+p.phaseVecsRx);
p.phaseCorr = refDists./c0*p.trans.f0;
end