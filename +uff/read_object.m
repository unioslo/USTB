function object = read_object(filename, location, verbose)
%READ_OBJECT   Read a UFF object from an HDF5 file
%
%   Reads and reconstructs a USTB object stored at the given location
%   within a UFF (.uff / .h5) file.
%
%   object = uff.read_object(filename, location, verbose)
%
%   Parameters:
%       filename    path to the UFF file
%       location    HDF5 group path (default: '/')
%       verbose     display progress messages (default: true)
%
%   Example:
%       ch = uff.read_object('data.uff', '/channel_data');
%
%   See also UFF.WRITE_OBJECT, UFF.INDEX, UFF.VERSION

flag_v10X=false;
flag_v11X=false;

if nargin<2||isempty(location); location='/'; end
if nargin<3; verbose=true; end

% check if path to file exists
[pathstr,~] = fileparts(filename);
if ~exist(pathstr,'file')
    error('UFF: The path %s does not exist.', pathstr);
end

% check if file exists
if ~(exist(filename,'file')==2)
    error('UFF: The file %s does not exist.', filename);
end

% check if version matches
file_version=h5readatt(filename, '/', 'version');    % read file version
file_version=file_version{1};                       % from cell to string
file_version=file_version(int32(file_version)>0);   % removing 0's from 0-terminated strings
if ~strcmp(file_version, uff.version)
    % Flags to enable backcompatibility. 
    if strcmp(file_version, 'v1.0.0') || strcmp(file_version, 'v1.0.1')
        flag_v10X=true;
    elseif strcmp(file_version, 'v1.1.0') || strcmp(file_version, 'v1.1.1')
        flag_v11X=true;
    elseif strcmp(file_version, 'v1.2.0') 
        % current version
    else
        error('UFF: Unsupported file version (%s). Current UFF version (%s). Please choose a new file instead.',file_version,uff.version);
    end
end

% check if location exist
if isempty(uff.index(filename,location,false));
    error('UFF: The location does not exists');
end

% check if batch reading
if nargin<2 || strcmp(location,'/')
    % we read everything in the main location
    item=uff.index(filename,'/');
    if length(item); object={}; end
    for n=1:length(item)
        object{n}=uff.read_object(filename,item{n}.location,verbose);
    end
else
    
    % checking name and class
    try
        data_name=h5readatt(filename, location ,'name');
        class_name=h5readatt(filename, location ,'class');
    catch me
        if isempty(findstr(me.message,'can''t locate attribute:'))
            me.rethrow;
        else
            warning(['UFF: unnamed locations not supported. Skipping ' location '.']);
            object=[];
            return;
        end
    end
    
    switch class_name
        case {'double' 'single' 'int16'}
            if ~h5readatt(filename, location, 'complex')
                object=h5read(filename, location);
            else
                object=h5read(filename, [ location '/real' ])+...
                    1i*h5read(filename, [ location '/imag' ]);
            end
        case 'char'
            object=char(h5read(filename, location));
        case 'uff.window'
            object=uff.window(h5read(filename, location ));
        case 'uff.wavefront'
            object=uff.wavefront(h5read(filename, location ));
        case 'cell'
            data_size=h5readatt(filename, location ,'size');
            N=prod(data_size);
            if(N>0)
                item=uff.index(filename, location );
                if length(item)~=N error('Size attribute does not match number of subgroups'); end
                object={};
                for n=1:N
                    object{n}=uff.read_object(filename,item{n}.location,verbose);
                end
                reshape(object,data_size.');
            end
        otherwise
            % rest of UFF structures
            if (findstr('uff.',class_name))
                switch class_name
                    case {'uff.channel_data' 'uff.beamformed_data' 'uff.phantom'}
                        if verbose fprintf('UFF: reading %s [%s]\n',data_name,class_name); end
                end
                data_size=h5readatt(filename, location ,'size');
                N=prod(data_size);
                if(N>1)
                    item=uff.index(filename, location );
                    if length(item)~=N error('Size attribute does not match number of subgroups'); end
                    if verbose fprintf('UFF: reading %s [%s] ',data_name,class_name); end
                    previous_msg = '';
                    for n=1:N
                        object(n)=uff.read_object(filename,item{n}.location,verbose);
                        if verbose previous_msg = tools.text_progress_bar(100*n/N,previous_msg); end
                    end
                    if verbose fprintf('\n'); end
                    reshape(object,data_size.');
                else
                    object=feval(class_name);
                    
                    % add properties
                    prop=uff.index(filename, location);
                    for m=1:length(prop)
                        % exceptions from backcompatibility
                        if flag_v10X&&strcmp(class_name,'uff.apodization')&&strcmp(prop{m}.name,'apex')
                            object.('origin')=uff.read_object(filename,prop{m}.location,verbose);                        
                        elseif flag_v10X&&strcmp(class_name,'uff.apodization')&&strcmp(prop{m}.name,'scan')
                            object.('focus')=uff.read_object(filename,prop{m}.location,verbose);                        
                        elseif flag_v11X&&strcmp(class_name,'uff.apodization')&&strcmp(prop{m}.name,'origo')
                            object.('origin')=uff.read_object(filename,prop{m}.location,verbose);  
                        elseif strcmp(class_name,'uff.sector_scan')&&strcmp(prop{m}.name,'apex')
                            object.('origin')=uff.read_object(filename,prop{m}.location,verbose);
                        else
                            object.(prop{m}.name)=uff.read_object(filename,prop{m}.location,verbose);
                        end
                    end
                end
            else
                warning('UFF:UnsupportedClass', 'Class %s not supported by UFF; skipping write.', class(value));
                object=[];
            end
    end
end

