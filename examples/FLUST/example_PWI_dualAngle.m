% Updated 10/11/2020, Joergen Avdal (jorgen.avdal@ntnu.no)

% Anne Saris 31-05-2022, first example script for dual angle plane wave imaging
% Data will be beamformed at angled grids, to be used seperately in the
% velocity-estimator.

% If using FLUST for scientific publications, please cite the original paper
% Avdal et al: Fast Flow-Line-Based Analysis of Ultrasound Spectral and
% Vector Velocity Estimators, tUFFC, 2019.

% FLUST is a simulation tool based on flowlines, useful for producing many
% realizations of the same flowfield. The motivation for making FLUST was
% to faciliate accurate assessment of statistical properties of velocity
% estimators like bias and variance.

% Using FLUST requires the user to provide/select two functions, one to create
% the flowlines, and one to calculate the PSFs from a vector of spatial
% positions. 

% After running this script, variable realTab contains realizations, and
% variables PSFs and PSFstruct contains point spread functions of the last flow line.

% FLUST accounts for interframe motion in plane wave sequences, assuming
% uniform firing rate, but not in scanned sequences.

% How to use FLUST:
% 1) Provide/select function to calculate PSFs from a vector of spatial positions. 
% 2) Run FLUST on phantom of interest.
% 3) Apply your favorite velocity estimator to realizations. 
% 4) Assess statistical properties of estimator, optimize estimator.
% 5) Publish results, report statistical properties, make results
%    reproducible.
% 6) Cite original FLUST paper

clear all;
close all;

setPathsScript;

%% DATA OUTPUT PARAMETERS
s = struct();

s.firing_rate = 8000; % firing rate of output signal, (Doppler PRF) = (firing rate)/(nr of firings)
s.nrReps = 100;         % nr of realizations 
s.nrSamps = 40;       % nr of slow time samples in each realization (Ensemble size)

s.contrastMode = 0;      % is set to 1, will simulate contrast scatterers propagating in flow field
s.contrastDensity = 0.1; % if using contrastMode, determines the density of scatterers, typically < 0.2

%% QUALITY PARAMETERS, SET ONLY ONE OF THESE
% s.dr = 5e-5;  % spatial discretization along flowlines: lambda/4 or smaller recommended if phase information is important
s.interpErrorLimit = 4; % FLUST will set s.dr to attain interpolation error smaller than this value in percent

%% PERFORMANCE PARAMETER
s.chunksize = 1;         % chunking on scanlines, adjust according to available memory.
s.useGPU = 0;


%% DEFINE ACQUSITION SETUP / PSF FUNCTIONS 
s.PSF_function = @PSFfunc_LinearProbe_PlaneWaveImaging_rotatedGrid;

% Tranducer and acquisition parameters. Print s.PSF_params after running simulation to see which parameters can be set.
s.PSF_params = [];     
% Transducer params - resembling L11-3
s.PSF_params.trans.f0 = 7.8e6;
s.PSF_params.trans.pulse_duration = 1.5;
s.PSF_params.trans.pitch = 135e-6;
s.PSF_params.trans.kerf = 13.5e-6;
s.PSF_params.trans.element_height = 5e-3;


% Acquisition params
s.PSF_params.acq.F_number = 1.16; % 128 elements
s.PSF_params.acq.alphaTx = [-20 20]*pi/180;
s.PSF_params.acq.alphaRx = [-20 20]*pi/180; 
% Image/scan region params
s.PSF_params.scan.rx_apod = 'tukey25';
s.PSF_params.scan.xStart = -3e-3;
s.PSF_params.scan.xEnd = 3e-3;
s.PSF_params.scan.Nx = 128;
s.PSF_params.scan.zStart = 15e-3;
s.PSF_params.scan.zEnd = 25e-3;
s.PSF_params.scan.Nz = 128;

% Runtime params
s.PSF_params.run.chunkSize = 101; % Description?

%% DEFINE PHANTOM AND PSF FUNCTIONS
%s.phantom_function = @Phantom_parabolic3Dtube;
% s.phantom_function = @Phantom_parabolic2Dtube;
s.phantom_function = @Phantom_gradient2Dtube;


