classdef postprocess < process
    %POSTPROCESS   Base class for post-processing algorithms
    %
    %   POSTPROCESS modifies beamformed data. This includes adaptive
    %   beamforming techniques (e.g. Coherence Factor, Minimum Variance),
    %   compounding, filtering, and image enhancement.
    %
    %   Input:  uff.beamformed_data -> Output: uff.beamformed_data
    %
    %   Properties:
    %       input                   UFF.BEAMFORMED_DATA input
    %       output                  UFF.BEAMFORMED_DATA output
    %       receive_apodization     UFF.APODIZATION for receive weighting
    %       transmit_apodization    UFF.APODIZATION for transmit wave weighting
    %
    %   See also PROCESS, PIPELINE, MIDPROCESS, PREPROCESS
    
    %   authors: Alfonso Rodriguez-Molares (alfonso.r.molares@ntnu.no)
    %            Ole Marius Hoel Rindal <olemarius@olemarius.net>
    %
    %   $Date: 2017/09/10$
    
    %% public properties
    properties  (Access = public)
        input                % UFF.BEAMFORMED_DATA class
        output               % UFF.BEAMFORMED_DATA class
    end
    
    %% Additional properties
    properties
        receive_apodization                           % APODIZATION class
        transmit_apodization                          % APODIZATION class
    end
    
    %% set methods
    methods
        function h=set.input(h,in_beamformed_data)
            assert(isa(in_beamformed_data,'uff.beamformed_data'), 'The input is not a UFF.BEAMFORMED_DATA class. Check HELP UFF.BEAMFORMED_DATA.');
            h.input=in_beamformed_data;
        end
        function h=set.receive_apodization(h,in_apodization)
            assert(isa(in_apodization,'uff.apodization'), 'The input is not a UFF.APODIZATION class. Check HELP UFF.APODIZATION.');
            h.receive_apodization=in_apodization;
        end
        
        function h=set.transmit_apodization(h,in_apodization)
            assert(isa(in_apodization,'uff.apodization'), 'The input is not a UFF.APODIZATION class. Check HELP UFF.APODIZATION.');
            h.transmit_apodization=in_apodization;
        end
    end
end

