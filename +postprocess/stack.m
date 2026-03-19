classdef stack < postprocess
%STACK   Scanline stacking for multi-angle beamformed data
%
%   Stacks scanlines from multiple transmit angles into a single
%   extended image. Supports linear and sector scans.
%
%   Input:  uff.beamformed_data -> Output: uff.beamformed_data
%
%   Example:
%       obj = postprocess.stack();
%
%   See also POSTPROCESS, MAX, UFF.LINEAR_SCAN, UFF.SECTOR_SCAN
%
%   authors: Alfonso Rodriguez-Molares (alfonso.r.molares@ntnu.no)
%            Ole Marius Hoel Rindal <olemarius@olemarius.net>
%
%   $Last updated: 2017/09/10$

        
    %% constructor
    methods (Access = public)
        function h=stack()
            h.name='Stack scanlines MATLAB';          % name of the process
            h.reference='www.ustb.no';                % reference to the publication where it is disclossed
            h.implemented_by={'Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>','Ole Marius Hoel Rindal <olemarius@olemarius.net>'};    
            h.version='v1.0.2';     
        end
    end
    
    methods
        function output = go(h)
            % check if we can skip calculation
            if h.check_hash()
                output= h.output; 
                return;
            end
            
            % check input
            assert(isa(h.input(1).scan,'uff.linear_scan')||isa(h.input(1).scan,'uff.sector_scan'),'Stack only works with LINEAR_SCAN and SECTOR_SCAN');
            [N_pixels Nrx Ntx N_frames]=size(h.input.data);
            N=Nrx*Ntx;
            tools.workbar();
            switch class(h.input(1).scan)
                case 'uff.linear_scan'
                    % declare
                    h.output=uff.beamformed_data(h.input);     % ToDo: shouldn't copy the data
                    h.output.data=zeros(N_pixels*Ntx,Nrx,1,N_frames);
    
                    % loop over scans
                    depth_axis=h.input.scan(1).z;
                    azimuth_axis=[];
                    for ntx=1:Ntx
                        tools.workbar(ntx/Ntx,sprintf('%s (%s)',h.name,h.version),'USTB');
                        azimuth_axis=[azimuth_axis h.input.scan(ntx).x_axis];
                        h.output.data((1:N_pixels)+N_pixels*(ntx-1),:,1,:)=h.input.data(:,:,ntx,:);
                    end
                    h.output.scan=uff.linear_scan('x_axis',azimuth_axis.','z_axis',depth_axis);
                case 'uff.sector_scan'
                    h.output=uff.beamformed_data(h.input); % ToDo: shouldn't copy the data
                    h.output.data=zeros(N_pixels*Ntx,Nrx,1,N_frames);
    
                    % loop over scans
                    depth_axis=h.input.scan(1).depth_axis;
                    azimuth_axis=[];
                    for ntx=1:Ntx
                        tools.workbar(ntx/Ntx,sprintf('%s (%s)',h.name,h.version),'USTB');
                        azimuth_axis=[azimuth_axis h.input.scan(ntx).azimuth_axis];
                        h.output.data((1:N_pixels)+N_pixels*(ntx-1),:,1,:)=h.input.data(:,:,ntx,:);
                    end
                    h.output.scan=uff.sector_scan('azimuth_axis',azimuth_axis.','depth_axis',depth_axis);
                    
            end
            tools.workbar(1);
            
            % pass reference
            output = h.output;
            
            % update hash
            h.save_hash();

        end
    end
end