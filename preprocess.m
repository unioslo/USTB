classdef preprocess < process
    %PREPROCESS   preprocess part of the prcessing pipeline. Takes a
    % uff.channel_data structure and return another uff.channel_data
    %
    %   See also PROCESS, CHANNEL_DATA, BEAMFORMED_DATA
    
    %   authors: Alfonso Rodriguez-Molares (alfonso.r.molares@ntnu.no)
    %            Ole Marius Hoel Rindal <olemarius@olemarius.net>
    %
    %   $Date: 2017/09/10$
    
    %% public properties
    properties  (Access = public)
        input                % CHANNEL_DATA class
        output               % CHANNEL_DATA class
    end
    
    %% set methods
    methods
        function set.input(h, val)
            validateattributes(val, {'uff.channel_data'}, {'scalar'})
            h.input = val;
        end
        function set.output(h, val)
            validateattributes(val, {'uff.channel_data'}, {'scalar'})
            h.output = val;
        end
    end
end

