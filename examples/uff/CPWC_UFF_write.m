%% Writting data to a UFF file
%
% In this example we show how to write channel and beamformed data into a
% UFF (Ultrasound File Format) file. The handling couldn't be simpler so
% this is going to be brief.
%
% _by Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no> 29.10.2018_


%% Getting channel data
%
% The first thing we need to save data into a UFF file is, you guessed it,
% data. Let us generate some channel data using the *fresnel*
% simulator included in the USTB. We won't get into details here. If you 
% want to know more about *fresnel* you can find some examples under the
% _fresnel_ folder.
%
% So here we define a 15 angles plane-wave sequence using a 128 elements
% linear array and a 5.2 MHz pulse. The phantom is a cross of point
% scatterers.

% phantom
x_sca=[zeros(1,7) -15e-3:5e-3:15e-3];
z_sca=[5e-3:5e-3:35e-3 20e-3*ones(1,7)];
N_sca=length(x_sca);
pha=uff.phantom();
pha.sound_speed=1540;            % speed of sound [m/s]
pha.points=[x_sca.', zeros(N_sca,1), z_sca.', ones(N_sca,1)];    % point scatterer position [m]
             
% probe
prb=uff.linear_array();
prb.N=128;                  % number of elements 
prb.pitch=300e-6;           % probe pitch in azimuth [m]
prb.element_width=270e-6;   % element width [m]
prb.element_height=5000e-6; % element height [m]

% pulse
pul=uff.pulse();
pul.center_frequency=5.2e6;       % transducer frequency [MHz]
pul.fractional_bandwidth=0.6;     % fractional bandwidth [unitless]

% sequence
N=31;                           % number of plane waves
angles=linspace(-0.3,0.3,N);    % angle vector [rad]
seq=uff.wave();
for n=1:N 
    seq(n)=uff.wave();
    seq(n).source.azimuth=angles(n);
    seq(n).source.distance=Inf;
    seq(n).probe=prb;
    seq(n).sound_speed=pha.sound_speed;
end

% simulator
sim=fresnel();

% setting input data 
sim.phantom=pha;                % phantom
sim.pulse=pul;                  % transmitted pulse
sim.probe=prb;                  % probe
sim.sequence=seq;               % beam sequence
sim.sampling_frequency=41.6e6;  % sampling frequency [Hz]

% launch the simulation
channel_data=sim.go();

% setting dataset name & author information
channel_data.name = 'Test for UFF example';
channel_data.author = {'Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>'}; 
channel_data.reference = {'www.ustb.no'};

%% Getting beamformed data
%
% We will also generate some beamformed data to save into the same UFF
% file. To do that we define a scanning grid, a beamformer, and we set it
% to run.

% scan
scan=uff.linear_scan('x_axis',linspace(-20e-3,20e-3,256).', 'z_axis', linspace(0e-3,40e-3,256).');
 
% pipeline
mid=midprocess.das();
mid.dimension = dimension.both;

mid.channel_data=channel_data;
mid.scan=scan;

mid.transmit_apodization.window=uff.window.tukey50;
mid.transmit_apodization.f_number=1.0;

mid.receive_apodization.window=uff.window.tukey50;
mid.receive_apodization.f_number=1.0;

% beamforming
b_data=mid.go();
b_data.plot();

%% Saving beamformed data
%
% It's about time we start saving some data. To do so we use the method
% *write* of the *uff* class. To do we just have to pass the path to the
% *uff* file to the *write* method of any uff class.

filename = [data_path() filesep 'test03.uff']; 
b_data.write(filename);

%%
%
% Now the beamformed data has been saved into the file. You can check
% the contents of the file with a HDF5 viewer such as
%
% <https://support.hdfgroup.org/products/java/release/download.html HDFView>
% 
% But the UFF packet provides a function that list the contents of a UFF
% file: the *index* function.

display=true;
index=uff.index(filename,'/',display);

%% 
% 
% *uff/index* returns a cell with information on the datasets and
% groups in the specified location, see: 

index{:}

%%
% If the flag *display* is set then the
% function displays that information on screen. *uff/index* is not
% recursive: it only shows the contents of the specified location. Notice 
% that name of the dataset inside the UFF file matches the object's name in 
% MATLAB's workspace 

%%
%
% If we try saving the data again then ...

b_data.write(filename);

%%
%
% ... a dialog will open asking if we want to overwrite the dataset. This
% dialog has a timeout of 5 seconds. If you're not quick it will not
% overwrite the data. Of course to avoid overwritting we can change the
% name of the dataset within the *uff* file by

b_data.write(filename,'b_data_copy');
uff.index(filename,'/',display);

%% Saving channel data
% 
% Saving channel data (or any other *uff* structure) is exactly as we have
% just shown. It might just take a bit more time due to the larger amount
% of data. Here we save *uff.scan* and *uff.channel_data*

%scan.write(filename);
channel_data.write(filename);
uff.index(filename,'/',display);
 
