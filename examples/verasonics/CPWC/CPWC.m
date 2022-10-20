%% Adquire and record a CPWC dataset

% date:     18.05.2017
% authors:  Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>
%           Ole Marius Hoel Rindal <olemarius@olemarius.net>
%
%% Read me
% To run you should be in the Verasonics folder and activate it. For
% instance by:
%
% >> cd C:\Users\verasonics\Documents\Vantage-XXX
% >> activate
%
% Then run and choose "Add to Path"
%
% To save the data:
%  
%  1.- Freeze
%  2.- Close the VSX window

clear all; %close all;

% Uncomment the probe connected to your Verasonics
%probe = 'L11-5v';
%probe = 'L11-4v';
probe = 'L7-4';

%%
% Check that user is standing in a Verasonics Vantage folder
s = strsplit(pwd,filesep);
assert(isempty(findstr(s{end},'Vantage'))==0,'The Verasonics Software has not been detected. Please check that you have installed the Verasonics Software Release 3.0.7 (or later) and that you are standing in an activated Verasonics Vantage folder. For licensing check http://downloads.verasonics.com');

% Set of filename handling
filename='a.mat';
folderdata=['data/' datestr(now,'yyyymmdd')];
mkdir(folderdata);            
filedata=[probe(1:regexp(probe,'-')-1),'_CPWC_' datestr(now,'HHMMSS') '.uff'];
uff_filename=[folderdata '/' filedata];

% scan area in live view
scan_area=[-19e-3 0e-3 19e-3 50e-3];
pixels=[256 256];

%% SI units
c0=1540;                % reference speed of sound [m/s]
f0=5.1e6;               % central frequency [Hz]

ex_cycles = 2.5;        % number of cycles of the excitation signal (NOT half-cycles)
ex_power = 0.67;        % signal duty cycle [0, 1] that relates to the amount of power delivered to the element  
ex_polarity = 1;        % easy way of changing the polarity

no_frames = 2;          % number of frames to be acquired
no_packets = 1;         % number of apertures per plane wave
no_planes = 15;         % number of acquisitions (ergo plane waves)
buffer_size = 4096;     % number of samples in the buffer
end_depth = 180;        % number of times samples to be acquired, given in number of wavelengths

PRF=5000;                           % Pulse repetition frequency [pulses/s]
framerate=PRF/no_packets/no_planes; % frame rate [frames/second]

%% dependent values
lambda=c0/f0;           % wavelength [m]
Fs=4*f0;                % sampling frequency

%% angle sequence
maximun_angle=16*pi/180;    % maximum angle [rad]
if no_planes<2
    angles=0;
else
    angles=linspace(-maximun_angle,maximun_angle,no_planes); % angle vector [rad]
end

%% System parameters.
Resource.Parameters.numTransmit = 128;    % number of transmit channels.
Resource.Parameters.numRcvChannels = 128; % number of receive channels.
Resource.Parameters.speedOfSound = c0;    % set speed of sound in m/sec before calling computeTrans
Resource.Parameters.simulateMode = 1;     % 0 means no simulation, if hardware is present.

%% Specify Trans structure array.
Trans.name = probe;
Trans.units = 'mm'; % Explicit declaration avoids warning message when selected by default
Trans.frequency = f0/1e6;   % The center frequency for the A/D 4xFc sampling.
% note nominal center frequency in computeTrans is 7.813 MHz
Trans = computeTrans(Trans);  % The transducer is 'known' transducer so we can use computeTrans.

%% Specify SFormat structure array.
SFormat.transducer = probe';   % 192 element linear array with 0.96 lambda spacing
SFormat.scanFormat = 'RLIN';     % rectangular linear array scan
SFormat.radius = 0;              % ROC for curved lin. or dist. to virt. apex
SFormat.theta = 0;
SFormat.numRays = 1;             % no. of Rays (1 for Flat Focus)
SFormat.FirstRayLoc = [0,0,0];   % x,y,z
SFormat.rayDelta = Trans.numelements*Trans.spacing;  % spacing in radians(sector) or dist. between rays (wvlnghts)
SFormat.startDepth = 2;          % Acquisition depth in wavelengths
SFormat.endDepth = end_depth;    % This should preferrably be a multiple of 128 samples.  

