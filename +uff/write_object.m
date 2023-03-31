function dumped_objects = write_object(filename,object,name,location,verbose)
%% WRITE_OBJECT  Writes object into location
%
%   This UFF method writes the object provided into the specified location
%   of a UFF file.
%
%   WRITE_OBJECT(filename, object, name, location, verbose)
%
%   Parameters:
%       filename    Name and path to the UFF file
%       object      Object to be written into the UFF file
%       name        Name of the object within the file
%       location    Location within the UFF file
%       verbose     Flag to get text messages
%
%   Example:
%       chdat = uff.channel_data();
%       uff.write_object('test.uff',chdat,'channel_data');
%
%   See also UFF.WRITE, UFF.INDEX

if(nargin<1)||isempty(filename) error('Missing UFF filename'); end
if(nargin<2)||isempty(object) error('Missing object to write in UFF file'); end
if(nargin<3)||isempty(name) error('Missing name for the HDF5 group'); end
if(nargin<4) location=[]; end
if nargin<5||isempty(verbose) verbose=true; end

% check if path to file exists
[pathstr,~] = fileparts(filename);
if ~exist(pathstr,'file')
    error(sprintf('UFF: The path %s does not exist. If you want to save in current working directory use ./ in front of the filname.',pathstr));
end

% if file doesn't exist -> we write the current version
if ~(exist(filename,'file')==2)
    if verbose fprintf('UFF: creating file %s\n',filename); end
    attr_details.Name = 'version';
    attr_details.AttachedTo = '/';
    attr_details.AttachType = 'group';
    hdf5write(filename, attr_details, uff.version);
end

% check if version matches
file_version=h5readatt(filename, '/','version');    % read file version
file_version=file_version{1};                       % from cell to string
file_version=file_version(int32(file_version)>0);   % removing 0's from 0-terminated strings
if ~strcmp(file_version, uff.version)
    error(sprintf('UFF: Unsupported file version (%s). Current UFF version (%s). The file you want to write to is obsolete, create a new file instead.',file_version,uff.version));
end

% check if location exist
if ~isempty(uff.index(filename,[location '/' name],false));
    choice = tools.dialog_timeout(5,sprintf('UFF: %s already exists in the file. Overwrite? (y/n)',[location '/' name]), ...
        'USTB', ...
        'Yes','No','No');
    if ~strcmp(choice,'Yes')
        fprintf(1,'%s not written\n',name);
        return;
    else
        fid = H5F.open(filename,'H5F_ACC_RDWR','H5P_DEFAULT');
        H5L.delete(fid,[location '/' name],'H5P_DEFAULT');
        H5F.close(fid);
    end
end

