function ok = TE_ps_sta_rf_mex(h)
%PS_STA_RF Point Spread function Synthetic Transmit Aperture RF test
%   Downloads data from 'https://www.ustb.no/datasets/ps'
%   beamforms it and compares it with previously beamformed data (USTB v1.9)

    import uff.*;
    
    % data location
    url='https://www.ustb.no/datasets/ps';   % if not found data will be downloaded from here
    local_path=[ustb_path() '/data/ps/'];                              % location of example data in this computer                      
    raw_data_filename='ps_sta_rf.mat';
    beamformed_data_filename='beamformed_ps_sta_rf.mat';
    
    % check if the file is available in the local path & downloads otherwise
    tools.download(raw_data_filename, url, local_path);
    tools.download(beamformed_data_filename, url, local_path);
    
    % load data
    load([local_path raw_data_filename]);    
    load([local_path beamformed_data_filename]);    
    
    % PROBE
    prb=probe();
    prb.geometry = s.geom;

    
    % SEQUENCE 
    for n=1:prb.N_elements 
        seq(n)=wave();
        seq(n).probe=prb;
        seq(n).sound_speed=s.c0;
        seq(n).source.xyz=[prb.x(n) prb.y(n) prb.z(n)];
        seq(n).delay=seq(n).source.distance/s.c0;
    end
    
    % RAW DATA
    r_data=channel_data();
    r_data.probe=prb;
    r_data.sequence=seq;
    r_data.initial_time=s.time(1);
    r_data.sampling_frequency=1/(s.time(2)-s.time(1));
    r_data.sound_speed=s.c0;
    r_data.data=s.data;
    
    % BEAMFORMER
    pipe=pipeline();
    pipe.channel_data=r_data;
    pipe.receive_apodization.window = window.boxcar;
    pipe.receive_apodization.f_number = r.f_number;
    pipe.transmit_apodization.window = window.boxcar;
    pipe.transmit_apodization.f_number = r.f_number;
    pipe.scan=linear_scan('x_axis',r.x_axis,'z_axis',r.z_axis);
    
    % beamforming
    b_data=pipe.go({midprocess.das postprocess.coherent_compounding});

    % test result
    ok=(norm(real(b_data.data)-r.data(:))/norm(r.data(:)))<h.external_tolerance;

%     figure;
%     plot(b_data.data); hold on; grid on;
%     plot(r.data(:),'r--'); 
%    
%     % show
%     b_data.plot([],'Result');
%     
%     % ref
%     ref_data=beamformed_data();
%     ref_data.data=r.data;
%     ref_data.scan=linear_scan(r.x_axis,r.z_axis);
%     ref_data.plot([],'Reference');
    
end