%% Specify PData structure array.
PData.sFormat = 1;      % use first SFormat structure.
PData.Size(1) = pixels(2);  % Z
PData.Size(2) = pixels(1);  % X
PData.Size(3) = 1;          % single image page
PData.pdeltaX = ((Trans.ElementPos(end,1)-Trans.ElementPos(1,1))*1e-3 /PData.Size(2))/lambda;
PData.pdeltaZ = (end_depth*lambda/PData.Size(1))/lambda;
PData.Origin = [Trans.ElementPos(1,1)*1e-3/lambda, 0, 0e-3/lambda]; % x,y,z of upper lft crnr.

%% Specify Media object. 'pt1.m' script defines array of point targets.
%Media.MP=[0, 0, 20e-3/lambda, 1; Trans.ElementPos];
pt1
Media.function = 'movePoints';

%% Specify Resources.
Resource.RcvBuffer(1).datatype = 'int16';
Resource.RcvBuffer(1).rowsPerFrame = no_packets*no_planes*buffer_size; 
Resource.RcvBuffer(1).colsPerFrame = Resource.Parameters.numRcvChannels;
Resource.RcvBuffer(1).numFrames = no_frames;     % 40 frames used for RF cineloop.
Resource.InterBuffer(1).datatype = 'complex';
Resource.InterBuffer(1).rowsPerFrame = 2*1024;    % this is for greatest depth
Resource.InterBuffer(1).colsPerFrame = PData.Size(2);
Resource.InterBuffer(1).numFrames = 1;          % one intermediate buffer needed.
Resource.ImageBuffer(1).datatype = 'double';
Resource.ImageBuffer(1).rowsPerFrame = 1024;
Resource.ImageBuffer(1).colsPerFrame = PData.Size(2);
Resource.ImageBuffer(1).numFrames = no_frames;         % image buffer 
Resource.DisplayWindow(1).Title = [probe,' CPWC'];
Resource.DisplayWindow(1).AxesUnits = 'mm';
Resource.DisplayWindow(1).pdelta = PData.pdeltaX;
Resource.DisplayWindow(1).Position = [250,250, ...    % upper left corner position
    ceil(PData.Size(2)*PData.pdeltaX/Resource.DisplayWindow(1).pdelta), ... % width
    ceil(PData.Size(1)*PData.pdeltaZ/Resource.DisplayWindow(1).pdelta)];    % height
Resource.DisplayWindow(1).ReferencePt = [PData.Origin(1),PData.Origin(3)];   % 2D imaging is in the X,Z plane
Resource.DisplayWindow(1).Colormap = gray(256);

%% Specify Transmit waveform structure.  
TW.type = 'parametric';
% pulse expecification in [MHz, duty-cycle, number-of-half-cycles, boolean]
TW.Parameters = [f0/1e6, ex_power, ex_cycles*2, ex_polarity];

%% Specify TX structure array.  
TX = repmat(struct('waveform', 1, ...
                   'Origin', [0.0,0.0,0.0], ...
                   'Apod', ones(1,Resource.Parameters.numTransmit), ...
                   'focus', 0.0, ...
                   'Steer', [0.0,0.0], ...
                   'Delay', zeros(1,Resource.Parameters.numTransmit)), 1, no_planes);
% writing sequence angles
for n = 1:no_planes 
    TX(n).Steer = [angles(n), 0.0];
    TX(n).Delay = computeTXDelays(TX(n),'TOAE'); % use 'TransmitOnAllElements' flag 
end

%% Specify TGC Waveform structure.
TGC.CntrlPts = [139,535,650,710,770,932,992,1012];
TGC.rangeMax = SFormat.endDepth;
TGC.Waveform = computeTGCWaveform(TGC);

%% Specify Receive structure arrays -
%   endDepth - add additional acquisition depth to account for some channels
%              having longer path lengths.
%   InputFilter - The same coefficients are used for all channels. The
%              coefficients below give a broad bandwidth bandpass filter.
maxAcqLength = sqrt(SFormat.endDepth^2 + (Trans.numelements*Trans.spacing)^2) - SFormat.startDepth;
wlsPer128 = 128/(4*2); % wavelengths in 128 samples for 4 samplesPerWave
Receive = repmat(struct('Apod', ones(1,128), ...
                        'startDepth', SFormat.startDepth, ...
                        'endDepth', SFormat.startDepth + wlsPer128*ceil(maxAcqLength/wlsPer128), ...
                        'TGC', 1, ...
                        'bufnum', 1, ...
                        'framenum', 1, ...
                        'acqNum', 1, ...
                        'samplesPerWave', 4, ...
                        'mode', 0, ...
                        'callMediaFunc', 0),1,no_packets*no_planes*no_frames);

