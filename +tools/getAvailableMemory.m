function val = getAvailableMemory
%GETAVAILABLEMEMORY   Return available physical memory in bytes
%
%   val = tools.getAvailableMemory()
%
%   See also TOOLS.CHECK_MEMORY
if isunix
    [~, val] = system('grep MemAvailable /proc/meminfo');
    val = sscanf(val, 'MemAvailable:   %d kB');
    val = val*1e3;
elseif ispc
    [~, sys] = memory;
    val = sys.PhysicalMemory.Available;
else
    disp('Platform not supported')
end
end