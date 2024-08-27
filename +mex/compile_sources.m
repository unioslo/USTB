% Compiles USTB mex sources 
%
% FOR WINDOWS:
% Works on MS with Visual Studo 2010+.
%
% FOR LINUX :
% Works with Intel TBB library.
%
% FOR MAC:
% Works with Intel TBB library. 
%
% Intel TBB library can be installed via "brew install tbb". Thus, using 
% the Homebrew (https://brew.sh/index_no.html). It is then defaultly 
% installed to /usr/local/Cellar/tbb/2017_U5/include/tbb/

copyfile(fullfile(matlabroot,'extern'),'.mex','f')

% changing to mex path
current_path=pwd;
[pathstr,name,ext] = fileparts(mfilename('fullpath'));
cd(pathstr);

%% das c
disp('------------------------ das_c');
mex.build_mex('das_c');

% going back to initial path
cd(current_path);
