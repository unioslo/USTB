% Acoustical Radiation Force Imaging Example with Verasonics
%
% A modified version of the original Verasonics script adding the
% interaction with the USTB code. The USTB code only displayes the
% estimated delay, and not the b-mode.
%
% NB! There seems to be a bug in the Verasonics part of the script so that
% you have to toggle the "push cycle" slider to update the push cycle to
% the value shown on the slider.
%
% _Author: Ole Marius Hoel Rindal <olemarius@olemarius.net> 05.07.2017_

clear all;

%% UFF file for USTB

% Uncomment the probe connected to your Verasonics
probe = 'L11-5v';
%probe = 'L11-4v';
%probe = 'L7-4';

% Set of filename handling
folderdata=['data/' datestr(now,'yyyymmdd')];
mkdir(folderdata);            
filedata=['SWE_',probe(1:regexp(probe,'-')-1),'_', datestr(now,'HHMMSS') '.uff'];
uff_filename=[folderdata '/' filedata];

%% System parameters
filename = ('L7-4ShearWave');

na          = 50;      % Set na = number of detect acquisitions.
SWIFrames   = 4;
BmodeFrames = 20;

powermax   = 250;      % scaling of the display function
pushCycle  = 1000;
maxVoltage = 65;

% Define ROI for IQ processing, can be changed in GUI
SWIFocusX = 0;
SWIFocusZ = 50;
SWIROI.width = 80; 
SWIROI.height = 50;  % [width and height in wavelength]

% Define system parameters.
Resource.Parameters.numTransmit = 128;      % number of transmit channels.
Resource.Parameters.numRcvChannels = 128;    % number of receive channels.
Resource.Parameters.speedOfSound = 1540;    % set speed of sound in m/sec before calling computeTrans
Resource.Parameters.verbose = 2;
Resource.Parameters.initializeOnly = 0;
Resource.Parameters.simulateMode = 0;
%  Resource.Parameters.simulateMode = 1 forces simulate mode, even if hardware is present.
%  Resource.Parameters.simulateMode = 2 stops sequence and processes RcvData continuously.

% Specify Trans structure array.
Trans.name = probe;
Trans.units = 'mm';
Trans = computeTrans(Trans); 
Trans.maxHighVoltage = maxVoltage;  % set maximum high voltage limit for pulser supply.

%% Imaging parameters

P.startDepth = 5;   % Acquisition depth in wavelengths
P.endDepth = 160;   % This should preferrably be a multiple of 128 samples.

% Specify PData(1) structure array for Bmode Imaging
PData(1).PDelta = [Trans.spacing,0,0.5];
PData(1).Size(1) = ceil((P.endDepth-P.startDepth)/PData(1).PDelta(3)); % startDepth, endDepth and pdelta set PData(1).Size.
PData(1).Size(2) = ceil((Trans.numelements*Trans.spacing)/PData(1).PDelta(1));
PData(1).Size(3) = 1;      % single image page
PData(1).Origin = [-Trans.spacing*(Trans.numelements-1)/2,0,P.startDepth]; % x,y,z of upper lft crnr.

% Specify PData(2) structure array for Shearwave visulization
PData(2) = PData(1);
PData(2).PDelta = [0.5,0,0.25];
PData(2).Size(1) = ceil((P.endDepth-P.startDepth)/PData(2).PDelta(3)); % startDepth, endDepth and pdelta set PData(1).Size.
PData(2).Size(2) = ceil((Trans.numelements*Trans.spacing)/PData(2).PDelta(1));
PData(2).Region.Shape = struct(...
    'Name','Rectangle',...
    'Position',[SWIFocusX,0,SWIFocusZ-SWIROI.height/2],...
    'width', SWIROI.width,...
    'height', SWIROI.height);
PData(2).Region = computeRegions(PData(2));

% PData(2).Size(1) = ceil(SWIROI.height/PData(2).PDelta(3)); % startDepth, endDepth and pdelta set PData(2).Size.
% PData(2).Size(2) = ceil(SWIROI.width/PData(2).PDelta(1));
% PData(2).Size(3) = 1;      % single image page
% PData(2).Origin = [(SWIFocusX-SWIROI.width)/2,0,SWIFocusZ-SWIROI.height/2]; % x,y,z of upper lft crnr in wavelength

% Specify Media object. 'pt1.m' script defines array of point targets.
pt1;
Media.function = 'movePoints';

%% Specify Resources.
% RcvBuffer for all raw data
Resource.RcvBuffer(1).datatype = 'int16';
Resource.RcvBuffer(1).rowsPerFrame = 2048;
Resource.RcvBuffer(1).colsPerFrame = 128;
Resource.RcvBuffer(1).numFrames = BmodeFrames;

% RcvBuffer for all raw data
Resource.RcvBuffer(2).datatype = 'int16';
Resource.RcvBuffer(2).rowsPerFrame = na*2048;
Resource.RcvBuffer(2).colsPerFrame = 128;
Resource.RcvBuffer(2).numFrames = SWIFrames;

% InterBuffer for Bmode (not required)
Resource.InterBuffer(1).numFrames = 1;

% InterBuffer for SWI visualizaion, colsPerFrame must be larger enough for
% PData(2) update
Resource.InterBuffer(2).numFrames = 1;
Resource.InterBuffer(2).pagesPerFrame = na;

% ImageBuffer for reference Bmode image
Resource.ImageBuffer(1).datatype = 'double';
Resource.ImageBuffer(1).numFrames = BmodeFrames;

Resource.DisplayWindow(1).Title = filename;
Resource.DisplayWindow(1).pdelta = 0.35;
ScrnSize = get(0,'ScreenSize');
DwWidth = ceil(PData(1).Size(2)*PData(1).PDelta(1)/Resource.DisplayWindow(1).pdelta);
DwHeight = ceil(PData(1).Size(1)*PData(1).PDelta(3)/Resource.DisplayWindow(1).pdelta);
Resource.DisplayWindow(1).Position = [250,(ScrnSize(4)-(DwHeight+150))/2, ...
    DwWidth, DwHeight];  % lower left corner position
Resource.DisplayWindow(1).ReferencePt = [PData(1).Origin(1),PData(1).Origin(3)]; % 2D imaging is in the X,Z plane
Resource.DisplayWindow(1).Colormap = gray(256);
Resource.DisplayWindow(1).numFrames = BmodeFrames;

%% Transmit parameters
% Specify Transmit waveform structure.
% - detect waveform
TW(1).type = 'parametric';
TW(1).Parameters = [Trans.frequency,0.67,2,1];   % A, B, C, D

% - Push waveform.
TW(2).type = 'parametric';
TW(2).Parameters = [Trans.frequency,1,pushCycle*2,1];  %

% Set TPC profile 5 high voltage limit.
TPC(5).maxHighVoltage = Trans.maxHighVoltage;

% Specify TX structure array.
TX = repmat(struct('waveform', 1, ...
    'Origin', [0.0,0.0,0.0], ...
    'focus', 0.0, ...
    'Steer', [0.0,0.0], ...
    'Apod', ones(1,Trans.numelements), ...
    'Delay', zeros(1,Trans.numelements)), 1, 2);

% - Set event specific TX attributes for push.
TX(2).waveform = 2;
TX(2).focus = SWIFocusZ;       % wavelength, can be changed in the GUI
TX(2).focusX = SWIFocusX;      % can be changed in the GUI
TX(2).pushElements = 32;       % can be changed in the GUI
TX(2).sysExtendBL = 1;

% Apod = 1 for pushing elements
TX(2).Apod = zeros(1,Trans.numelements);
TX(2).Apod(64-TX(2).pushElements/2 +1 : 64+TX(2).pushElements/2) = 1;
TX(2).Delay = computeTXDelays(TX(2));

%% Receive parameters
% Specify Receive structure arrays.
% -- Receive will be changed after SWI on.
% -- Compute the maximum receive path length, using the law of cosines.
maxAcqLength = ceil(sqrt(P.endDepth^2 + ((Trans.numelements-1)*Trans.spacing)^2));
wlsPer128 = 128/(4*2); % wavelengths in 128 samples for 4 samplesPerWave