%% - Set event specific Receive attributes.
for i = 1:Resource.RcvBuffer(1).numFrames  % no_Apert*no_planes acquisitions per frame
    I = no_packets*no_planes*(i-1);
    Receive(I+1).callMediaFunc = 1;
    for j = 1:no_packets; 
        J=no_planes*(j-1);
        for k = 1:no_planes; % for each aperture acquire all angles    
            Receive(I+J+k).framenum = i;
            Receive(I+J+k).acqNum = J+k;
        end
    end
end

%% Specify Recon structure arrays.
Recon = struct('senscutoff', 0.6, ...
               'pdatanum', 1, ...
               'rcvBufFrame', -1, ...     % use most recently transferred frame
               'IntBufDest', [1,1], ...
               'ImgBufDest', [1,-1], ...  % auto-increment ImageBuffer each recon
               'RINums', (1:no_planes)');

ReconInfo = repmat(struct('mode', 4, ...  % default is to accumulate IQ data.
                   'txnum', 1, ...
                   'rcvnum', 1, ...
                   'regionnum', 0), 1, no_planes);

% Set specific ReconInfo attributes.
ReconInfo(1).mode = 3;
for n=1:no_planes
    ReconInfo(n).rcvnum = n;
    ReconInfo(n).txnum = n;  
end
ReconInfo(no_planes).mode = 5;               
               
%% Specify Process structure array.
Process(1).classname = 'Image';
Process(1).method = 'imageDisplay';
Process(1).Parameters = {'imgbufnum',1,...   % number of buffer to process.
                         'framenum',-1,...   % (-1 => lastFrame)
                         'pdatanum',1,...    % number of PData structure to use
                         'norm',1,...        % normalization method(1 means fixed)
                         'pgain',2.0,...            % pgain is image processing gain
                         'persistMethod','simple',...
                         'persistLevel',30,...
                         'interp',1,...      % method of interpolation (1=4pt interp)
                         'compression',0.5,...      % X^0.5 normalized to output word size
                         'reject',2,...
                         'mappingMode','full',...
                         'display',1,...      % display image after processing
                         'displayWindow',1};

%% Specify SeqControl structure arrays.
SeqControl(1).command = 'jump'; % jump back to start.
SeqControl(1).argument = 1;
SeqControl(2).command = 'timeToNextAcq';  % time between synthetic aperture acquisitions
SeqControl(2).argument = 1/PRF*1e6;       % PRF
SeqControl(3).command = 'timeToNextAcq';  % time between frames
SeqControl(3).argument = max([1/PRF*1e6 1/framerate*1e6 - no_planes/PRF*1e6]); % framerate = PRF
SeqControl(4).command = 'returnToMatlab';
nsc = 5; % nsc is count of SeqControl objects

%% Specify Event structure arrays.
n = 1; % n is count of Events
for i = 1:no_frames
    I = no_packets*no_planes*(i-1);
    for j = 1:no_packets
        J = no_planes*(j-1);
        for k= 1:no_planes
            % transmit/receive event & trigger
            Event(n).info = 'Transmit & receive event';
            Event(n).tx = k;         % use 1st TX structure.
            Event(n).rcv = I+J+k;    % use 1st Rcv structure.
            Event(n).recon = 0;      % no reconstruction.
            Event(n).process = 0;    % no processing
            Event(n).seqControl = [2]; % time between syn. aper. acqs.
            n = n+1;
        end
    end

    % Replace last event seqControl value.
    Event(n-1).seqControl = [3,nsc]; % time between frames, SeqControl struct defined below.
    SeqControl(nsc).command = 'transferToHost';
    nsc = nsc + 1;
    
    % Live reconstruction
    Event(n).info = 'Reconstruct & process'; 
    Event(n).tx = 0;         % no transmit
    Event(n).rcv = 0;        % no rcv
    Event(n).recon = 1;      % reconstruction
    Event(n).process = 1;    % processing
    Event(n).seqControl = 0;
    if floor(i/2) == i/2     % Exit to Matlab every 2nd frame 
        Event(n).seqControl = 4;
    end
    n = n+1;
end

% Jump to first event
Event(n).info = 'Jump back to first event';
Event(n).tx = 0;        % no TX
Event(n).rcv = 0;       % no Rcv
Event(n).recon = 0;     % no Recon
Event(n).process = 0; 
Event(n).seqControl = 1; % jump command


%% User specified UI Control Elements
% - Sensitivity Cutoff
UI(1).Control =  {'UserB7','Style','VsSlider','Label','Sens. Cutoff',...
                  'SliderMinMaxVal',[0,1.0,Recon(1).senscutoff],...
                  'SliderStep',[0.025,0.1],'ValueFormat','%1.3f'};
UI(1).Callback = text2cell('%-UI#1Callback');

% - Range Change
UI(2).Control = {'UserA1','Style','VsSlider','Label','Range',...
                 'SliderMinMaxVal',[64,320,SFormat.endDepth],'SliderStep',[0.1,0.2],'ValueFormat','%3.0f'};
UI(2).Callback = text2cell('%-UI#2Callback');

% Specify factor for converting sequenceRate to frameRate.
frameRateFactor = no_planes;

% Save all the structures to a .mat file.
save('a');

%% call VSX
VSX;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% converting the format to USTB 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
disp('Converting data format to USTB');
%% create USTB data class structure with Verasonics class
ver = verasonics();
% The Verasonics class needs these structs to create a USTB dataset
% NB! The Trans struct should be given first.
ver.Trans = Trans;
ver.RcvData = RcvData;          
ver.Receive = Receive;
ver.Resource = Resource;
ver.TW = TW;
ver.TX = TX;
ver.angles = angles;

% Create channel_data object
channel_data = ver.create_cpw_channeldata();

%% SCAN
sca=uff.linear_scan();
sca.x_axis = linspace(channel_data.probe.x(1),channel_data.probe.x(end),256).';
sca.z_axis = linspace(0,50e-3,256).';
 
%% Define processing pipeline and beamform
pipe=pipeline();
pipe.channel_data=channel_data;
pipe.scan=sca;

pipe.receive_apodization.window=uff.window.tukey50;
pipe.receive_apodization.f_number=1.7;

pipe.transmit_apodization.window=uff.window.tukey50;
pipe.transmit_apodization.f_number=1.7;

% Start the processing pipeline
b_data=pipe.go({midprocess.das postprocess.coherent_compounding});

% show
b_data.plot();

%% write channel_data to file the filname that was created in the beginning of this script
answer = questdlg('Do you want to save this dataset?');
if strcmp(answer,'Yes')
    channel_data.write(uff_filename,'channel_data');
end
return

% **** Callback routines to be converted by text2cell function. ****
%-UI#1Callback - Sensitivity cutoff change
ReconL = evalin('base', 'Recon');
for i = 1:size(ReconL,2)
    ReconL(i).senscutoff = UIValue;
end
assignin('base','Recon',ReconL);
Control = evalin('base','Control');
Control.Command = 'update&Run';
Control.Parameters = {'Recon'};
assignin('base','Control', Control);
return
%-UI#1Callback

%-UI#2Callback - Range change
simMode = evalin('base','Resource.Parameters.simulateMode');
% No range change if in simulate mode 2.
if simMode == 2
    set(hObject,'Value',evalin('base','SFormat.endDepth'));
    return
end
range = UIValue;
assignin('base','range',range);
SFormat = evalin('base','SFormat');
SFormat.endDepth = range;
assignin('base','SFormat',SFormat);
evalin('base','PData.Size(1) = ceil((SFormat.endDepth-SFormat.startDepth)/PData.pdeltaZ);');
evalin('base','[PData.Region,PData.numRegions] = createRegions(PData);');
evalin('base','Resource.DisplayWindow(1).Position(4) = ceil(PData.Size(1)*PData.pdeltaZ/Resource.DisplayWindow(1).pdelta);');
Receive = evalin('base', 'Receive');
Trans = evalin('base', 'Trans');
maxAcqLength = sqrt(range^2 + (Trans.numelements*Trans.spacing)^2)-SFormat.startDepth;
wlsPer128 = 128/(4*2);
for i = 1:size(Receive,2)
    Receive(i).endDepth = SFormat.startDepth + wlsPer128*ceil(maxAcqLength/wlsPer128);
end
assignin('base','Receive',Receive);
evalin('base','TGC.rangeMax = SFormat.endDepth;');
evalin('base','TGC.Waveform = computeTGCWaveform(TGC);');
Control = evalin('base','Control');
Control.Command = 'update&Run';
Control.Parameters = {'SFormat','PData','Receive','Recon','DisplayWindow','ImageBuffer'};
assignin('base','Control', Control);
assignin('base', 'action', 'displayChange');
return
%-UI#2Callback
