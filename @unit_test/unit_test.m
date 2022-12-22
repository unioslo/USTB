classdef unit_test 
%UNIT_TEST   UNIT_TEST definition
%
%   See also UNIT_TEST/UNIT_TEST

%   authors: Alfonso Rodriguez-Molares (alfonso.r.molares@ntnu.no)
%   $Date: 2017/03/09 $
    
    %% private properties
    properties  (Access = public)   
        external_tolerance=0.05;  % relative error to pass unit test against other beamformers (due to interpolation errors)
        internal_tolerance=0.01;  % relative error to pass unit test against our own beamformers
    end
    
    %% constructor
    methods (Access = public)
        function h=unit_test()
            %UNIT_TEST   Constructor of UNIT_TESTING class
            %
            %   Syntax:
            %   h = unit_test()
            %
            %   See also BEAM, PHANTOM, PROBE
        end
    end
    
    %% tests
    methods (Access = public)
        function ok=all(h)
            if ~isfolder(fullfile(ustb_path(), '/data', '/ps'))
                h.download_UT_data()
            end
            
            %ALL   Go through all tests
            allok=1;
            
            % create log file
            filename=[ustb_path() '/logs/log_' sprintf('%d',round(datevec(datetime))) '.txt'];
            fid = fopen(filename,'w');
            
            % who is running this?
            if ispc
                user=getenv('USERNAME');
                computer=getenv('COMPUTERNAME');
            elseif isunix
                user=getenv('USER');
                computer=getenv('HOSTNAME');
            end            
            line=sprintf('Alltest run on %s by %s at %s MATLAB=%s\n',datestr(datetime),user,computer,version);
            fprintf(1,line);
            fprintf(fid,line);            
            
            % read methods
            m=methods(h);
            
            % loop over methods
            for n=1:length(m)
                if m{n}(1)=='T'
                    
                    % launch test
                    a=[ 'ok=h.' m{n} '();'];
                    tic;
                    eval(a);
                    etime=toc;
                    
                    % report
                    allok=allok*ok;
                    line=sprintf('%s %d %0.3f',m{n},ok,etime);
                    if(ok)
                        line=[line ' ' repmat('.',[1 50-length(line)]) ' OK\n'];
                        fprintf(1,line);
                    else
                        line=[line ' ' repmat('.',[1 50-length(line)]) ' ERROR\n'];
                        fprintf(2,line);
                    end
                    fprintf(fid,line);
                end
            end
            
            % close log
            fid = fclose(fid);
            
            % not all tests passed? => we report the error
            if ~allok 
                error(['Not all test have passed. Check the ' filename]); 
            else
                fprintf('<strong>All tests OK!!</strong>\n');
            end
        end
        
        function download_UT_data(~)% data location
            url='https://www.ustb.no/datasets';   % if not found data will be downloaded from here           
            filename='ps.zip';
            data_path=fullfile(ustb_path(), 'data');
            
            % Downlad data if needed
            tools.download(filename, url, data_path);

            unzip(fullfile(data_path,filename), data_path)
            delete(fullfile(data_path,filename))
        end
    end
end