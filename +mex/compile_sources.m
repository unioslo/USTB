% Compiles USTB mex sources 
%
% FOR WINDOWS:
% Works on MS with Visual Studo 2010+.
%
% FOR LINUX :
% Works with Intel TBB library.
%
% FOR MAC:
% Works with oneTBB parallellization library
% oneTBB (formerly Intel TBB) can be installed with Homebrew using the command
% "brew install tbb". By default, the latest versions of the necessary files
% will be symlinked in the directories "/opt/homebrew/include" and "/opt/homebrew/lib". 
% If the library is installed to a different location, this alternative 
% path must be specified in build_mex.m. 

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
