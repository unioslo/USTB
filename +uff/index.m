function out=index(filename,location,display)
%% INDEX - Returns contains of a UFF location
%
%   This UFF method returns a list of the datasets and groups
%   in the specified location. The location must be group. The
%   display flag will plot the list on screen.
%
%   out = UFF.INDEX(filename,location,display)
%
%   Example:
%
%       list = uff.index('/',true);
%
%   See also UFF.READ, UFF.UFF, UFF.WRITE

if nargin<2||isempty(location) location='/'; end
if nargin<3||isempty(display) display=false; end

out={}; nn=1;

% try/catch to check that location doesn't exist
try
    info=h5info(filename,location);
catch me
    if isempty(findstr(me.message,'name doesn''t exist')) && isempty(findstr(me.message,'Unable to find object'))
        me.rethrow;
    else
        % the location doesn't exist
        return;
    end
end
if display fprintf('UFF: Contents of %s at %s\n',filename,location); end

% groups
if isfield(info,'Groups')
    groups=info.Groups;
    for n=1:length(groups)
        out{nn}.location=groups(n).Name;
        out{nn}.name=[];
        out{nn}.class=[];
        out{nn}.size=[0 0];
        for m=1:length(groups(n).Attributes)
            if strcmp(groups(n).Attributes(m).Name,'class') out{nn}.class=groups(n).Attributes(m).Value; end
            if strcmp(groups(n).Attributes(m).Name,'name') out{nn}.name=groups(n).Attributes(m).Value; end
            if strcmp(groups(n).Attributes(m).Name,'size') out{nn}.size=groups(n).Attributes(m).Value; end
        end
        if display fprintf('   - %s: %s [%s] size(%d,%d)\n',out{nn}.location, out{nn}.name, out{nn}.class, out{nn}.size); end
        nn=nn+1;
    end
end

% datasets
if isfield(info,'Datasets')
    datasets=info.Datasets;
    for n=1:length(datasets)
        out{nn}.location=[location '/' datasets(n).Name];
        for m=1:length(datasets(n).Attributes)
            if strcmp(datasets(n).Attributes(m).Name,'class') out{nn}.class=datasets(n).Attributes(m).Value; end
            if strcmp(datasets(n).Attributes(m).Name,'name') out{nn}.name=datasets(n).Attributes(m).Value; end
        end
        if display fprintf('   - %s: %s [%s]\n',out{nn}.location, out{nn}.name, out{nn}.class); end
        nn=nn+1;
    end
end

% datasets
if isfield(info,'Datatype')
    out{nn}.location=[location '/' info.Name];
    out{nn}.class=info.Datatype.Class; 
    out{nn}.size=info.Datatype.Size; 
    nn=nn+1;
end