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
%       url = [tools.zenodo_dataset_files_base() '/ARFI_dataset.uff'];
%       file = fullfile(ustb_path(), 'data', 'ARFI_dataset.uff');
%       tools.download(file, url)

[path, name, ext] = fileparts(file);

% Undocumented optional third argument that ensures backward compatibility 
% with old examples
if nargin > 2 
    path = local_path;  % The third argument used to be the path
    % Strip trailing slash from base URL so we do not produce .../datasets//file.uff
    % (some servers return 404 for the double slash, e.g. GitHub Actions).
    base = url;
    while ~isempty(base) && base(end) == '/'
        base = base(1:end-1);
    end
    url = [base, '/', file]; % The URL now needs to include the file name
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
    
    % Create folder if it does not exist (again, in case path changed)
    if ~exist(path, 'dir')
        mkdir(path)
    end

    % Use websave for standard HTTPS downloads (Zenodo, ustb.no, etc.)
    % The legacy matlab.net.http path is kept only for Google Drive confirm flows.
    if contains(url, 'drive.google.com')
        download_google_drive(file, url);
    else
        webopts = weboptions('Timeout', 300);
        try
            websave(file, url, webopts);
        catch ME
            % websave may fail on servers returning duplicate Content-Type
            % headers; fall back to urlwrite (deprecated but resilient).
            try
                urlwrite(url, file); %#ok<URLWR>
            catch ME2
                error('tools:download:failed', ...
                    'Download failed.\n  websave: %s\n  urlwrite: %s', ...
                    ME.message, ME2.message);
            end
        end
    end
end
end

function download_google_drive(file, url)
%DOWNLOAD_GOOGLE_DRIVE  Handle Google Drive confirm-download flow.
opts = matlab.net.http.HTTPOptions('ProgressMonitorFcn', ...
    @tools.progressMonitor, 'UseProgressMonitor', true);

response = send(matlab.net.http.RequestMessage(), url, opts);

if response.StatusCode == 200
    if isempty(response.Body.ContentType) || ...
            strcmp(response.Body.ContentType.Type, 'application')
        fid = fopen(file, 'w');
        fwrite(fid, response.Body.Data);
        fclose(fid);
    elseif strcmp(response.Body.ContentType.Type, 'text')
        request = matlab.net.http.RequestMessage();
        setCookie = response.getFields('Set-Cookie');
        cookieInfo = setCookie.convert();
        key = '';
        for cookie = [cookieInfo.Cookie]
            if startsWith(cookie.Name, 'download_warning')
                key = cookie.Value;
                request = addFields(request, 'Cookie', ...
                    matlab.net.http.Cookie(cookie.Name, cookie.Value));
            end
        end
        response = send(request, strcat(url, '&confirm=', key), opts);
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