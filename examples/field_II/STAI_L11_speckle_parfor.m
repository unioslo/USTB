%% Computation of a STAI dataset with Field II to simulate specular tissue using parameters of an L11-4v 128 element Verasonics Transducer and beamforming with USTB and using MATLAB's parfor function for parallelization
%
% This example shows how to load the data from a Field II simulation of specular tissue into
% USTB objects, and then beamform it with the USTB routines.
% This example uses the L11-4v 128 element Verasonics Transducer
% The Field II simulation program (<field-ii.dk>) should be in MATLAB's path.
%
% This tutorial assumes familiarity with the contents of the
% <../../fresnel/linear_array/html/CPWC_linear_array.html 'CPWC simulation with the USTB built-in Fresnel
% simulator'> tutorial. Please feel free to refer back to that for more
% details.
%
% _by Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>, Ole Marius Hoel
% Rindal <olemarius@olemarius.net> and Arun Asokan Nair <anair8@jhu.edu> 09.05.2017_

%% Clear old workspace and close old plots

clear all;
close all;

filename = 'FieldII_speckle_simulation.uff';

if exist([data_path filesep filename]) > 0 %If the file exists load the file
    
    disp('We were lucky, and the data was already simulated, so we can simply load it!');
    uff_file= [data_path filesep filename];
    channel_data = uff.read_object(uff_file,'/channel_data');
    
else % Else, run the simulation
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
    pulse_duration          = 2.5;             % pulse duration [cycles]
    
    %% Pulse definition
    %
    % We then define the pulse-echo signal which is done here using the
    % *fresnel* simulator's *pulse* structure. We could also use
    % <http://field-ii.dk/ 'Field II'> for a more accurate model.
    
    pulse = uff.pulse();
    pulse.center_frequency = f0;
    pulse.fractional_bandwidth = 0.65;        % probe bandwidth [1]
    t0 = (-1/pulse.fractional_bandwidth/f0): dt : (1/pulse.fractional_bandwidth/f0);
    impulse_response = gauspuls(t0, f0, pulse.fractional_bandwidth);
    impulse_response = impulse_response-mean(impulse_response); % To get rid of DC
    
    te = (-pulse_duration/2/f0): dt : (pulse_duration/2/f0);
    excitation = square(2*pi*f0*te+pi/2);
    one_way_ir = conv(impulse_response,excitation);
    two_way_ir = conv(one_way_ir,impulse_response);
    lag = length(two_way_ir)/2;
    
    % We display the pulse to check that the lag estimation is on place
    % (and that the pulse is symmetric)
    
    figure;
    plot((0:(length(two_way_ir)-1))*dt -lag*dt,two_way_ir); hold on; grid on; axis tight
    plot((0:(length(two_way_ir)-1))*dt -lag*dt,abs(hilbert(two_way_ir)),'r')
    plot([0 0],[min(two_way_ir) max(two_way_ir)],'g');
    legend('2-ways pulse','Envelope','Estimated lag');
    title('2-ways impulse response Field II');
    
    %% Aperture Objects
    % Next, we define the the mesh geometry with the help of Field II's
    % *xdc_linear_array* function.
    
    noSubAz=round(probe.element_width/(lambda/8));        % number of subelements in the azimuth direction
    noSubEl=round(probe.element_height/(lambda/8));       % number of subelements in the elevation direction
    Th = xdc_linear_array (probe.N, probe.element_width, probe.element_height, kerf, noSubAz, noSubEl, [0 0 Inf]);
    Rh = xdc_linear_array (probe.N, probe.element_width, probe.element_height, kerf, noSubAz, noSubEl, [0 0 Inf]);
    
    % We also set the excitation, impulse response and baffle as below:
    xdc_excitation (Th, excitation);
    xdc_impulse (Th, impulse_response);
    xdc_baffle(Th, 0);
    xdc_center_focus(Th,[0 0 0]);
    xdc_impulse (Rh, impulse_response);
    xdc_baffle(Rh, 0);
    xdc_center_focus(Rh,[0 0 0]);
    
    %% Speckle Phantom
    %
    % In our next step, we define our phantom. Here, our goal is to simulate
    % speckle so we have a 100 scatterrers with axial and lateral coordinates
    % randomly drawn from a uniform distribution and scatterer amplitudes
    % randomly drawn from a normal distribution.
    
    number_of_scatterers = 500000;
    xxp_speckle=random('unif',-5e-3,5e-3,number_of_scatterers,1);
    zzp_speckle=random('unif',15e-3,20e-3,number_of_scatterers,1);
    sca = [xxp_speckle zeros(length(xxp_speckle),1) zzp_speckle];  % list with the scatterers coordinates [m]
    amp=randn(length(sca),1);                   % list with the scatterers amplitudes
    cropat=round(1.1*2*sqrt((max(sca(:,1))-min(probe.x))^2+max(sca(:,3))^2)/c0/dt);   % maximum time sample, samples after this will be dumped
    
    %% Output data
    %
    % We define the variables to store our output data
    
    t_out=0:dt:((cropat-1)*dt);                 % output time vector
    STA=zeros(cropat,probe.N,probe.N);    % impulse response channel data
    %% Compute STA signals
    %
    % Now, we finally reach the stage where we generate a STA (Synthetic
    % Transmit Aperture) dataset with the help of Field II.
    
    disp('Field II: Computing STA dataset');
    disp('No waitbar possible for parfor, so just be patient :)');
    parfor n=1:probe.N
        %Since we are using parfor, we have to initate Field II and the arrays
        %for every worker as well.
        field_init(0);
        Th = xdc_linear_array (probe.N, probe.element_width, probe.element_height, kerf, noSubAz, noSubEl, [0 0 Inf]);
        Rh = xdc_linear_array (probe.N, probe.element_width, probe.element_height, kerf, noSubAz, noSubEl, [0 0 Inf]);
        xdc_excitation (Th, excitation);
        xdc_impulse (Th, impulse_response);
        xdc_baffle(Th, 0);
        xdc_center_focus(Th,[0 0 0]);
        xdc_impulse (Rh, impulse_response);
        xdc_baffle(Rh, 0);
        xdc_center_focus(Rh,[0 0 0]);
        
        % transmit aperture
        xdc_apodization(Th, 0, [zeros(1,n-1) 1 zeros(1,probe.N-n)]);
        xdc_focus_times(Th, 0, zeros(1,probe.N));
        
        % receive aperture
        xdc_apodization(Rh, 0, ones(1,probe.N));
        xdc_focus_times(Rh, 0, zeros(1,probe.N));
        
        % do calculation
        [v,t]=calc_scat_multi(Th, Rh, sca, amp);
        
        % save data -> with parloop we need to pad the data
        if size(v,1)<cropat
            STA(:,:,n)=padarray(v,[cropat-size(v,1) 0],0,'post');    
        else
            STA(:,:,n)=v(1:cropat,:);
        end
        
        % Sequence generation
        seq(n)=uff.wave();
        seq(n).probe=probe;
        seq(n).source.xyz=[probe.x(n) probe.y(n) probe.z(n)];
        seq(n).sound_speed=c0;
        seq(n).delay = probe.r(n)/c0-lag*dt+t; % t0 and center of pulse compensation
    end
    
    %% Channel Data
    %
    % In this part of the code, we creat a uff data structure to specifically
    % store the captured ultrasound channel data.
    
    channel_data = uff.channel_data();
    channel_data.sampling_frequency = fs;
    channel_data.sound_speed = c0;
    channel_data.initial_time = 0;
    channel_data.pulse = pulse;
    channel_data.probe = probe;
    channel_data.sequence = seq;
    channel_data.data = STA./max(STA(:));
    
    %% Save UFF dataset
    %
    % Finally, we save the data into a UFF file.
    % There is a 
    channel_data.write([data_path filesep filename],'channel_data');
    
