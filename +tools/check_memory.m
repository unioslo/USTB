function check_memory(bytes)
%CHECK_MEMORY   Check that enough RAM is available for an allocation
%
%   tools.check_memory(bytes)
%
%   See also TOOLS.GETAVAILABLEMEMORY

if ispc %The memory check is only available on windows
    [user,sys] = memory;

    safety_factor = 0.3;

    assert(sys.PhysicalMemory.Available>(1 + safety_factor)*bytes,'Not available RAM for the new data. Aborting process.');
end
end
