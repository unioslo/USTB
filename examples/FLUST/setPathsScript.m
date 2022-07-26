lastwarn(''); % reset warning

%% set paths here

% PSF generators (Field II/MUST/other)
addpath('PathToField'); % Path to Field II goes here
addpath('PathToMUST'); % Path to MUST if this is used

% FLUST folders
addpath( genpath( pwd) ); % please run FLUST from its root folder
addpath('..\..'); % ustb main folder

%% check if addpath returned warnings
[warnmsg, msgid] = lastwarn;
if strcmp( msgid, 'MATLAB:mpath:nameNonexistentOrNotADirectory')
    disp('At least one addpath statement in setPathsScript returned with a warning.')
    edit setPathsScript.m
    warning('Check that paths to PSF simulator (Field/MUST/other) are set properly in setPathsScript.m');
end