end
%% Scan
%
% The scan area is defines as a collection of pixels spanning our region of
% interest. For our example here, we use the *linear_scan* structure,
% which is defined with two components: the lateral range and the
% depth range. *scan* too has a useful *plot* method it can call.

scan=uff.linear_scan('x_axis',linspace(-5e-3,5e-3,256).', 'z_axis', linspace(15e-3,20e-3,256).');

%% Beamformer
%
% With *channel_data* and a *scan* we have all we need to produce an
% ultrasound image. We now use a USTB structure *beamformer*, that takes an
% *apodization* structure in addition to the *channel_data* and *scan*.

pipe=pipeline();
pipe.channel_data=channel_data;
pipe.scan=scan;

% Delay and sum on receive, then coherent compounding
b_data=pipe.go({midprocess.das() postprocess.coherent_compounding()});

% Display image
figure(1);clf
b_data.plot(1)

%% Plot a PDF of speckle and compare to theoretically predicted Rayleigh distribution that speckle possesses
envelope = abs(b_data.data);
envelope = envelope./max(envelope(:));
m = mean(envelope(:));
s = std(envelope(:));

snr_calculated_das = m/s
snr_theoretical = (pi/(4-pi))^(1/2)
b = s/(sqrt((4-pi)/2)); %Scale parameter

% Estimate PDF
x_axis = linspace(0,1,200);
[n,xout] = hist(envelope(:),x_axis);
delta_x = xout(2)-xout(1);
n = n/sum(n)/delta_x;

% Theoretical Rayleigh PDF
theoretical_pdf = (x_axis./b^2).*exp(-x_axis.^2/(2.*b^2));

% Plot
color=[0.25 1 0.75]
figure(2);clf;
plot(xout,n,'LineWidth',2,'Color','r','DisplayName','Estimated PDF');hold on;
plot(x_axis,theoretical_pdf,'--','Color',color,'LineWidth',2,'DisplayName','Rayleigh Theoretical PDF');
title('PDF of envelope');
xlabel('Normalized amplitude');
ylabel('Probability')
legend('show');