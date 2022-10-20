clear all
close all
clc

file_id = 2;    % 1. Google drive. Large file. Requires confirm
                % 2. Google drive. Small file. Does not require confirm
                % 3. Nyhirse St. Olav 
                % 4. ustb.no

switch file_id
    case 1
        url = ['https://drive.google.com/uc?export=download' ...
            '&id=19OyvPCP4qUiTECFpUe8r3r_Ys2281j0N'];
        name = 'Verasonics_P2-4_apical_four_chamber_subject_1.uff';
    case 2
        url = ['https://drive.google.com/uc?export=download' ...
            '&id=1LDu9WGeYvOFY--TnIHrUHBsvranQsPKf'];
        name = 'PICMUS_carotid_long.uff';
    case 3
        url = ['https://nyhirse.medisin.ntnu.no/ustb/data/ps/' ...
            'ps_cpw_rf.mat'];
        name = 'ps_cpw_rf.mat';
    case 4
        url = 'https://ustb.no/datasets/L7_FI_IUS2018.uff';
        name = 'L7_FI_IUS2018.uff';
end

file = fullfile(data_path(), 'test_folder', name);

tools.download(file, url)


