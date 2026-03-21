classdef uff < handle
    %UFF   Base class for all Ultrasound File Format (UFF) data objects
    %
    %   UFF is the superclass for all data objects in the USTB. It provides
    %   common metadata properties (name, reference, author, version, info)
    %   and methods for reading from and writing to UFF files, which are
    %   based on the HDF5 file format.
    %
    %   Properties:
    %       name        name of the dataset
    %       reference   reference to the publication where it was used
    %       author      contact of the authors
    %       version     version of the dataset
    %       info        other information
    %
    %   Example:
    %       obj = uff();
    %
    %   See also UFF.CHANNEL_DATA, UFF.BEAMFORMED_DATA, UFF.PROBE, UFF.SCAN
    
    %   authors: Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>
    %
    %   $Last updated: 2017/08/07$
    
    %% Logistics parameters
    properties  (Access = public)
        name={}                         % name of the dataset
        reference={}                    % reference to the publication where it was used/acquired
        author={}                       % contact of the authors
        version={}                      % version of the dataset
        info={}                         % other information
    end
    
    %% Protected
    properties (Access = protected)
        last_hash
    end
    
    %% constructor
    methods (Access = public)
        function h=uff(varargin)
            %UFF   Constructor of UFF class
            %
            %   Syntax:
            %   h = uff(varaguin)
            %
            %   See also UFF.CHANNEL_DATA, UFF.BEAMFORMED_DATA

            if nargin==1 && ~isempty(varargin) 
                % copy
                h.copy(varargin{1});
            elseif nargin>1
                eval(['mco = ?' class(h) ';']);
                plist = mco.PropertyList;
                % varagin 
                for n=1:2:(2*floor(nargin/2))
                    found=false;
                    for m=1:length(plist)
                        if strcmp(plist(m).Name,varargin{n})
                            h.(plist(m).Name)=varargin{n+1};
                            found=true;
                            continue;
                        end
                    end
                    if ~found warning(sprintf('Parameter %s not in %s',varargin{n},class(h))); end
                end                
            end
        end
    end

    
    %% copy
    methods (Access = public)
        function copy(h,object)
            %COPY    Copy the values from another channel_data
            %
            %   Syntax:
            %   COPY(object)
            %       object       Instance of a channel_data class
            %
            %   See also SCAN, WAVE, SOURCE
            
            assert(isa(object,class(h)),'Class of the input object is not identical');
            
            % we copy all non-dependent & public properties
            list_properties=properties(object);
            for n=1:numel(list_properties)
                property_name=list_properties{n};
                mp = findprop(h,property_name);
                if strcmp(mp.GetAccess,'public')&&~mp.Dependent
                    eval(sprintf('h.%s = object.%s;',property_name,property_name));
                end
            end
        end
    end
    
    %% HASH tools
    methods
        function out = hash(h)
            % HASH Gives hash for all the non-dependent & public properties 
            
            % loop over all non-dependent & public properties
            str=[];
            list_properties=properties(h);
            for n=1:numel(list_properties)
                property_name=list_properties{n};
                mp = findprop(h,property_name);
                if strcmp(mp.GetAccess,'public')&&~mp.Dependent
                    %fprintf(1,'%s -> %s\n',property_name,tools.hash(h.(property_name)));
                    if isa(h.(property_name),'uff')
                        for ne=1:numel(h.(property_name))
                            str = [ str; h.(property_name)(ne).hash()];
                        end
                    elseif isa(h.(property_name),'uff.window')||isa(h.(property_name),'dimension')||isa(h.(property_name),'code')||isa(h.(property_name),'uff.wavefront')
                            str=[str;tools.hash(char(h.(property_name)))];
                    else
                        str=[str;tools.hash(h.(property_name))];
                    end
                end
            end
            
            out=tools.hash(str);
        end
        
        function h=save_hash(h)
            h.last_hash=h.hash();
        end
        
        function equal=check_hash(h)
            if isempty(h.last_hash) equal=false;
            else
                equal=strcmp(h.hash(),h.last_hash); 
                if equal 
                    fprintf('%s: Inputs and outputs are unchanged. Skipping process.\n',class(h)); 
                end
            end
        end
        
    end
    
    %% Public UFF file write/read
    methods (Access = public)
        function write(h, filename, name, location, verbose)
            %% WRITE  Writes object into location
            %
            %   This UFF method writes the object into the specified location
            %   with the provided name.
            %
            %   UFF_OBJECT.WRITE(filename,name,location,verbose)
            %
            %   Parameters:
            %       filename    Name and path to the UFF file
            %       name        Name of the object within the file
            %       location    Location within the UFF file
            %       verbose     Flag to get text messages
            %
            %   Example:
            %       channel_data = uff.channel_data();
            %       channel_data.write('test.uff');
            %
            %   See also UFF.READ, UFF.INDEX
            
            if nargin<3||isempty(name) name=evalin('caller','inputname(1)'); end
            if nargin<4 location=[]; end
            if nargin<5||isempty(verbose) verbose=true; end
            
            % we are good to write the object
            uff.write_object(filename, h, name, location, verbose);            
        end
        
         function read(h, filename, location, verbose)
            %% READ  Reads object from location
            %
            %   This UFF method read the UFF object from the specified location
            %   with the provided name. 
            %
            %   UFF_OBJECT.READ(filename, location, verbose)
            %
            %   Parameters:
            %       filename    Name and path to the UFF file
            %       location    Location within the UFF file
            %       verbose     Flag to get text messages
            %
            %   Example:
            %       channel_data = uff.channel_data();
            %       channel_data.read('test.uff','/channel_data');
            %
            %   See also UFF.WRITE, UFF.INDEX
            
            if nargin<4 verbose=true; end
            
            object=uff.read_object(filename, location, verbose);
            if numel(object)==1 h.copy(object); 
            else
                error('UFF: Trying to copy an array of objects into an UFF class. Use intead: a = uff().read(filename,location)');
            end
        end
    end
       
    %% display methods
    methods
        function print_authorship(h)
            out_name = textwrap([],h.name,50);
            fprintf('Name: \t\t %s \n',out_name{1});
            for i = 2:numel(out_name)
                fprintf('\t\t %s \n',out_name{i});
            end
            out_reference = textwrap([],h.reference,50);
            fprintf('Reference: \t %s \n',out_reference{1});
            for i = 2:numel(out_reference)
                fprintf('\t\t %s \n',out_reference{i});
            end
            fprintf('Author(s): ');
            for i = 1:numel(h.author)
                if i == 1
                    fprintf('\t %s \n',h.author{i});
                else
                    fprintf('\t\t %s \n',h.author{i});
                end
            end
            fprintf('Version: \t %s \n',h.version{:});
        end
    end
end