% Total (na+1)*RcvBuffer.numFrames  (1 regular flash and na detections)
Receive = repmat(struct('Apod', ones(1,Trans.numelements), ...
    'startDepth', P.startDepth, ...
    'endDepth', P.startDepth + wlsPer128*ceil(maxAcqLength/wlsPer128), ...
    'TGC', 1, ...
    'bufnum', 1, ...
    'framenum', 1, ...
    'acqNum', 1, ...
    'sampleMode', 'NS200BW', ...
    'mode', 0, ...
    'callMediaFunc', 0), 1, BmodeFrames+na*SWIFrames);

% % Receive(1) to Receive(20) are regular flash imaging
for i = 1:BmodeFrames
    % -- Acquisition for full frame.
    Receive(i).callMediaFunc = 1;  % make media move per frame
    Receive(i).framenum = i;
end

d = i; % detection starts from i+1, here is 21;

% - Set event specific Receive attributes for each frame.
for i = 1:SWIFrames
    for j = 1:na  % na acquisitions per frame
        Receive(na*(i-1)+j+d).callMediaFunc = 1;  % make media move per frame
        Receive(na*(i-1)+j+d).bufnum = 2;
        Receive(na*(i-1)+j+d).framenum = i;
        Receive(na*(i-1)+j+d).acqNum = j;
    end
end

% Specify TGC Waveform structure.
TGC.CntrlPts = [500,590,650,710,770,800,850,950];
TGC.rangeMax = P.endDepth;
TGC.Waveform = computeTGCWaveform(TGC);

%% Reconstruction parameters
% Specify Recon structure arrays.
% - We need a Recon structure for the 2D image which will be used for each frame.
% Recon(1) is used in regular flash imaging
% Recon(2) is used in Bmode imaging after SWI on
% - 10 IQData frames will be stored after Recon(3) to Recon(12)

Recon = repmat(struct(...
    'senscutoff', 0.6, ...
    'pdatanum', 1, ...
    'rcvBufFrame',-1, ...
    'IntBufDest', [2,1], ...
    'ImgBufDest', [0,0], ...
    'RINums',1),1,3);

Recon(1).IntBufDest = [1,1];
Recon(1).ImgBufDest = [1,-1];
Recon(1).RINums = 1;

Recon(2).IntBufDest = [0,0];
Recon(2).ImgBufDest = [1,-1];
Recon(2).RINums = 2;

Recon(3).pdatanum = 2;
Recon(3).IntBufDest = [2,1];
Recon(3).ImgBufDest = [0,0];
Recon(3).RINums = 3:na+2;

% Define ReconInfo structures.
% - ReconInfo for 2D frame.
ReconInfo(1) = struct('mode','replaceIntensity', ...  % intensity output.
    'txnum',1, ...
    'rcvnum',1, ...
    'regionnum',1);

ReconInfo(2) = struct('mode','replaceIntensity', ...  % intensity output.
    'txnum',1, ...
    'rcvnum',d+1, ...                % the first Acq will be shown in the display window
    'regionnum',1);

k = 2; % k keeps track of index of last ReconInfo defined
% We need na ReconInfo structures for IQ reconstructions.

ReconInfo((k+1):(k+na)) = repmat(struct('mode', 'replaceIQ', ... % IQ output
    'txnum', 1, ...
    'rcvnum', 1, ...
    'regionnum', 1), 1, na);

% - Set specific ReconInfo attributes.
for j = 1:na  % For each row in the column
    ReconInfo(k+j).txnum = 1;
    ReconInfo(k+j).rcvnum = j+d;
    ReconInfo(k+j).pagenum = j;
end


%% Process parameters
% Specify Process structure array. (1) is used for B-mode imaging
% Specify Process structure array.
pers = 20;
Process(1).classname = 'Image';
Process(1).method = 'imageDisplay';
Process(1).Parameters = {'imgbufnum',1,...   % number of buffer to process.
                         'framenum',-1,...   % (-1 => lastFrame)
                         'pdatanum',1,...    % number of PData structure to use
                         'pgain',1.0,...            % pgain is image processing gain
                         'reject',2,...      % reject level 
                         'persistMethod','simple',...
                         'persistLevel',pers,...
                         'interpMethod','4pt',...  %method of interp. (1=4pt)
                         'grainRemoval','none',...
                         'processMethod','none',...
                         'averageMethod','none',...
                         'compressMethod','power',...
                         'compressFactor',40,...
                         'display',1,...      % display image after processing
                         'displayWindow',1};

% EF1 is external function for UI control
Process(2).classname = 'External';
Process(2).method = 'UIControl';
Process(2).Parameters = {'srcbuffer','none'};

% EF2 is external function for shearwave visualization
Process(3).classname = 'External';
Process(3).method = 'processIQ';
Process(3).Parameters = {'srcbuffer','inter',... % name of buffer to process.
    'srcbufnum',2,...
    'srcframenum',1,...
    'dstbuffer','none'};

%% SeqControl and Events for shearwave generation

% - Change to Profile 1 (low power)
SeqControl(1).command = 'setTPCProfile';
SeqControl(1).condition = 'immediate';
SeqControl(1).argument = 1;
% - Change to Profile 5 (high power)
SeqControl(2).command = 'setTPCProfile';
SeqControl(2).condition = 'immediate';
SeqControl(2).argument = 5;
% - Noop to allow time for charging external cap.
SeqControl(3).command = 'noop';
SeqControl(3).argument = 500000; % wait 100 msec.

% - time between regular flash imaging
SeqControl(4).command = 'timeToNextAcq';
SeqControl(4).argument = 10000;               % 10 ms
% - time between push and detect acquisitions
SeqControl(5).command = 'timeToNextAcq';
SeqControl(5).argument = 500;               % 500usec
afterpush = 5;
% - time between detect acquisitions
SeqControl(6).command = 'timeToNextAcq';
SeqControl(6).argument = 100;               % 100usec 
PRF=6;
% - time between frames
SeqControl(7).command = 'timeToNextEB';    % set time between extended bursts
SeqControl(7).argument = 200000;            % 200000usec = 200msec (~ 5 fps)
TTNEB=7;

% - Return to Matlab
SeqControl(8).command = 'returnToMatlab';
% - Trigger out
SeqControl(9).command = 'triggerOut';

% - Jump back to start will be defined in the event due to the conditional
% event coding

nsc = length(SeqControl)+1;

% Specify Event structure arrays.
n = 1;

Event(n).info = 'ext func for UI control';
Event(n).tx = 0;         % no transmit
Event(n).rcv = 0;        % no rcv
Event(n).recon = 0;      % reconstruction
Event(n).process = 2;    % process
Event(n).seqControl = 0;
n = n+1;

%% Regular flash imaging starts fron event(nStartFlash)
nStartFlash = n;

% Switch to TPC profile 1 (low power) for flash imaging
Event(n).info = 'Switch to profile 1.';
Event(n).tx = 0;
Event(n).rcv = 0;
Event(n).recon = 0;
Event(n).process = 0;
Event(n).seqControl = 1;
n = n+1;

nStartAcqFlash = n;

for i = 1:BmodeFrames
    Event(n).info = 'trigger out'; % Only needed for verifying push waveform with scope.
    Event(n).tx = 0;
    Event(n).rcv = 0;
    Event(n).recon = 0;
    Event(n).process = 0;
    Event(n).seqControl = 9;
    n = n+1;
    
    Event(n).info = 'Full aperature.';
    Event(n).tx = 1;         % use 1st TX structure.
    Event(n).rcv = i;      % use ith Rcv structure for the ith frame.
    Event(n).recon = 0;      % no reconstruction.
    Event(n).process = 0;    % no processing
    Event(n).seqControl = [4,nsc]; % time between frames, SeqControl struct defined below.
    SeqControl(nsc).command = 'transferToHost';
    nsc = nsc + 1;
    n = n+1;
    
    Event(n).info = 'recon and process';
    Event(n).tx = 0;         % no transmit
    Event(n).rcv = 0;        % no rcv
    Event(n).recon = 1;      % reconstruction
    Event(n).process = 1;    % process
    Event(n).seqControl = 8;
    n = n+1;
