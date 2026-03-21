classdef preprocess < process
    %PREPROCESS   Base class for pre-processing algorithms
    %
    %   PREPROCESS modifies channel data before beamforming. Typical
    %   operations include demodulation of RF data to produce IQ data
    %   and refocusing.
    %
    %   Input:  uff.channel_data -> Output: uff.channel_data
    %
    %   Properties:
    %       input    UFF.CHANNEL_DATA input
    %       output   UFF.CHANNEL_DATA output
    %
    %   See also PROCESS, PIPELINE, MIDPROCESS, POSTPROCESS
    
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

