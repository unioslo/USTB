function loadBinary(tag)
if nargin < 1
    [filename, saveFolder] = uigetfile( ['saveData' filesep '*.mat'] );
    tag = filename(1:end-9);
else
    saveFolder = 'saveData';
end
% load binary file and meta
% addpath('C:\Users\ingvilek\OneDrive - NTNU\FLUST\ustb_phantomDB')
% saveFolder = '.\saveData\';
% tag = 'spinningDisk_0p2To0p7_diam7mm_twoAngles_Field'
% tag = 'gradientTube_0p1To1p0_diam6mm_btfAz60_Field'
loadstr = [saveFolder '\' tag];

load([loadstr '_meta']);

fid = fopen( [loadstr '_dataR'], 'r');
dataR = fread( fid, 'single');
fclose( fid);

fid = fopen( [loadstr '_dataI'], 'r');
dataI = fread( fid, 'single');
fclose( fid);

realTab = reshape( dataR+1i*dataI, RTsize);

assignin( 'base', 'realTab', realTab);
assignin( 'base', 'PSFstruct', PSFstruct);
assignin( 'base', 's', s);
assignin( 'base', 'GT', GT);
assignin( 'base', 'X', X);
assignin( 'base', 'Y', Y);
assignin( 'base', 'Z', Z);
assignin( 'base', 'flowField', flowField);
