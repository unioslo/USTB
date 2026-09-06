function path = resolve_channel_data_path(uff_file, preferred)
%RESOLVE_CHANNEL_DATA_PATH  Find HDF5 path to uff.channel_data in a UFF file.
%
%   PREFERRED is optional (e.g. '/channel_data_speckle'). If empty or invalid,
%   we scan the file root for groups with class uff.channel_data.

path = '';
if nargin >= 2 && ~isempty(preferred)
    if h5_group_exists(uff_file, preferred)
        path = preferred;
        return
    end
end

list = uff.index(uff_file, '/', false);
for i = 1:numel(list)
    if ~isfield(list{i}, 'class') || ~isfield(list{i}, 'location')
        continue
    end
    if strcmp(list{i}.class, 'uff.channel_data')
        path = list{i}.location;
        return
    end
end
end

function ok = h5_group_exists(file, loc)
ok = false;
try
    h5info(file, loc);
    ok = true;
catch
    ok = false;
end
end