end

Event(n).info = 'Jump back';
Event(n).tx = 0;        % no TX
Event(n).rcv = 0;       % no Rcv
Event(n).recon = 0;     % no Recon
Event(n).process = 0;
Event(n).seqControl = nsc;
SeqControl(nsc).command = 'jump';
SeqControl(nsc).argument = nStartAcqFlash;

n = n+1;
nsc = nsc+1;

%% Shear Wave Imaging starts from event(nStartPush)
nStartPush = n;

% Switch to TPC profile 5 (high power) and allow time for charging ext. cap.
Event(n).info = 'Switch to profile 5.';
Event(n).tx = 0;
Event(n).rcv = 0;
Event(n).recon = 0;
Event(n).process = 0;
Event(n).seqControl = 2;
n = n+1;

Event(n).info = 'noop for charging ext. cap.';
Event(n).tx = 0;
Event(n).rcv = 0;
Event(n).recon = 0;
Event(n).process = 0;
Event(n).seqControl = 3;
n = n+1;

nStartAcqPush = n;

for i = 1:SWIFrames
    Event(n).info = 'trigger out'; % Only needed for verifying push waveform with scope.
    Event(n).tx = 0;
    Event(n).rcv = 0;
    Event(n).recon = 0;
    Event(n).process = 0;
    Event(n).seqControl = 9;
    n = n+1;
    
    % Push transmit
    Event(n).info = 'Push transmit';
    Event(n).tx = 2;
    Event(n).rcv = 0;
    Event(n).recon = 0;
    Event(n).process = 0;
    Event(n).seqControl = [afterpush, TTNEB];
    n = n+1;
    
    for j = 1:na                      % Acquire frame
        Event(n).info = 'Acquire data';
        Event(n).tx = 1;
        Event(n).rcv = na*(i-1)+j+d;
        Event(n).recon = 0;      % no reconstruction.
        Event(n).process = 0;    % no processing
        Event(n).seqControl = PRF; %
        n = n+1;
    end
    
    Event(n-1).seqControl = 0; % do not want a TTNA here, since the next transmit is a EB
    
    Event(n).info = 'transfer data to Host';
    Event(n).tx = 0;         % no transmit
    Event(n).rcv = 0;        % no rcv
    Event(n).recon = 0;      % no reconstruction
    Event(n).process = 0;    % no process
    Event(n).seqControl = nsc;
    SeqControl(nsc).command = 'transferToHost'; % transfer frame to host buffer
    nsc = nsc+1;
    n = n+1;
    
    Event(n).info = 'recon and process for SWI';
    Event(n).tx = 0;         % no transmit
    Event(n).rcv = 0;        % no rcv
    Event(n).recon = [2,3];  % reconstruction
    Event(n).process = 1;    % process
    Event(n).seqControl = 0;
    n = n+1;
    
    Event(n).info = 'ext func to process IQ';
    Event(n).tx = 0;         % no transmit
    Event(n).rcv = 0;        % no rcv
    Event(n).recon = 0;      % reconstruction
    Event(n).process = 3;    % process
    Event(n).seqControl = 8;    
    n = n+1;    
    
end

Event(n).info = 'Jump back';
Event(n).tx = 0;        % no TX
Event(n).rcv = 0;       % no Rcv
Event(n).recon = 0;     % no Recon
Event(n).process = 0;
Event(n).seqControl = nsc;
SeqControl(nsc).command = 'jump';
SeqControl(nsc).argument = nStartAcqPush;


%% User specified UI Control Elements

% Define UIPos, which contains the default GUI positions - three columns of 10 controls. The x,y
%    locations increment up columns, with each column being a separate page. The origin
%    specified by UIPos is the lower left corner of a virtual box that encloses the control.
UIPos = zeros(10,2,3);
UIPos(:,1,1) = 0.0625;
UIPos(:,1,2) = 0.375;
UIPos(:,1,3) = 0.6875;
UIPos(:,2,1) = 0.0:0.1:0.9;
UIPos(:,2,2) = 0.0:0.1:0.9;
UIPos(:,2,3) = 0.0:0.1:0.9;

% Define slider group offsets and sizes. All units are normalized.
SG = struct('TO',[0.0,0.0975],...   % title offset
    'TS',[0.25,0.025],...   % title size
    'TF',0.8,...            % title font size
    'SO',[0.0,0.06],...     % slider offset
    'SS',[0.25,0.031],...   % slider size
    'EO',[0.075,0.031],...   % edit box offset
    'ES',[0.11,0.031]);     % edit box size

% - Sensitivity Cutoff
UI(1).Control =  {'UserB7','Style','VsSlider','Label','Sens. Cutoff',...
    'SliderMinMaxVal',[0,1.0,Recon(1).senscutoff],...
    'SliderStep',[0.025,0.1],'ValueFormat','%1.3f'};
UI(1).Callback = text2cell('%-UI#1Callback');

% - Range Change
UI(2).Control = {'UserA1','Style','VsSlider','Label','Range',...
    'SliderMinMaxVal',[64,320,P.endDepth],...
    'SliderStep',[0.1,0.2],'ValueFormat','%3.0f'};
UI(2).Callback = text2cell('%-UI#2Callback');

% - Focus Adjustment, off: move Focus = 1, on: move ROI = 2
% checkFocusAdj = 1;
UI(3).Control = {'UserB5','Style','VsButtonGroup','Title','move Focus / ROI',...
    'NumButtons',2,'Labels',{'move Focus','move ROI'}};
UI(3).Callback = text2cell('%-UI#3Callback');
% {'assignin(''base'',''checkFocusAdj'',UIState)'};

% - Push Elements Adjustment
TX(2).oldElements = TX(2).pushElements;
UI(4).Control = {'UserB4','Style','VsSlider','Label','Push Elements',...
    'SliderMinMaxVal',[20,100,TX(2).pushElements],...
    'SliderStep',[1/80,5/80],'ValueFormat','%3.0f'};
UI(4).Callback = text2cell('%-UI#4Callback');

% - IQ Caxis Adjustment
UI(5).Control = {'UserC3','Style','VsSlider','Label','IQ Caxis',...
    'SliderMinMaxVal',[100,600,powermax],...
    'SliderStep',[10/500,50/500],'ValueFormat','%3.0f'};
UI(5).Callback = {'assignin(''base'',''powermax'',UIValue)'};

% - IQ loop fps adjustment, only works at freeze and replay status
replay = 'off';
loopfps = 15;
UI(6).Control = {'UserC2','Style','VsSlider','Label','IQ loop fps',...
    'SliderMinMaxVal',[1,31,loopfps],...
    'SliderStep',[1/30,5/30],'ValueFormat','%3.0f'};
UI(6).Callback = text2cell('%-UI#6Callback');

% The follow UIs are not using User##
Pos = UIPos(2,:,3);

% text for IQ replay, no callback
UI(7).Control = {'Style','text',...
    'String','IQ replay',...
    'Units','normalized',...
    'Position',[Pos+SG.TO,SG.TS],...
    'FontUnits','normalized',...
    'FontSize',0.8,...
    'FontWeight','bold'};

% Replay button
UI(8).Control = {'Style','pushbutton',...
    'String','Replay',...
    'Units','normalized',...
    'Position',[Pos+[0 0.05],0.12,0.04],...
    'FontUnits','normalized',...
    'FontSize',0.5,...
    'Callback',{@replayIQ}};
UI(8).Callback = text2cell('%-UI#8Callback');

% Stop button, only visible after clicking "replay"
UI(9).Control = {'Style','pushbutton',...
    'String','Stop',...
    'Visible','off',...
    'Units','normalized',...
    'Position',[Pos+[0 0.05],0.12,0.04],...
    'FontUnits','normalized',...
    'FontSize',0.5,...
    'Callback','assignin(''base'',''replay'',''off'');'};

