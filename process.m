classdef process < handle
    %PROCESS   process part of the beamforming chain
    %
    %   See also PIPELINE, CHANNEL_DATA, BEAMFORMED_DATA
    
    %   authors: Alfonso Rodriguez-Molares (alfonso.r.molares@ntnu.no)
    %            Ole Marius Hoel Rindal <olemarius@olemarius.net>
    %
    %   $Date: 2017/09/10$
    
    %% Logistics
    properties  (Access = public)
        name=''              % name of the process
        reference=''         % reference to the publication where it is disclossed
        implemented_by=''    % contact of the implementer/s
        version=''           % verion
    end
    
    %% Protected
    properties (Access = protected)
        last_hash
    end
    
    %% HASH tools
    methods
        function out = hash(h)
            %% HASH Gives hash for all the non-dependent & public properties 
            
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
                    elseif isa(h.(property_name),'uff.window')||isa(h.(property_name),'dimension')||isa(h.(property_name),'code')||isa(h.(property_name),'spherical_transmit_delay_model')
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
                    warning('Inputs and outputs are unchanged. Skipping process...'); 
                end
            end
        end
        
    end
    
    %% Display methods
    methods
        function print_name(h)
            idx = 1;
            while idx+50 < length(h.name)
                if idx < 50
                    fprintf('Name:\t\t %s \n',h.name(idx:idx+49));
                else
                    fprintf('\t\t %s \n',h.name(idx:idx+49));
                end
                idx = idx+50;
            end
            if idx < 50
                fprintf('Name:\t\t %s \n',h.name(idx:end));
            else
                fprintf('\t\t %s \n',h.name(idx:end));
            end
        end
        
        function print_reference(h)
            idx = 1;
            while idx+50 < length(h.reference)
                if idx < 50
                    fprintf('Reference:\t %s \n',h.reference(idx:idx+49));
                else
                    fprintf('\t\t %s \n',h.reference(idx:idx+49));
                end
                idx = idx+50;
            end
            if idx < 50
                fprintf('Name:\t %s \n',h.reference(idx:end));
            else
                fprintf('\t\t %s \n',h.reference(idx:end));
            end
        end
        
        function print_implemented_by(h)
            idx = 1;
            while idx+50 < length(h.implemented_by)
                if idx < 50
                    fprintf('Implemented by:\t %s \n',h.implemented_by(idx:idx+49));
                else
                    fprintf('\t\t %s \n',h.implemented_by(idx:idx+49));
                end
                idx = idx+50;
            end
            if idx < 50
                fprintf('Name:\t %s \n',h.implemented_by(idx:end));
            else
                fprintf('\t\t %s \n',h.implemented_by(idx:end));
            end
        end
    end
    
end

