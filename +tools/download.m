function download(file, url, local_path)
%DOWNLOAD download a dataset from specified URL.
%   download(FILE, URL) checks if the specified file is missing and 
%   downlods it from URL. The input argument FILE is a string that contains
%   the absolute path to the file.
% 
%   This function supports downloading large files from Google drive.
%   In order to download a dataset from Google drive, URL must be provided as
%   URL = https://drive.google.com/uc?export=download&id=ID' where ID is
%   the file id
%
%   Example:
%       url = 'http://ustb.no/datasets/ARFI_dataset.uff';
%       file = fullfile(ustb_path(), 'data', 'ARFI_dataset.uff');
%       tools.download(file, url)

[path, name, ext] = fileparts(file);

% Undocumented optional third argument that ensures backward compatibility 
% with old examples
if nargin > 2 
    path = local_path;  % The third argument used to be the path
    url = [url, '/', file]; % The URL now needs to include the file name
    file = fullfile(path, [name, ext]); % The file need to have the full path 
                                        % to be saved correctly later
end

% Check that the file has not been downloaded previously
if ~exist(file,  'file')
    
    fprintf(1, 'USTB download tool\n')
    msg = textwrap({strcat(name, ext)}, 50);
    fprintf('File:\t\t%s\n', msg{1});
    for i = 2:numel(msg)
        fprintf('\t\t\t%s\n', msg{i});
    end
    msg = textwrap({url}, 50);
    fprintf('URL:\t\t%s\n', msg{1});
    for i = 2:numel(msg)
        fprintf('\t\t\t%s\n', msg{i});
    end
    msg = textwrap({path}, 50);
    fprintf('Path:\t\t%s\n', msg{1});
    for i = 2:numel(msg)
        fprintf('\t\t\t%s\n', msg{i});
    end
    
    % Create folder if it does not exist
    if ~exist(path, 'dir')
        mkdir(path)
    end
    
    % Prepare a HTTP option object were we specify to use a custom progress
    % monitor, which informs the user about the amount of downloaded data
    opts = matlab.net.http.HTTPOptions('ProgressMonitorFcn', ...
        @tools.progressMonitor, 'UseProgressMonitor',true);
    
    % We send a first GET request
    response = send(matlab.net.http.RequestMessage(), url, opts);
    
    % First, we check that the response from the server was OK
    if response.StatusCode == 200
        
        % If the content of the first response is of type 'application-
        % octet-stream' or is not specified, it means that we have already
        % downloaded the file in the first request. NOTE: the order in
        % which the two clauses are checked is important
        if isempty(response.Body.ContentType) || ...
                strcmp(response.Body.ContentType.Type, 'application')
            
            % We just need to save the file
            fid = fopen(file, 'w');
            fwrite(fid, response.Body.Data);
            fclose(fid);
            
        % If the content of the first response is of type 'text-html', it
        % means that the file was large enough to trigger the warning
        % download message in Google drive. Therefore, we need to send a 
        % confirm request to begin the download
        elseif strcmp(response.Body.ContentType.Type, 'text')        
            
            % First, we prepare a second GET request, which will start the file
            % download
            request = matlab.net.http.RequestMessage();
            
            % Then we extract the cookies from the response
            setCookie = response.getFields('Set-Cookie');
            cookieInfo = setCookie.convert();
            
            % We look for the cookie whose field starts with "download warning"
            for cookie = [cookieInfo.Cookie]
                
                if startsWith(cookie.Name, 'download_warning')
                    
                    key = cookie.Value;
                    request = addFields(request, 'Cookie', ...
                        matlab.net.http.Cookie(cookie.Name, cookie.Value));
                end
            end
            
            % We send the second GET request and begin the file download
            response = send(request, strcat(url, '&confirm=', key), opts);
            
            % We save the file
            fid = fopen(file, 'w');
            fwrite(fid, response.Body.Data);
            fclose(fid);
        else
            error('Unknown content type!');
        end
        
    else
        error('The HTTP request failed with error %d', response.StatusCode);
    end
end
end