% Save shavewave imaging.avi with desired fps in the PC
UI(10).Control = {'Style','pushbutton',...
    'String','Save',...
    'Units','normalized',...
    'Position',[Pos+[0.13 0.05],0.12,0.04],...
    'FontUnits','normalized',...
    'FontSize',0.5,...
    'Callback',{@saveIQ}};
UI(10).Callback = text2cell('%-UI#10Callback');

% ROI adjustment
UI(11).Control = {'UserB2','Style','VsSlider','Label','ROI Width',...
    'SliderMinMaxVal',[20,100,SWIROI.width],...
    'SliderStep',[2/40,10/40],'ValueFormat','%3.0f'};
UI(11).Callback = text2cell('%-UI#11Callback');

UI(12).Control = {'UserB1','Style','VsSlider','Label','ROI Height',...
    'SliderMinMaxVal',[20,120,SWIROI.height],...
    'SliderStep',[1/100,10/100],'ValueFormat','%3.0f'};
UI(12).Callback = text2cell('%-UI#12Callback');

% SWI switch button
UI(13).Control =  {'UserB6','Style','VsPushButton','Label','SWI off'};

UI(14).Control =  {'UserB6','Style','VsPushButton','Label','SWI on'};

UI(15).Control =  {'UserB3','Style','VsSlider','Label','Push cycles',...
    'SliderMinMaxVal',[50,2000,pushCycle],...
    'SliderStep',[10/1500,50/1500],'ValueFormat','%4.0f'};
UI(15).Callback = text2cell('%-UI#15Callback');

%% How many External Functions? 
NumOfFunc = 9;
for No = 1:NumOfFunc
    EF(No).Function = text2cell(['%-EF#',num2str(No)]);
end

% ROI position
ROIpos = [TX(2).focusX-SWIROI.width/2,TX(2).focus-SWIROI.height/2,SWIROI.width,SWIROI.height];

% ElementLocation is used for focus correction
Location.Element = (0.5 + PData(1).Origin(1)):Trans.spacing/2:(PData(1).Origin(1)+DwWidth*Resource.DisplayWindow.pdelta - 0.5);
Location.PosForOddPush = Location.Element(1:2:end); % center of each element
Location.PosForEvenPush = Location.Element(2:2:end); % 127 spaces among 128 elements

% Specify factor for converting sequenceRate to frameRate.
frameRateFactor = 1;

% Save all the structures to a .mat file.
save(['MatFiles/',filename]);
VSX

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% converting the format to USTB 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
disp('Converting data format to USTB');

assert(sum(RcvData{2}(:))~=0,'The RcvData is empty, did you fire a push pulse?');

%% create USTB data class structure with Verasonics class
ver = verasonics();
% The Verasonics class needs these structs to create a USTB dataset
% NB! The Trans struct should be given first.
ver.Trans = Trans;
ver.RcvData = RcvData{2}; % We are just saving the "superframe"          
ver.Receive = Receive;
ver.Resource = Resource;
ver.TW = TW(1);
ver.TX = TX(1);
ver.angles = 0;%This should be the zero times the na defined in the beginning!!
ver.frames_in_superframe = na;
ver.number_of_superframes = Resource.RcvBuffer(2).numFrames;

% Create channel_data object
channel_data = ver.create_cpw_superframe_channeldata();

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

disp = postprocess.autocorrelation_displacement_estimation();
disp.channel_data = channel_data;

% Start the processing pipeline
b_data=pipe.go({midprocess.das postprocess.coherent_compounding disp});

%% show
f100 = figure(100);
b_data.plot(f100,'Displacement',[],'none');
caxis([-0.1*10^-6 0.3*10^-6]); % Updating the colorbar
colormap(gca(f100),'hot');       % Changing the colormap

%%
answer = questdlg('Do you want to save this dataset?');
if strcmp(answer,'Yes')
    %% write channel_data to file the filname that was created in the beginning of this script
    channel_data.write(uff_filename,'channel_data');
end
return

%% **** Callback routines to be converted by text2cell function. ****
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
    set(hObject,'Value',evalin('base','P.endDepth'));
    return
end
P = evalin('base','P');
P.endDepth = UIValue;
assignin('base','P',P);
evalin('base','PData(1).Size(1) = ceil((P.endDepth-P.startDepth)/PData(1).PDelta(3));');
evalin('base','PData(1).Region = computeRegions(PData(1));');
evalin('base','Resource.DisplayWindow(1).Position(4) = ceil(PData(1).Size(1)*PData(1).PDelta(3)/Resource.DisplayWindow(1).pdelta);');
Receive = evalin('base', 'Receive');
Trans = evalin('base', 'Trans');
maxAcqLength = ceil(sqrt(P.endDepth^2 + ((Trans.numelements-1)*Trans.spacing)^2));
for i = 1:size(Receive,2)
    Receive(i).P.endDepth = maxAcqLength;
end
assignin('base','Receive',Receive);
evalin('base','TGC.rangeMax = P.endDepth;');
evalin('base','TGC.Waveform = computeTGCWaveform(TGC);');
evalin('base','if VDAS==1, Result = loadTgcWaveform(1); end');
Control = evalin('base','Control');
Control.Command = 'update&Run';
Control.Parameters = {'PData','InterBuffer','ImageBuffer','DisplayWindow','Receive','Recon'};
assignin('base','Control', Control);
assignin('base', 'action', 'displayChange');
return
%-UI#2Callback

%-UI#3Callback - move Focus or move ROI
Resource = evalin('base','Resource');
ROIHandle = evalin('base','ROIHandle');

if UIState == 1
    assignin('base','moveTarget','Focus');
    set(ROIHandle,'ButtonDownFcn',[]);
    set(Resource.DisplayWindow(1).figureHandle,'WindowButtonDownFcn','moveFocus');
else
    assignin('base','moveTarget','SWIROI');
    set(Resource.DisplayWindow(1).figureHandle,'WindowButtonDownFcn',[]);
    set(ROIHandle,'ButtonDownFcn','moveROI');
end
return
%-UI#3Callback

%-UI#4Callback - PushElements adjustment
% checkFocusAdj = evalin('base','checkFocusAdj');
TX = evalin('base','TX');
UI = evalin('base','UI');
freeze = evalin('base','freeze');

assignin('base','moveTarget','Focus');
pushElements = round(get(UI(4).handle(2),'Value'));

% If focusAdj is off, or at freeze, or Shearwave fig is closed, change value back to the old one
if freeze == 1
    set(UI(4).handle(2),'Value',TX(2).pushElements);
    set(UI(4).handle(3),'String',TX(2).pushElements);
else% on, focussCorrection and TXLimitCheck
    TX(2).oldElements = TX(2).pushElements;
    TX(2).pushElements = pushElements;
    assignin('base','TX',TX);
    
    SS.check = ['Changing push elements to ',num2str(pushElements),' elements...'];
    SS.error = ['Back to previous push Elements, ',num2str(TX(2).oldElements),' elements'];
    SS.final = ['Push elements have been changed to ',num2str(pushElements),' elements.'];
    
    focusCorrection;
    TXLimitCheck(SS,'TX');
end
return
%-UI#4Callback

%-UI#6Callback - fps adjustment for replay shearwave imaging
UI = evalin('base','UI');
loopfps = evalin('base','loopfps');
freeze = evalin('base','freeze');

if freeze == 1
    assignin('base','loopfps', UIValue);
else
    set(UI(6).handle(2),'Value',loopfps);
    set(UI(6).handle(3),'String',loopfps);
end
return
%-UI#6Callback

%-UI#8Callback
replayIQ(varargin)

freeze = evalin('base','freeze');
% figClose = evalin('base','figClose');

