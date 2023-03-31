classdef pipeline < process
%pipeline   pipeline definition
%
%   See also PROCESS, BEAM, PHANTOM, PROBE

%   authors: Alfonso Rodriguez-Molares (alfonso.r.molares@ntnu.no)
%            Ole Marius Hoel Rindal <olemarius@olemarius.net>
%
%   $Last updated: 2017/09/15$

    %% public properties
    properties  (Access = public)
        channel_data         % CHANNEL_DATA class
        receive_apodization  % APODIZATION class
        transmit_apodization % APODIZATION class
        scan                 % collection of SCAN classes
    end
    
    %% optional properties
    properties  (Access = public)
        pulse                % PULSE class
    end
    
    %% constructor
    methods (Access = public)
        function h=pipeline(pipe)
            %beamformer   Constructor of beamformer class
            %
            %   Syntax:
            %   h = beamformer()
            %
            %   See also BEAM, PHANTOM, PROBE, PULSE                      
            
            h.receive_apodization=uff.apodization();  % APODIZATION class
            h.transmit_apodization=uff.apodization(); % APODIZATION class
            
            % If called with another beamformer object as parameter
            % copy the properties
            if nargin > 0 && ~isempty(pipe)
                h.channel_data = pipe.channel_data;
                h.receive_apodization = pipe.receive_apodization;
                h.transmit_apodization = pipe.transmit_apodization;
                h.scan = pipe.scan;
            end
        end
    end
    
    %% go method
    methods 
        function output = go(h,process_list)
            % default case: no processors are defined
            if nargin == 1
               midproc=midprocess.das_matlab();
               
               % input data
               midproc.channel_data=h.channel_data;
               midproc.receive_apodization=h.receive_apodization;
               midproc.transmit_apodization=h.transmit_apodization;
               midproc.scan=h.scan;
               
               % logistics
               h.name = midproc.name;
               h.reference = midproc.reference;
               h.implemented_by = midproc.implemented_by;
               h.version = midproc.version;
               
               % go method
               output = midproc.go();
            else
               if isa(process_list{1},'preprocess') 
                    process_list{1}.input=h.channel_data;
               elseif  isa(process_list{1},'midprocess')
                    process_list{1}.channel_data=h.channel_data;
                    process_list{1}.receive_apodization=h.receive_apodization;
                    process_list{1}.transmit_apodization=h.transmit_apodization;
                    process_list{1}.scan=h.scan;
               else
                    error('The first process in the pipeline must be either a preprocess or a midprocess');
               end
                   
               % authorship
               h.name{1} = process_list{1}.name;
               h.reference{1} = process_list{1}.reference;
               h.implemented_by = process_list{1}.implemented_by;
               h.version{1} = process_list{1}.version;
               
               % go first process
               output = process_list{1}.go();
               
               % rest of processes
               for n=2:length(process_list)
               if isa(process_list{n},'preprocess')
                    if isa(process_list{n-1},'preprocess') 
                        process_list{n}.input=output;
                    else
                        error(sprintf('Only a preprocess can go before a preprocess: %s -> %s',class(process_list{n-1}),class(process_list{n})));
                    end
               elseif isa(process_list{n},'midprocess')
                    if isa(process_list{n-1},'preprocess') 
                        process_list{n}.channel_data=output;
                        process_list{n}.receive_apodization=h.receive_apodization;
                        process_list{n}.transmit_apodization=h.transmit_apodization;
                        process_list{n}.scan=h.scan;
                    else
                        error(sprintf('Only a preprocess can go befor a midprocess: %s -> %s',class(process_list{n-1}),class(process_list{n})));
                    end
               elseif isa(process_list{n},'postprocess')
                    if ~isa(process_list{n-1},'preprocess')
                        process_list{n}.input=output;
                        process_list{n}.receive_apodization=h.receive_apodization;
                        process_list{n}.transmit_apodization=h.transmit_apodization;
                    else
                        error(sprintf('Found postprocess after preprocess: %s -> %s',class(process_list{n-1}),class(process_list{n})));
                    end
               else
                    error('Unknown process type');
               end
                   
                   % concatenate logistics
                   h.name = [h.name process_list{n}.name];
                   h.reference = [h.reference process_list{n}.reference];
                   h.implemented_by = [h.implemented_by process_list{n}.implemented_by];
                   h.version = [h.version process_list{n}.version];
                   
                   % go method
                   output = process_list{n}.go();
               end
            end               
        end
    end
    
    %% set methods
    methods  
        function h=set.receive_apodization(h,in_apodization)
            assert(isa(in_apodization,'uff.apodization'), 'The input is not a APODIZATION class. Check HELP APODIZATION.');
            h.receive_apodization=in_apodization;
        end        
        function h=set.transmit_apodization(h,in_apodization)
            assert(isa(in_apodization,'uff.apodization'), 'The input is not a APODIZATION class. Check HELP APODIZATION.');
            h.transmit_apodization=in_apodization;
        end           
        function h=set.channel_data(h,in_channel_data)
            assert(isa(in_channel_data,'uff.channel_data'), 'The input is not a CHANNEL_DATA class. Check HELP CHANNEL_DATA.');
            h.channel_data=in_channel_data;
        end   
    end
    
    
end