classdef midprocess < process
    %MIDPROCESS   Base class for beamforming (mid-processing) algorithms
    %
    %   MIDPROCESS performs the delay-and-sum operation that transforms
    %   channel data into beamformed image data. The output pixel grid is
    %   defined by a scan object.
    %
    %   Input:  uff.channel_data -> Output: uff.beamformed_data
    %
    %   Properties:
    %       channel_data            UFF.CHANNEL_DATA input
    %       scan                    UFF.SCAN defining the pixel grid
    %       receive_apodization     UFF.APODIZATION for receive weighting
    %       transmit_apodization    UFF.APODIZATION for transmit wave weighting
    %       beamformed_data         UFF.BEAMFORMED_DATA output
    %
    %   See also MIDPROCESS.DAS, PROCESS, PIPELINE, POSTPROCESS, PREPROCESS
    
    %   authors: Alfonso Rodriguez-Molares (alfonso.r.molares@ntnu.no)
    %            Ole Marius Hoel Rindal <olemarius@olemarius.net>
    %
    %   $Date: 2017/09/10$
    
    %% public properties
    properties  (Access = public)
        channel_data         % UFF.CHANNEL_DATA class
        scan                 % UFF.SCAN class
        receive_apodization  % APODIZATION class
        transmit_apodization % APODIZATION class
        beamformed_data      % UFF.BEAMFORMED_DATA class
    end
    
    %% constructor
    methods (Access = public)
        function h=midprocess()
            %midprocess   Constructor of process class
            %
            %   Syntax:
            %   h = midprocess()
            %
            %   See also BEAMFORMER, CHANNEL_DATA, BEAMFORMED_DATA
            
            h.channel_data=uff.channel_data();        % CHANNEL_DATA
            h.receive_apodization=uff.apodization();  % APODIZATION class
            h.transmit_apodization=uff.apodization(); % APODIZATION class
            h.scan=uff.scan();                        % SCAN class
            h.beamformed_data=uff.beamformed_data();  % BEAMFORMED_DATA class
            
        end
    end

    %% set methods
    methods
        function h=set.channel_data(h,in_channel_data)
            assert(isa(in_channel_data,'uff.channel_data'), 'The input is not a UFF.CHANNEL_DATA class. Check HELP UFF.CHANNEL_DATA.');
            h.channel_data=in_channel_data;
        end
        
        function h=set.scan(h,in_scan)
            assert(isa(in_scan,'uff.scan'), 'The input is not a UFF.SCAN class. Check HELP UFF.SCAN.');
            h.scan=in_scan;
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

