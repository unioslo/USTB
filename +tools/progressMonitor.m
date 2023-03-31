classdef progressMonitor < matlab.net.http.ProgressMonitor
    properties
        Direction matlab.net.http.MessageType % Direction. Download or Upload
        Value uint64 % Total number of transferred bytes
        clearMsg
    end
    
    methods
        % Class constructor
        function obj = progressMonitor
            obj.Interval = 1;
            obj.clearMsg = '';
        end
        
        % Function that is called once transfer is complete or halted
        function done(obj)
            
            % This checks avoids the completion message to be shown twice.
            % Checking that obj.Value is empty ensures that the compleation
            % message is not shown when getting the "download warning" from
            % the server
            if ~obj.InUse && ~isempty(obj.Value)
                fprintf(1, '...done!\n');
            end
        end
    end
    
    % SET methods
    methods
        function set.Direction(obj, dir)
            obj.Direction = dir;
        end
        
        function set.Value(obj, value)
            obj.Value = value;
            obj.fprintf();
        end
    end
    
    methods
        function fprintf(obj)
            if  obj.Direction == matlab.net.http.MessageType.Response
                if isempty(obj.Max)
                    msg = sprintf('Downloading %d MB', obj.Value/1e6);
                else
                    msg = sprintf('Downloading %d / %d MB', ...
                        obj.Value/1e6, obj.Max/1e6);
                end
            else
                if isempty(obj.Max)
                    msg = sprintf('Uploading %d MB', obj.Value/1e6);
                else
                    msg = sprintf('Uploading %d / %d MB', ...
                        obj.Value/1e6, obj.Max/1e6);
                end
            end
            
            fprintf(1, strcat(obj.clearMsg, msg));
            obj.clearMsg = repmat('\b', size(msg));
        end
    end
end