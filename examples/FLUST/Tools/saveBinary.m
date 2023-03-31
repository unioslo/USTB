function saveBinary( tag, opts)
if nargin < 2
    opts.overWrite = 0; % overwrite existing file without asking first
    opts.keepClass = 0; % 0 - convert scan object to struct, 1 - keep scan object
end
if ~isfield( opts, 'overWrite')
    opts.overWrite = 0;
end
if ~isfield( opts, 'keepClass')
    opts.keepClass = 0;
end
if nargin < 1
    tag = ['FLUSTsim_' strrep( strrep( strrep( datestr(datetime('now') ), ':', '_' ), ' ', '_'), '-', '_')];
end
% save binary file and meta
saveFolder = '.\saveData';
if ~exist( saveFolder, 'dir')
    mkdir( saveFolder)
end
saveStr = [saveFolder '\' tag];

metafile = [saveStr '_meta'];
if exist( metafile, 'file') && ~opts.overWrite
    answer = questdlg(['File ', metafile ' exists, do you want to overwrite?', 'Yes', 'No']);
    if isempty( answer) || strcmp( answer, 'no')
        return
    end
end

realTab = evalin( 'base', 'realTab');
PSFstruct = evalin( 'base', 'PSFstruct');
s = evalin( 'base', 's');
GT = evalin( 'base', 'GT');
X = evalin( 'base', 'X');
Y = evalin( 'base', 'Y');
Z = evalin( 'base', 'Z');
flowField = evalin( 'base', 'flowField');

RTsize = size( realTab);
PSFstruct.data = [];
if ~opts.keepClass
    PSFstruct = struct( PSFstruct);
    PSFstruct.scan = struct( PSFstruct.scan);
end

save(metafile, 'RTsize', 'PSFstruct', 's', 'GT', 'X', 'Y', 'Z', 'flowField');

fid = fopen( [saveStr '_dataR'], 'w');
fwrite( fid, real(realTab), 'single');
fclose( fid);

fid = fopen( [saveStr '_dataI'], 'w');
fwrite( fid, imag(realTab), 'single');
fclose( fid);

disp( ['Saved ' tag ' to ' saveFolder])