switch class(object)
    case {'double' 'single' 'int16'}
        sz=size(object);
        if isreal(object)
            sz=size(object);
            h5create(filename,[location '/' name], size(object), 'Datatype', 'single');
            h5write(filename,[location '/' name], single(object));
            h5writeatt(filename,[location '/' name],'class',class(object));
            h5writeatt(filename,[location '/' name],'name',name);
            h5writeatt(filename,[location '/' name],'imaginary',0);
            h5writeatt(filename,[location '/' name],'complex',0);
            dumped_objects=1;
        else
            % real
            h5create(filename,[location '/' name '/real'], size(object), 'Datatype', 'single');
            h5write(filename,[location '/' name '/real'], single(real(object)));
            h5writeatt(filename,[location '/' name '/real'],'class',class(object));
            h5writeatt(filename,[location '/' name '/real'],'name',name);
            h5writeatt(filename,[location '/' name '/real'],'imaginary',0);
            
            % imag
            h5create(filename,[location '/' name '/imag'], size(object), 'Datatype', 'single');
            h5write(filename,[location '/' name '/imag'], single(imag(object)));
            h5writeatt(filename,[location '/' name '/imag'],'class',class(object));
            h5writeatt(filename,[location '/' name '/imag'],'name',name);
            h5writeatt(filename,[location '/' name '/imag'],'imaginary',1);
            
            % group attributes
            h5writeatt(filename,[location '/' name],'class',class(object));
            h5writeatt(filename,[location '/' name],'name',name);
            h5writeatt(filename,[location '/' name],'complex',1);
            dumped_objects=1;
        end
    case 'char'
        h5create(filename,[location '/' name], size(object), 'Datatype', 'single');
        h5write(filename,[location '/' name], uint16(object));
        h5writeatt(filename,[location '/' name],'class',class(object));
        h5writeatt(filename,[location '/' name],'name',name);
        dumped_objects=1;
    case 'uff.window'
        h5create(filename,[location '/' name], size(object), 'Datatype', 'single');
        h5write(filename,[location '/' name], single(object));
        h5writeatt(filename,[location '/' name],'class',class(object));
        h5writeatt(filename,[location '/' name],'name',name);
        dumped_objects=1;
    case 'cell'
        % call write for all members in the cell
        dumped_objects=0;
        for n=1:numel(object)
            dumped_objects=dumped_objects+uff.write_object(filename,object{n}, [name '_' sprintf('%04d',n)],[location '/' name], verbose);
        end
        
        % group attributes
        if dumped_objects
            h5writeatt(filename,[location '/' name],'class',class(object));
            h5writeatt(filename,[location '/' name],'name',name);
            h5writeatt(filename,[location '/' name],'array',1);
            h5writeatt(filename,[location '/' name],'size',size(object));
        end
    otherwise
        % UFF structures
        if (findstr('uff.',class(object)))
            if numel(object)>1
                
                if verbose fprintf('UFF: writing %s [%s] at %s ',name,class(object),location); end
                % call write for all members in the array
                dumped_objects=0;
                previous_msg='';
                for n=1:numel(object)
                    dumped_objects=dumped_objects+uff.write_object(filename,object(n), [name '_' sprintf('%04d',n)],[location '/' name],verbose);
                    if verbose previous_msg = tools.text_progress_bar(100*n/numel(object),previous_msg); end
                end
                if verbose fprintf('\n'); end
                
                % group attributes
                if dumped_objects
                    h5writeatt(filename,[location '/' name],'class',class(object));
                    h5writeatt(filename,[location '/' name],'name',name);
                    h5writeatt(filename,[location '/' name],'array',1);
                    h5writeatt(filename,[location '/' name],'size',size(object));
                end
            else
                % here we process non-array UFF structures
                switch class(object)
                    case {'uff.channel_data' 'uff.beamformed_data' 'uff.phantom'}
                        if verbose
                            if isempty(location)
                                fprintf('UFF: writing %s [%s] at %s\n',name,class(object),'/');
                            else
                                fprintf('UFF: writing %s [%s] at %s\n',name,class(object),location);
                            end
                        end
                end
                
                % dump all fields in struct (or properties in class)
                dumped_objects=0;
                field_list = fieldnames(object);
                eval(['mco = ?' class(object) ';']);
                plist = mco.PropertyList;
                for f=1:length(field_list)
                    
                    % check if the property is dependent
                    copy=false;
                    for p=1:length(plist)
                        if strcmp(plist(p).Name,field_list{f})
                            copy=~plist(p).Dependent;
                            continue;
                        end
                    end
                    
                    % if it isn't dependent or empty we write it
                    if copy
                        prop=object.(field_list{f});
                        if numel(prop)
                            uff.write_object(filename, prop, field_list{f}, [location '/' name], verbose);
                            dumped_objects=dumped_objects+1;
                        end
                    end
                end
                
                if dumped_objects>0
                    h5writeatt(filename,[location '/' name],'class',class(object));
                    h5writeatt(filename,[location '/' name],'name',name);
                    h5writeatt(filename,[location '/' name],'size',size(object));
                    h5writeatt(filename,[location '/' name],'array',0);
                end
            end
        else warning(sprintf('Class %s not supported by UFF; skipping write.',class(object))); end
end
