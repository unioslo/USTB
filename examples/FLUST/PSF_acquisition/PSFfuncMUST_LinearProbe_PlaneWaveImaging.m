function [PSFs,p] = PSFfuncMUST_LinearProbe_PlaneWaveImaging(flowLine, setup) % parameter structure not used in this example

%% Computation of a CPWI dataset with MUST 
%
% Creates a simulation of Na plane waves using MUST, requires access to the
% SIMUS simulator, which is included in the MUST library.
%
% date:               25.05.2022
% modified by      :  Joergen Avdal <jorgen.avdal@ntnu.no>
%                     Ingvild Kinn Ekroll <ingvild.k.ekroll@ntnu.no>

%% Set default setup parameters

p.trans.f0                = 5.1333e+06;      % Transducer center frequency [Hz]
p.trans.element_height    = 5e-3;            % Height of element [m]
p.trans.pitch             = 0.300e-3;        % probe.pitch [m]
p.trans.kerf              = 0.03e-03;        % gap between elements [m]
p.trans.lens_el           = 20e-3;           % position of the elevation focus
p.trans.N                 = 128;             % Number of elements
p.trans.pulse_duration    = 4.5;             % pulse duration [cycles]
p.trans.c0                = 1540;            % speed of sound [m/s]

p.acq.F_number = 1;
p.acq.alphaTx = 0; %atan(1/2/p.acq.F_number);
p.acq.alphaRx = 0;

p.scan.xStart = -10e-3;
p.scan.xEnd = 10e-3;
p.scan.Nx = 256;
p.scan.zStart = 10e-3;
p.scan.zEnd = 30e-3;
p.scan.Nz = 256;


%% Read setup parameters
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

%% Dependent Parameters

p.trans.lambda            = p.trans.c0/p.trans.f0;   % Wavelength [m]
p.trans.element_width     = p.trans.pitch-p.trans.kerf; 

c0 = p.trans.c0; % Speed of sound [m/s]


%% Simulation

param = struct();
param.fc = p.trans.f0;
param.kerf = p.trans.kerf;
param.width = p.trans.element_width;
param.pitch = p.trans.pitch;
param.Nelements = p.trans.N;
param.bandwidth = min( 65, 100./p.trans.pulse_duration);
param.radius = Inf;
param.height = p.trans.element_height;

param.c = c0;
param.fs = p.trans.f0*4;
param.fnumber = p.acq.F_number;

scatx = flowLine(:,1).'; % transposing yields PSFs instead of single image
scatz = flowLine(:,3).';
RC = ones( size( scatx) );

xs = linspace( setup.scan.xStart, setup.scan.xEnd, setup.scan.Nx);
zs = linspace( setup.scan.zStart, setup.scan.zEnd, setup.scan.Nz);
[X,Z] = meshgrid(xs,zs);
sca=uff.linear_scan('x_axis',xs.', 'z_axis', zs.');
PSFs.scan = sca;
PSFs.modulation_frequency = param.fc;

N = length(p.acq.alphaTx);
p.phaseVecsTx = [sin(p.acq.alphaTx); zeros( size( p.acq.alphaTx) ); cos(p.acq.alphaTx)];
p.phaseVecsRx = [sin(p.acq.alphaRx); zeros( size( p.acq.alphaRx) ); cos(p.acq.alphaRx)];
refDistsGrid = X.*permute(2*p.phaseVecsRx(1,:), [1 3 2]) + ...
    Z.*permute(2*p.phaseVecsRx(3,:), [1 3 2]);

opt.waitbar = false;
tic
for angleind = 1:N
    txDelay = txdelay( param, -p.acq.alphaTx(angleind) ); % NB! MUST sign convention
    param.RXangle = -p.acq.alphaRx(angleind);

    [RF, param] = simus( scatx, scatz, RC, txDelay, param, opt);
    IQ = rf2iq(RF,param);
    IQb = das(IQ,X,Z,txDelay,param);
    IQb = IQb.*exp(-1i*2*pi*refDistsGrid(:,:,angleind)./c0*p.trans.f0 ); % Rx phase compensation
    if angleind == 1
        PSFs.data = zeros( [length(xs)*length(zs) 1 N size( flowLine, 1) ] );
    end
    PSFs.data(:,:,angleind,:) = reshape( IQb, [length(xs)*length(zs) 1 1 size( flowLine, 1) ] );
end
% add phase correction for FLUST interpolation step, improves numerical stability
refDists = flowLine*(p.phaseVecsTx+p.phaseVecsRx);
p.phaseCorr = refDists./c0*p.trans.f0;
PSFs.isMUST = 1;
toc