if freeze == 1
    replay = 'on';
    assignin('base','replay','on');
    
    UI = evalin('base','UI');
    TX = evalin('base','TX');
    ROIpos = evalin('base','ROIpos');
    MovieData = evalin('base','MovieData');    
    SWIfigHandle = evalin('base','SWIfigHandle');
    
    set(UI(8).handle,'Visible','off');
    set(UI(9).handle,'Visible','on');
    
    disp('replay shearwave imaging....');
    
    x = round(TX(2).focusX);
    z = TX(2).focus;
    
    IQData = evalin('base','IQData');
    IQBuffer = IQData{1};
    
    Depth = size(IQBuffer,1);
    Width = size(IQBuffer,2);

    na = evalin('base','na');
    
    IQMovie(na-1) = struct('cdata',[],'colormap',[]);
    SWIimageHandle = evalin('base','SWIimageHandle');   
    
    while strcmp(replay,'on')
        
        for i = 1:na-1
            
            tic
            replay = evalin('base','replay');
            freeze = evalin('base','freeze');
            loopfps = evalin('base','loopfps');
            powermax = evalin('base', 'powermax');
            
            % if GUI is closed, return
            if evalin('base','exit == 1')
                return
            end
            
            % unfreeze will stop replay
            if freeze == 0 || strcmp(replay,'off') == 1
                set(UI(8).handle,'Visible','on');
                set(UI(9).handle,'Visible','off');
                assignin('base','replay','off');
                assignin('base','IQMovie',IQMovie);
                return
            end
            
            set(SWIimageHandle,'CData',squeeze(MovieData(:,:,i)));
            drawnow
            caxis(get(SWIfigHandle,'currentAxes'),[50,powermax]);
            
            IQMovie(i)=getframe(SWIfigHandle);
            pause(1/loopfps-toc);
            
        end
        
    end
    
end

return
%-UI#8Callback

%-UI#10Callback
saveIQ(varargin)
UI = evalin('base','UI');
freeze = evalin('base','freeze');