% Phantom parameters. Print s.phantom_params after running simulation to see which parameters can be set.
s.phantom_params = []; 
s.phantom_params.btfAZ = 90;
% s.phantom_params.btf = 90;
s.phantom_params.flowlength = 0.012;
s.phantom_params.diameter = 0.006; % Number of flowlines = ceil(diameter/maxLineSpacing)+1
s.phantom_params.tubedepth = 0.02;
s.phantom_params.maxLineSpacing = 0.0001; % NB: Needs to be sufficiently small for given application - in the order of lambda/2;
% s.phantom_params.vel_low = 0.001;
% s.phantom_params.vel_high = 0.5;
s.phantom_params.vel_1 = 0.02;
s.phantom_params.vel_2 = 0.5;

% To output true velocities in phantom, define grid
myX = linspace(s.PSF_params.scan.xStart,s.PSF_params.scan.xEnd,s.PSF_params.scan.Nx);
myZ = linspace(s.PSF_params.scan.zStart,s.PSF_params.scan.zEnd,s.PSF_params.scan.Nz);
[X,Z] =  meshgrid(myX,myZ);

% make phantom, get true velocity and phantom parameters
%  [flowField, s.phantom_params, GT] = s.phantom_function(s.phantom_params,X,Z); % flowField should have timetab and postab fields
Y = zeros( size(X) );
[flowField, s.phantom_params, GT] = s.phantom_function(s.phantom_params,X,Y,Z); % flowField should have timetab and postab fields

%% AS, visualize flowlines & GT
figure
for i = 1:size(flowField,2) % all flowlines
    hold on, plot3(flowField(i).postab(:,1)*1000,flowField(i).postab(:,2)*1000, flowField(i).postab(:,3)*1000,'*-')    
end
hold on, plot3(0, 0, s.phantom_params.tubedepth*1000, '.k')
%     hold on, plot3(zeros(size(depthtab,2)), zeros(size(depthtab,2)), depthtab*1000, 'sqk')
xlabel('X (mm)'), ylabel('Y (mm)'), zlabel('Z (mm)')
hold off
grid on
title('Flowlines, rF(t)')
set(gca,'zdir','reverse')
view(3)

GTT = reshape(GT, [s.PSF_params.scan.Nx, s.PSF_params.scan.Nz, 3]);
figure,subplot(1,4,1), imagesc(X(:),Z(:),GTT(:,:,1)), title('Vx'), colorbar
hold on, subplot(1,4,2), imagesc(X(:),Z(:), GTT(:,:,2)), title('Vy'), colorbar
subplot(1,4,3), imagesc(X(:),Z(:), GTT(:,:,3)), title('Vz'), colorbar
subplot(1,4,4), imagesc(X(:), Z(:), sqrt(GTT(:,:,1).^2 + GTT(:,:,2).^2 + GTT(:,:,3).^2)), title('Vmagn'), colorbar

% % figure, imagesc(X(:),Z(:),GT), title('Vmagn'), colorbar
% figure, hold on, pcolor(X*1000,Z*1000,GT), shading interp, title('Vmagn (m/s)'), colorbar
% set(gca,'ydir','reverse'), axis image
% xlabel('X (mm)'), ylabel('Z (mm)')  
    

%% FLUST main loop
tic
runFLUST;
disp('Running time FLUST')
toc

% Elapsed time is 2454.964098 seconds.

%% Save realizations
dir = 'SaveData';
filename = 'PWI_dualAngle_gradient2Dtube.mat';

% save(fullfile(dir, filename) ); % savebinary function soon available


%% VISUALIZE FIRST REALIZATION using the built-in beamformed data object

% AS: not possble yet to show data on linear_scan_rotated using ustb yet
% --> USTB: beamformed_data.m has to be adapted

% firstRealization = realTab(:,:,:,1,1);
% 
% b_data = uff.beamformed_data();
% b_data.scan = PSFstruct.scan;
% b_data.data = reshape(firstRealization,size(firstRealization,1)*size(firstRealization,2),1,1,size(firstRealization,3));
% b_data.plot([],['Flow from FLUST'],[20])

