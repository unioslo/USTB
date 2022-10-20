function ok = TE_FI_RTB(h)
%TE_FI_RTB Test RTB implementation against previous version
% Downloads data from http://www.USTB.no beamforms it using RTB and 
% compares it with previously beamformed data (USTB develop before merge Feb 2020)
% Author Ole Marius Hoel Rindal (olemarius@olemarius.net)

% data location
url='http://ustb.no/datasets/';      % if not found downloaded from here
filename='L7_FI_IUS2018.uff';
filename_reference='reference_RTB_data.uff';

% Downlad data if needed
tools.download(filename, url, data_path);
tools.download(filename_reference, url, data_path);

% Load channel data
channel_data=uff.read_object([data_path filesep filename],'/channel_data');

% Define axis
x_axis=zeros(channel_data.N_waves,1);
for n=1:channel_data.N_waves
    x_axis(n)=channel_data.sequence(n).source.x;
end
z_axis=linspace(1e-3,62e-3,512*2).';

% Create scan
MLA = 4;
scan_RTB = uff.linear_scan('x_axis',linspace(x_axis(1),x_axis(end),length(x_axis)*MLA)','z_axis',z_axis);

% Do retrospective beamforming
mid_RTB=midprocess.das();
mid_RTB.dimension = dimension.both();

mid_RTB.channel_data=channel_data;
mid_RTB.scan=scan_RTB;
% We are using the hybrid transmit delay model. See the reference below:
% Rindal, O. M. H., Rodriguez-Molares, A., & Austeng, A. (2018). A simple , artifact-free , virtual source model.
% IEEE International Ultrasonics Symposium, IUS, 1–4.
mid_RTB.spherical_transmit_delay_model = spherical_transmit_delay_model.hybrid;
mid_RTB.transmit_apodization.window=uff.window.tukey25;
mid_RTB.transmit_apodization.f_number = 2;
mid_RTB.transmit_apodization.MLA = MLA;
mid_RTB.transmit_apodization.MLA_overlap = MLA;
mid_RTB.transmit_apodization.minimum_aperture = [3.0000e-03 3.0000e-03];

mid_RTB.receive_apodization.window=uff.window.boxcar;
mid_RTB.receive_apodization.f_number=1.7;
b_data_RTB=mid_RTB.go();

% Compensate with weighting
tx_apod = mid_RTB.transmit_apodization.data;
weighting = 1./sum(tx_apod,2);

b_data_RTB_compensated = uff.beamformed_data(b_data_RTB);
b_data_RTB_compensated.data = b_data_RTB.data .* weighting;
%%
% Read reference data
r=uff.read_object([data_path filesep filename_reference],'/b_data');

%figure
%b_data_RTB_compensated.plot(subplot(1,3,1),'RTB image');
%b_data_RTB_compensated.plot(subplot(1,3,2),'Reference img');
%subplot(1,3,3)
%imagesc(scan_RTB.x_axis*1000,scan_RTB.z_axis*1000,abs(r.get_image('none')-b_data_RTB_compensated.get_image('none')))
%axis image; title('Diff');
%colorbar

%% test result
ok=(norm(b_data_RTB_compensated.data-r.data(:))/norm(r.data(:)))<h.internal_tolerance;

end