if evalin('base','exist(''IQMovie'',''var'')')
    if freeze == 1
        assignin('base','replay','off');
        set(UI(8).handle,'Visible','on');
        set(UI(9).handle,'Visible','off');
        
        IQMovie = evalin('base','IQMovie');
        loopfps = evalin('base','loopfps');
        [fn,pn,filterindex] = uiputfile('*.avi','Save Shearwave movie as');
        if ~isequal(fn,0) % fn will be zero if user hits cancel
            fn = strrep(fullfile(pn,fn), '''', '''''');
            movie2avi(IQMovie,fn,'fps',loopfps,'compression', 'None');
            fprintf('The shearwave movie has been saved at %s \n',fn);
        else
            disp('The shearwave movie is not saved.');
        end
    end
else
    msgbox('replay is not finished!');
end
return
%-UI#10Callback

%-UI#11Callback - ROI Width change
PData = evalin('base','PData');
SWIROI = evalin('base','SWIROI');
Location = evalin('base','Location');
ROIHandle = evalin('base','ROIHandle');
SWIfigHandle = evalin('base','SWIfigHandle');

ROIpos = get(ROIHandle,'Position');

newX = ROIpos(1) - (UIValue-ROIpos(3))/2;
if newX < Location.Element(1)-0.5, newX = Location.Element(1)-0.5;
elseif newX > Location.Element(end)+0.5-UIValue, newX = Location.Element(end)+0.5-UIValue; end

ROIpos(1) = newX;
ROIpos(3) = UIValue;
SWIROI.width = UIValue;
assignin('base','ROIpos',ROIpos);
assignin('base','SWIROI',SWIROI);

PData(2).Region(1).Shape.width = SWIROI.width;
PData(2).Region(1) = computeRegions(PData(2));
  
assignin('base','PData',PData);

Control = evalin('base','Control');
Control.Command = 'update&Run';
Control.Parameters = {'PData','Recon'};
assignin('base','Control', Control);
assignin('base','newIQ',1);
assignin('base','moveTarget','SWIROI');

pos = get(SWIfigHandle,'Position');
set(SWIfigHandle,'Position',[pos(1:2),[SWIROI.width+3,SWIROI.height]*7]);

return
%-UI#11Callback

%-UI#12Callback - ROI Height change
P = evalin('base','P');
PData = evalin('base','PData');
SWIROI = evalin('base','SWIROI');
ROIHandle = evalin('base','ROIHandle');
SWIfigHandle = evalin('base','SWIfigHandle');

ROIpos = get(ROIHandle,'Position');

newY = ROIpos(2) - (UIValue-ROIpos(4))/2;
if newY < P.startDepth, newY = P.startDepth;
elseif newY > P.endDepth - UIValue, newY = P.endDepth - UIValue; end

ROIpos(2) = newY;
ROIpos(4) = UIValue;
SWIROI.height = UIValue;
assignin('base','ROIpos',ROIpos);
assignin('base','SWIROI',SWIROI);

PData(2).Region(1).Shape.Position(3) = newY;
PData(2).Region(1).Shape.height = SWIROI.height;
PData(2).Region(1) = computeRegions(PData(2));

assignin('base','PData',PData);

Control = evalin('base','Control');
Control.Command = 'update&Run';
Control.Parameters = {'PData','Recon'};
assignin('base','Control', Control);
assignin('base','newIQ',1);
assignin('base','moveTarget','SWIROI');

pos = get(SWIfigHandle,'Position');
set(SWIfigHandle,'Position',[pos(1:2),[SWIROI.width+3,SWIROI.height]*7]);
return
%-UI#12Callback

%-UI#15Callback - pushCycle change
TW = evalin('base', 'TW');
TX = evalin('base', 'TX');
TW(2).oldCycles = evalin('base','pushCycle');

pushCycle = round(UIValue);

% TW(2) is used for push
if strcmp(TW(2).type,'parametric') || strcmp(TW(2).type,'envelop')
    TW(2).Parameters(3) = pushCycle*2;
    evalin('base',['pushCycle = ',num2str(pushCycle),';']);
else
    set(UI(15).handle(2),'Value',TW.oldCycles);
    set(UI(15).handle(3),'String',num2str(TW.oldCycles));
end

[~,~,~,~,TW(2)] = computeTWWaveform(TW(2));
TX(2).Bdur = TW(2).Bdur;

SS.check = ['Changing push cycles to ',num2str(pushCycle,'%4.0f'),' cycles...'];
SS.error = ['Back to previous push cycles, ',num2str(TW(2).oldCycles,'%4.0f'),' cycles.'];
SS.final = ['Push cycles have been changed to ',num2str(pushCycle,'%4.0f'),' cycles.'];

assignin('base','TW',TW);
assignin('base','TX',TX);

TXLimitCheck(SS,'TW');

return
%-UI#15Callback


%% External functions with process object

%-EF#1
UIControl(varargin)

UI = evalin('base','UI');
f = evalin('base','f');

for i = 3:15
    set(UI(i).handle,'Visible','off');
end

hv2Handle(1) = findobj('String','High Voltage P5');
hv2Handle(2) = findobj('tag','hv2Sldr');
hv2Handle(3) = findobj('tag','hv2Value');
hv2Handle(4) = findobj('tag','hv2Actual');
set(hv2Handle,'Visible','off');

% modify font of buttongroup
% f = findobj('tag','UI');
bkgrnd = get(f,'Color');
set(UI(3).handle(1),'FontSize',0.2,'BackgroundColor',bkgrnd);
if ispc
    pos = [0.58 0.08]; % for Windows
else
    pos = [0.52 0.05]; % for Mac
end

set(UI(3).handle(2),'FontSize',0.9,'Position',[0.05,pos(1),0.9,0.34]);
set(UI(3).handle(3),'FontSize',0.9,'Position',[0.05,pos(2),0.9,0.34]);

set(UI(13).handle,'Callback',@SWIoff);
set(UI(14).handle,'Callback',@SWIon);
set(UI(14).handle,'Visible','on');

return
%-EF#1

%-EF#2
processIQ(IQBuffer)
%processIQFunction: Computes power estimates from IQData
%		Im = I(k) * Q(k+1) - I(k+1) * Q(k)
%		Re = I(k) * I(k+1) + Q(k) * Q(k+1)
%		Power = sqrt(Im*Im + Re*Re);

persistent recHandle markHandle myHandle recTrans

SWIROI = evalin('base','SWIROI');
ROIpos = evalin('base','ROIpos');
SWIfigHandle = evalin('base','SWIfigHandle');
bmodeFigHandle = evalin('base','Resource.DisplayWindow(1).figureHandle');

na = evalin('base','na');
TX = evalin('base','TX');
PData = evalin('base','PData');
newIQ = evalin('base','newIQ');
Trans = evalin('base','Trans');
powermax = evalin('base', 'powermax');
moveTarget = evalin('base','moveTarget');

ROILA = (PData(2).Region.PixelsLA+1);

Depth = floor(SWIROI.height/PData(2).PDelta(3));%size(IQBuffer,1);%PData(2).Size(1);
Width = length(ROILA)/Depth;

if ~isequal(mod(Width,1),0)    
    Width = floor(SWIROI.width/PData(2).PDelta(1));%size(IQBuffer,2);%PData(2).Size(2);
    Depth = length(ROILA)/Width;
end

MovieData = zeros(Depth,Width,na-1);

x = TX(2).focusX;
z = TX(2).focus;

% Focus mark, SWIROI,  and Transducer rect on bmode figure
if ishandle(bmodeFigHandle)
    if  isempty(recHandle) || ~ishandle(recHandle)
        figure(bmodeFigHandle), hold on,
        recHandle = rectangle('Position',[x-SWIROI.width/2,z-SWIROI.height/2,SWIROI.width,SWIROI.height],'EdgeColor','w','LineWidth',2);
        recTrans  = rectangle('Position',[x-TX(2).pushElements*Trans.spacing/2,4,TX(2).pushElements*Trans.spacing,4],'EdgeColor','r','FaceColor','r');
        markHandle = plot(x,z,'xr','MarkerFaceColor','r','MarkerSize',8,'Linewidth',2);hold off;
        assignin('base','TransHandle',recTrans);
        assignin('base','ROIHandle',recHandle);
        assignin('base','markHandle',markHandle);
    else
        switch moveTarget
            case 'Focus'
                set(markHandle,'XData',x);
                set(markHandle,'YData',z);
                set(recTrans,'Position',[x-TX(2).pushElements*Trans.spacing/2,4,TX(2).pushElements*Trans.spacing,4]);
                assignin('base','moveTarget','jump');
            case 'SWIROI'
                set(recHandle,'Position',ROIpos);
                assignin('base','moveTarget','jump');
            case 'jump'
        end
    end
end

% kernel2D is used for 2D filter to smooth SWI 
kernel2D = ...
[   0.0073    0.0208    0.0294    0.0208    0.0073;
    0.0208    0.0589    0.0833    0.0589    0.0208;
    0.0294    0.0833    0.1179    0.0833    0.0294;
    0.0208    0.0589    0.0833    0.0589    0.0208;
    0.0073    0.0208    0.0294    0.0208    0.0073;];

if newIQ == 1  % Need to replot focus IQ data after changing ROI
    assignin('base','newIQ',0);
    
    axisChannel = linspace(ROIpos(1),ROIpos(1)+ROIpos(3),Width);
    axisDepth   = linspace(ROIpos(2),ROIpos(2)+ROIpos(4),Depth);   
    
    IQ3 = IQBuffer(:,:,1,3); IQ4 = IQBuffer(:,:,1,4);
   
    ImMean = (imag(IQ3(ROILA)) + imag(IQ4(ROILA)))/2;
    ReMean = (real(IQ3(ROILA)) + real(IQ4(ROILA)))/2;
    Im = (imag(IQ3(ROILA))-ImMean) .* (real(IQ4(ROILA))-ReMean) - ...
        (imag(IQ4(ROILA))-ImMean) .* (real(IQ3(ROILA))-ReMean);
    Re = (imag(IQ3(ROILA))-ImMean) .* (imag(IQ4(ROILA))-ImMean) + ...
        (real(IQ3(ROILA))-ReMean) .* (real(IQ4(ROILA))-ReMean);
    Power = reshape((Im .* Im + Re .* Re).^0.125,Depth,Width);           
    buffer = filter2(Power,kernel2D,'full');
    bufferS = size(buffer);
    ind1 = (bufferS(1)-Depth)/2;
    ind2 = (bufferS(2)-Width)/2;
    Power = rot90(buffer(ind1+1:end-ind1,ind2+1:end-ind2),2);
    figure(SWIfigHandle), if ishandle(myHandle), delete(myHandle); end
    myHandle = imagesc(axisChannel,axisDepth,Power);
    title('Shear Wave Visualization with L7-4','FontSize',14,'Fontweight','bold');
    xlabel('Wavelength','FontSize',12,'Fontweight','bold');
    ylabel('Wavelength','FontSize',12,'Fontweight','bold');
    set(gca,'FontSize',12,'Fontweight','bold');
    axis tight equal, colormap('gray')
    MovieData(:,:,1) = Power;
    assignin('base','SWIimageHandle',myHandle);
end

caxis(get(SWIfigHandle,'currentAxes'),[50,powermax]);
% The size of IQData here is [nRows, nCols, nFrames, nPages]
for i = 2:na-1 % for all combinations of 2 pages
    IQ1 = IQBuffer(:,:,1,i); IQ2 = IQBuffer(:,:,1,i+1);
    ImMean = (imag(IQ1(ROILA)) + imag(IQ2(ROILA)))/2;
    ReMean = (real(IQ1(ROILA)) + real(IQ2(ROILA)))/2;
    Im = (imag(IQ1(ROILA))-ImMean) .* (real(IQ2(ROILA))-ReMean) - ...
        (imag(IQ2(ROILA))-ImMean) .* (real(IQ1(ROILA))-ReMean);
    Re = (imag(IQ1(ROILA))-ImMean) .* (imag(IQ2(ROILA))-ImMean) + ...
        (real(IQ1(ROILA))-ReMean) .* (real(IQ2(ROILA))-ReMean);
    Power = reshape((Im .* Im + Re .* Re).^0.125,Depth,Width);           
    buffer = filter2(Power,kernel2D,'full');
    bufferS = size(buffer);
    ind1 = (bufferS(1)-Depth)/2;
    ind2 = (bufferS(2)-Width)/2;
    Power = rot90(buffer(ind1+1:end-ind1,ind2+1:end-ind2),2);
    set(myHandle,'CData',Power);
    MovieData(:,:,i) = Power;   
    drawnow
end

assignin('base','MovieData',MovieData);


return

%-EF#2

%% Other external functions used in callback functions

%-EF#3
moveFocus(varargin)

freeze = evalin('base','freeze');
exit = evalin('base','exit');

if freeze == 0 && exit == 0  % no response if freeze or exit
    
    UI = evalin('base','UI');
    TX = evalin('base','TX');
    Trans = evalin('base','Trans');
    SWIROI = evalin('base','SWIROI');
    Location = evalin('base','Location');
    
    Location.oldX = TX(2).focusX;
    Location.oldZ = TX(2).focus;
    
    bmodeFigHandle = evalin('base','Resource.DisplayWindow(1).figureHandle');
    bmodeAxes = get(bmodeFigHandle,'currentAxes');
    currentPos = get(bmodeAxes,'CurrentPoint');
    YLim = get(bmodeAxes,'YLim');
    
    Location.newX = currentPos(1);
    Location.newZ = currentPos(3);
       
    if Location.newZ > YLim(2)-5, Location.newZ = YLim(2)-5;
    elseif Location.newZ < 10, Location.newZ = 10;
    end
    
    assignin('base','Location',Location);
    assignin('base','moveTarget','Focus');
    focusCorrection;
    
    Location = evalin('base','Location');
    
    SS.check = ['Moving focus to (',num2str(Location.newX,'%3.2f'),',',num2str(Location.newZ,'%3.2f'),')....'];
    SS.error = ['Back to previous focus (',num2str(Location.oldX,'%3.2f'),',',num2str(Location.oldZ,'%3.2f'),').'];
    SS.final = ['Push focus has been moved to (',num2str(Location.newX,'%3.2f'),',',num2str(Location.newZ,'%3.2f'),').'];
    
    TXLimitCheck(SS,'TX');
    
end
%-EF#3

%-EF#4
moveROI(varargin)

freeze = evalin('base','freeze');
exit = evalin('base','exit');

if freeze == 0 && exit == 0  % no response if freeze or exit
    
    ax = axis;
    xrange = ax(2)-ax(1); % range of x-axis
    yrange = ax(4)-ax(3); % range of y-axis
    
    gcfUnits = get(gcf,'Units');
    pltUnits = get(gca,'Units');
    set(gcf,'Units','pixels')
    set(gca,'Units','normalized');
    
    theRect = get(gcbo,'Position'); % position of clicked rectangle (figure units)
    theFig = get(gcf,'Position'); % position of figure on desktop (pixel units)
    thePlot = get(gca,'Position'); % position of plot within figure (percentages)
    
    pt1 = get(gcf,'CurrentPoint'); % button down detected (pixel units)
    pt2 = get(gca,'CurrentPoint'); % button down detected (figure units)
    
    set(gcf,'Units',gcfUnits);
    set(gca,'Units',pltUnits);
    
    xoffset = pt2(1,1)-theRect(1);
    if isequal( get(gca,'Ydir'), 'reverse' )
        yoffset = theRect(2)-pt2(1,2)+theRect(4);
    else
        yoffset = pt2(1,2)-theRect(2);
    end
    
    x = pt1(1) - xoffset/xrange * theFig(3)*thePlot(3); % calc. x location in pixels
    y = pt1(2) - yoffset/yrange * theFig(4)*thePlot(4); % calc. y location in pixels
    wt = theRect(3)/xrange * theFig(3) * thePlot(3); % calc. width in pixels
    ht = theRect(4)/yrange * theFig(4) * thePlot(4); % calc. height in pixels
    
    beforeRect = [x y wt ht]; % starting rectange (pixels)
    afterRect = dragrect(beforeRect); % move around
    pixDiff = afterRect(1:2)-beforeRect(1:2); % find the change in x/y pixel units
    figDiff = pixDiff .* ... % convert change to figure units
        [xrange/(theFig(3)*thePlot(3)) yrange/(theFig(4)*thePlot(4))];
    
    if isequal( get(gca,'Ydir'), 'reverse' )
        newY = pt2(1,2) - (figDiff(2)-yoffset)-theRect(4);
    else
        newY = pt2(1,2) + figDiff(2) - yoffset;
    end
    
    newX = pt2(1,1) + figDiff(1) - xoffset;
    
    P = evalin('base','P');
    Location = evalin('base','Location');
    
    if newX < Location.Element(1)-0.5, newX = Location.Element(1)-0.5;
    elseif newX > Location.Element(end)+0.5-theRect(3), newX = Location.Element(end)+0.5-theRect(3); end
    
    if newY < P.startDepth, newY = P.startDepth;
    elseif newY > P.endDepth - theRect(4), newY = P.endDepth - theRect(4); end
    
    set(gcbo,'Position',[newX newY theRect(3) theRect(4)]) % move rectangle to the new location
    assignin('base','ROIpos',[newX newY theRect(3) theRect(4)]);
    
    % Trans and PData are required for computeRegions
    PData = evalin('base','PData');
    SWIROI = evalin('base','SWIROI');
    
    PData(2).Region.Shape.Position = [newX+SWIROI.width/2,0,newY];
    PData(2).Region = computeRegions(PData(2));   
    
    assignin('base','PData',PData);
    assignin('base','newIQ',1);
    
    Control = evalin('base','Control');
    Control.Command = 'update&Run';
    Control.Parameters = {'PData','Recon'};
    assignin('base','Control', Control);
    
end

%-EF#4

%-EF#5
TXLimitCheck(SS,adjustCase)

TXEventCheck;
TX = evalin('base','TX');
Trans = evalin('base','Trans');
Location = evalin('base','Location');

% Location.newX won't be assigned if new focus is not determined
if ~isfield(Location,'pushStartEle')
    Ind = find(TX(2).Apod == 1);
    Location.pushStartEle = Ind(1);
end

oldApod = TX(2).Apod;
TX(2).Apod = zeros(1,Trans.numelements);
TX(2).Apod(Location.pushStartEle:Location.pushStartEle+TX(2).pushElements-1) = 1;
fprintf([SS.check, '\n']);

% Check Gate Driver Limit
TW = evalin('base','TW');
UI = evalin('base','UI');
TXEvent = evalin('base','TXEvent');
numBoards = evalin('base', 'numBoards');
numTXEvents = length(TXEvent); % due to one push event per frame

gdPsImax = 4;
Cgdps = 1100; % power supply storage capacitor in uF
maxVdroopLimit = 1.5; % maximum allowed droop in volts at power supply storage capacitor

gdIperCHF = 1/64; % supply current in Amps, per channel at 1 MHz

totalPRI = 0;
idleT = zeros(1, size(TXEvent, 2)); % idle time per event (cumPRI - Bdur)
Bdur(1:numTXEvents) = TW(2).Bdur;
Numpulses = TX(2).Numpulses;
% create array indices for summing pairs of channels sharing a gate driver;
% within each AFE group of 8 channels, channels N and N+4 are using the
% same gate driver package.
incr4 = [1, 2, 3, 4];
GDindxA = incr4;
for i = 1:(numBoards*8 - 1)
    GDindxA = [GDindxA, (incr4+8*i)];
end
GDindxB = GDindxA + 4;

bdCumGdPsLd = 0;
for TEnum = 1:numTXEvents
    
    totalPRI = totalPRI + TXEvent(TEnum).cumPRI; % accumulate PRI over all TXEvents
    idleT(TEnum) = TXEvent(TEnum).cumPRI - Bdur(TEnum);
    
    % find per-channel gate driver supply current based on average
    % cycle rate over the burst interval, and also the total gate driver
    % supply current per board by summing over all channels on each board
    TXthermal(TEnum).ChGdIperCh = gdIperCHF * Numpulses/(2*Bdur(TEnum));
    ChPrGdI = TXthermal(TEnum).ChGdIperCh(GDindxA) + TXthermal(TEnum).ChGdIperCh(GDindxB);
    for bdnum = 1:numBoards
        chindex = (32*(bdnum-1) + (1:32));
        BdGdI(bdnum) = sum(ChPrGdI(chindex));
    end
    bdCumGdPsLd = bdCumGdPsLd + Bdur(TEnum)*BdGdI; % total gate driver supply load in Amp-usec
end

if max(bdCumGdPsLd)>gdPsImax*totalPRI
    switch adjustCase
        case 'TX'
            TX(2).focusX = Location.oldX;
            TX(2).Origin = Location.oldX;
            TX(2).focus  = Location.oldZ;
            TX(2).Apod = oldApod;
            TX(2).pushElements = TX(2).oldElements;
            set(UI(4).handle(2),'Value',TX(2).oldElements);
            set(UI(4).handle(3),'String',TX(2).oldElements);
        case 'TW'
            evalin('base','pushCycle = TW(2).oldCycles;');
    end
    fprintf(['Maximum per-board total Gate driver supply load of ',num2str(max(bdCumGdPsLd),'%.1f'),...
        ' Amp-usec exceeds power supply capacity of ', num2str(gdPsImax*totalPRI,'%.1f'), ' Amp-usec.\n\n',...
        ' in Event ', num2str(TXEvent(1).Event), ', board number(', num2str(bdnum),'). \n']);
    fprintf([SS.error, '\n']);
    assignin('base','TX', TX);
    
    return
end

% Pass the limit, writing new TX and PData to workspace
fprintf([SS.final, '\n']);

switch adjustCase
    case 'TX'
        TX(2).focusX = Location.newX;
        TX(2).Origin = Location.newX;
        TX(2).focus = Location.newZ;
        TX(2).oldElements = TX(2).pushElements;
    case 'TW'
        evalin('base','TW(2).oldCycles = pushCycle;');
end

TX(2).Delay = computeTXDelays(TX(2));
assignin('base','TX', TX);

Control.Command = 'update&Run';
Control.Parameters = {'TW','TX','Recon'};
assignin('base','Control', Control);
%-EF#5

%-EF#6
closeIQfig(varargin)

if evalin('base','exit')
    delete(gcf)
else
    SWIoff;
end

return
%-EF#6

%-EF#7
SWIoff(varargin)

% if the movie is replay, no response
replay = evalin('base','replay');

if strcmp(replay,'on')
    msgbox('please stop reply first');
    
elseif strcmp(replay,'off')
    
    % make related UI controls unvisible
    UI = evalin('base','UI');
    for i = 3:15
        set(UI(i).handle,'Visible','off');
    end
    set(UI(2).handle,'Visible','on');
    set(UI(14).handle,'Visible','on');

    % Set Focus Adjustment back to off
    set(UI(3).handle(2),'Value',1);
    set(UI(3).handle(3),'Value',0);
    
    % make SWI figure, blue region, and red mark unvisible
    set(evalin('base','SWIfigHandle'),'Visible','off');
    
    if evalin('base','exist(''ROIHandle'',''var'')')
        if evalin('base','ishandle(ROIHandle)')
            set(evalin('base','ROIHandle'),'Visible','off');
            set(evalin('base','markHandle'),'Visible','off');
            set(evalin('base','TransHandle'),'Visible','off');
        else
            evalin('base','clear ROIHandle markHandle TransHandle');
        end
    end
    
    % make P1 slider visible and P5 slider unvisible
    hv1Handle(1) = findobj('String','High Voltage P1');
    hv1Handle(2) = findobj('tag','hv1Sldr');
    hv1Handle(3) = findobj('tag','hv1Value');
    set(hv1Handle,'Visible','on');
    
    hv2Handle(1) = findobj('String','High Voltage P5');
    hv2Handle(2) = findobj('tag','hv2Sldr');
    hv2Handle(3) = findobj('tag','hv2Value');
    hv2Handle(4) = findobj('tag','hv2Actual');
    set(hv2Handle,'Visible','off');
    
    % set hv2 back to 1.6v
    hv2 = 1.6;
    TPC = evalin('base','TPC');
    [~,hvset] = setTpcProfileHighVoltage(hv2,length(TPC));
    TPC(length(TPC)).hv = hvset;
    assignin('base','TPC',TPC);
    set(hv2Handle(3),'String',num2str(hvset,'%.1f'));
    set(hv2Handle(2),'Value',hv2); 
    display('Wait 5 seconds for voltage decrease');
    pause(5);
    
    % change the start event
    nStart = evalin('base','nStartFlash');
    Control = evalin('base','Control');
    Control.Command = 'set&Run';
    Control.Parameters = {'Parameters',1,'startEvent',nStart};
    evalin('base',['Resource.Parameters.startEvent =',num2str(nStart),';']);
    assignin('base','Control',Control);
    
    % no WindowButtonDownFcn
    Resource = evalin('base','Resource');
    set(Resource.DisplayWindow(1).figureHandle,'WindowButtonDownFcn',[]);
    
end

return
%-EF#7

%-EF#8
SWIon(varargin)

Resource = evalin('base','Resource');

% Handle for Shearwave figure
if ~evalin('base','exist(''SWIfigHandle'',''var'')')
    
    SWIROI = evalin('base','SWIROI');
    
    SWIfigHandle = figure('Name','ShearWaveVisulization',...
        'NumberTitle','off','Visible','on',...
        'Position',[Resource.DisplayWindow(1).Position(1)+Resource.DisplayWindow(1).Position(3), ... % left edge
        Resource.DisplayWindow(1).Position(2), ... % bottom
        [SWIROI.width+3,SWIROI.height]*7], ...            % width, height
        'CloseRequestFcn',{@closeIQfig});
    assignin('base','SWIfigHandle',SWIfigHandle);
else
    set(evalin('base','SWIfigHandle'),'Visible','on');
end

if evalin('base','exist(''ROIHandle'',''var'')')
    if evalin('base','ishandle(ROIHandle)')
        % make ROI, recTrans and mark visible
        set(evalin('base','ROIHandle'),'Visible','on');
        set(evalin('base','markHandle'),'Visible','on');
        set(evalin('base','TransHandle'),'Visible','on');
    end
end

% newIQ is used for check whether new SWI axes is required
evalin('base','newIQ = 1;');

% make related UI controls visible
UI = evalin('base','UI');
for i = 3:15
    set(UI(i).handle,'Visible','on','Interruptible','off');
end
set(UI(2).handle,'Visible','off');
set(UI(9).handle,'Visible','off');
set(UI(14).handle,'Visible','off');
set(UI(8).handle,'Interruptible','on');

% set moveTarget and WindowButtonDownFcn
assignin('base','moveTarget','Focus');
set(Resource.DisplayWindow(1).figureHandle,'WindowButtonDownFcn','moveFocus');

% make P1 slider unvisible and P5 slider visible
hv1Handle(1) = findobj('String','High Voltage P1');
hv1Handle(2) = findobj('tag','hv1Sldr');
hv1Handle(3) = findobj('tag','hv1Value');
set(hv1Handle,'Visible','off');

hv2Handle(1) = findobj('String','High Voltage P5');
hv2Handle(2) = findobj('tag','hv2Sldr');
hv2Handle(3) = findobj('tag','hv2Value');
hv2Handle(4) = findobj('tag','hv2Actual');
set(hv2Handle,'Visible','on');

focusCorrection;

% change the start event
nStart = evalin('base','nStartPush');
Control = evalin('base','Control');
Control.Command = 'set&Run';
Control.Parameters = {'Parameters',1,'startEvent',nStart};
evalin('base',['Resource.Parameters.startEvent =',num2str(nStart),';']);
assignin('base','Control',Control);

return
%-EF#8

%-EF#9
focusCorrection(varargin)

TX = evalin('base','TX');
Trans = evalin('base','Trans');
Location = evalin('base','Location');

pushElements = TX(2).pushElements;

if ~isfield(Location,'newX')
    Location.oldX = TX(2).focusX;
    Location.oldZ = TX(2).focus;
    Location.newX = TX(2).focusX;
    Location.newZ = TX(2).focus;
    Ind = find(TX(2).Apod == 1);
    Location.pushStartEle = Ind(1);
end

x = Location.newX;
z = Location.newZ;

% Location.PosForEvenPush indicates the x-coor of the right edge of each element
% LOcation.PosForOddPush indicates the x-coor of the center of each element
if mod(pushElements,2) == 0
    focusLimit = [Location.PosForEvenPush(pushElements/2),Location.PosForEvenPush(Trans.numelements-pushElements/2)];
    if x < focusLimit(1), x = focusLimit(1); elseif x > focusLimit(2), x = focusLimit(2); end
    [value,eleInd] = min(abs(x - Location.PosForEvenPush));
    Location.newX = Location.PosForEvenPush(eleInd);
    Location.pushStartEle = eleInd - pushElements/2 + 1;
else
    focusLimit = [Location.PosForOddPush((pushElements+1)/2),Location.PosForOddPush(Trans.numelements-(pushElements-1)/2)];
    if x < focusLimit(1), x = focusLimit(1);
    elseif x > focusLimit(2), x = focusLimit(2); end
    [value,eleInd] = min(abs(x - Location.PosForOddPush));
    Location.newX = Location.PosForOddPush(eleInd);
    Location.pushStartEle = eleInd - (pushElements-1)/2;
end

Location.pushStartCoor = Location.PosForEvenPush(Location.pushStartEle);
assignin('base','Location',Location);

%-EF#9