%% AS - temp, own visualization of realizations

dynamic_range = 60;
ensNr = 1;

% Movie object
filenameMovie       = fullfile( dir, 'realizationsGradFlow.avi' );
writerObj           = VideoWriter(filenameMovie,'Motion JPEG AVI');
writerObj.FrameRate = 5;
writerObj.Quality   = 80;
open(writerObj);

% axis info
xc = p.scan.xStart+((p.scan.xEnd-p.scan.xStart)/2);% Center of rotation
zc = p.scan.zStart + ((p.scan.zEnd-p.scan.zStart)/2);
if ~exist('sca','var')
    nA = size(realTab,4);
    sca = cell(1,nA);
    for a = 1:nA
        sca{a} = uff.linear_scan_rotated('x_axis',linspace(p.scan.xStart,p.scan.xEnd,p.scan.Nx).', 'z_axis', linspace(p.scan.zStart,p.scan.zEnd,p.scan.Nz).', 'rotation_angle', p.acq.alphaTx(a) ,'center_of_rotation',[xc,0,zc]');
    end
end
x1 = reshape(sca{1}.x,[sca{1}.N_x_axis, sca{1}.N_z_axis])*1000;
z1 = reshape(sca{1}.z,[sca{1}.N_x_axis, sca{1}.N_z_axis])*1000;
x2 = reshape(sca{2}.x,[sca{2}.N_x_axis, sca{2}.N_z_axis])*1000;
z2 = reshape(sca{2}.z,[sca{2}.N_x_axis, sca{2}.N_z_axis])*1000;

% temp - visualize grid en TD
    figure, plot(x1,z1,'*b')
    hold on, plot(x2,z2,'*g')
    set(gca,'ydir','reverse')

    pitch = p.trans.pitch;
    numelements = p.trans.N; 
    numelementsA = p.trans.Na;
    elempos             = 1000* linspace(-(numelements-1)/2,...              % z-coordinates of the elements
                           (numelements-1)/2,...
                           numelements)*pitch;
    hold on, plot(elempos,zeros(size(elempos)),'sqk')
    xlabel('X (mm)'), ylabel('Z (mm)')

    angles = p.acq.alphaTx / pi*180;

    % Determine borders of PW angled beams
    % PW-20
    depth   = p.scan.zEnd*1000 + 10;
    bx1      = elempos(p.trans.elemStart(1));
    bx1_d    = elempos(p.trans.elemStart(1)) - depth*tand(-angles(1));
    bx2      = elempos(p.trans.elemEnd(1));
    bx2_d    = elempos(p.trans.elemEnd(1)) - depth*tand(-angles(1));
    xmin    = [bx1 bx1_d bx2_d bx2 bx1];
    ymin    = [0 depth depth 0 0];

    % PW+20
    bx1      = elempos(p.trans.elemStart(2));
    bx1_d    = elempos(p.trans.elemStart(2)) - depth*tand(-angles(2));
    bx2      = elempos(p.trans.elemEnd(2));
    bx2_d    = elempos(p.trans.elemEnd(2)) - depth*tand(-angles(2));
    xplus   = [bx1 bx1_d bx2_d bx2 bx1];
    yplus   = [0 depth depth 0 0];
    clear bx1 bx1_d bx2 bx2_d depth

    hold on, plot(xmin,ymin, '--b')
    plot(xplus,yplus,'--g')
    axis image
    
    % phantom borders
    hold on, plot([0-s.phantom_params.flowlength/2 0+s.phantom_params.flowlength/2]*1000,[s.phantom_params.tubedepth-s.phantom_params.diameter/2 s.phantom_params.tubedepth-s.phantom_params.diameter/2]*1000,'--r')
    hold on, plot([0-s.phantom_params.flowlength/2 0+s.phantom_params.flowlength/2]*1000,[s.phantom_params.tubedepth+s.phantom_params.diameter/2 s.phantom_params.tubedepth+s.phantom_params.diameter/2]*1000,'--r')


% data
firstReal = realTab(:,:,:,:,ensNr);
envelope = abs(firstReal);
envelope = 20*log10(envelope./max(envelope(:)));
max_value = 0;
min_value = -dynamic_range;

% figure
% [ fig(1), ah1 ]  = multipleAxes( 700, 1100, 1, 2, 0,45,'on',[1 1 1], [1 1 1] );
fig(1) = figure(100);
set( fig(1), 'Position', [10 10 700 1100]);

ah1(1) = subplot(2,1,1); ah1(2) = subplot(2,1,2);

for fr = 1:s.nrSamps
    
    % angle 1
    a = 1;
%     axes(ah1(1))
%     hold(ah1(1), 'off')
    pcolor(ah1(1), x1, z1, envelope(:,:,fr, a)), shading(ah1(1),'interp')
    set(ah1(1),'ydir','reverse')
    xlabel(ah1(1), 'X (mm)')
    ylabel(ah1(1), 'Z (mm)')
    axis(ah1(1), 'image');
    title(ah1(1), ['PW-20, ensNr: ', num2str(ensNr, '%02d'), ', frameNr: ', num2str(fr, '%02d')])
    colormap(ah1(1), gray);
    caxis(ah1(1),[min_value max_value]);
%     brighten( -0.5)
    colorbar(ah1(1))
    
    % borders PW and phantom geom
%     hold(ah1(1), 'on'), plot(ah1(1), xmin,ymin, '--b')
%     plot(ah1(1), [0-s.phantom_params.flowlength/2 0+s.phantom_params.flowlength/2]*1000,[s.phantom_params.tubedepth-s.phantom_params.diameter/2 s.phantom_params.tubedepth-s.phantom_params.diameter/2]*1000,'--r')
%     plot(ah1(1), [0-s.phantom_params.flowlength/2 0+s.phantom_params.flowlength/2]*1000,[s.phantom_params.tubedepth+s.phantom_params.diameter/2 s.phantom_params.tubedepth+s.phantom_params.diameter/2]*1000,'--r')
    
    % angle 2
%     axes(ah1(2))
    a = 2;
%     hold(ah1(2), 'off')
    pcolor(ah1(2), x2, z2, envelope(:,:,fr, a)), shading(ah1(2), 'interp');
    set(ah1(2),'ydir','reverse')
    xlabel(ah1(2),'X (mm)')
    ylabel(ah1(2),'Z (mm)')
    axis(ah1(2), 'image');
    title(ah1(2),['PW+20, ensNr: ', num2str(ensNr, '%02d'), ', frameNr: ', num2str(fr, '%02d')])
    colormap( ah1(2), gray);
    caxis(ah1(2),[min_value max_value]);
%     brighten(-0.5)
    colorbar( ah1(2) )
    
    % borders PW phantom params
%     hold( ah1(2), 'on'), plot(ah1(2), xplus,yplus,'--g')
%     plot(ah1(2), [0-s.phantom_params.flowlength/2 0+s.phantom_params.flowlength/2]*1000,[s.phantom_params.tubedepth-s.phantom_params.diameter/2 s.phantom_params.tubedepth-s.phantom_params.diameter/2]*1000,'--r')
%     plot(ah1(2), [0-s.phantom_params.flowlength/2 0+s.phantom_params.flowlength/2]*1000,[s.phantom_params.tubedepth+s.phantom_params.diameter/2 s.phantom_params.tubedepth+s.phantom_params.diameter/2]*1000,'--r')
     
    writeVideo(writerObj,getframe(fig(1)))
    
end

close(writerObj)

%% True velocities?

% figure(); imagesc(X(:), Z(:), GT); title('Vmag') % Example, looking at velocity magnitude (NB, change to x and z component)


GT_rsh = reshape( GT, [s.PSF_params.scan.Nz s.PSF_params.scan.Nx 3] );
figure(); imagesc(X(:), Z(:), GT_rsh(:,:,1)); title('Vx') % Example, looking at x component of velocity field


