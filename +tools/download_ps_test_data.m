function download_ps_test_data()
%DOWNLOAD_PS_TEST_DATA  Ensure ps/ test .mat files are available locally.
%   Downloads individual .mat files from Zenodo record 20269473 into data/ps/.

ps_dir = fullfile(ustb_path(), 'data', 'ps');
if ~isfolder(ps_dir)
    mkdir(ps_dir);
end

url = 'https://zenodo.org/records/20270074/files';

files = {'ps_vs_iq.mat', 'ps_vs_rf.mat', 'ps_sta_iq.mat', 'ps_sta_rf.mat', ...
         'ps_cpw_iq.mat', 'ps_cpw_rf.mat', ...
         'beamformed_ps_vs_iq.mat', 'beamformed_ps_vs_rf.mat', ...
         'beamformed_ps_sta_iq.mat', 'beamformed_ps_sta_rf.mat', ...
         'beamformed_ps_cpw_iq.mat', 'beamformed_ps_cpw_rf.mat'};

for k = 1:numel(files)
    tools.download(files{k}, url, ps_dir);
end

end
