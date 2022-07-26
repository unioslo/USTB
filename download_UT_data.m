function download_UT_data(h)% data location
url='https://www.ustb.no/datasets/';   % if not found data will be downloaded from here
local_path=[ustb_path() '/data/'];                              % location of example data in this computer
zip_data='ps.zip';

fprintf('Downloading and unzipping data for unit tests...');
% check if the file is available in the local path & downloads otherwise
%tools.download(zip_data, url, local_path);
websave([local_path,zip_data],[url,zip_data]);
%%
unzip([local_path,zip_data],local_path)
fprintf('...done!')
end