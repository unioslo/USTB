classdef verasonics < handle
    %Verasonics  Class for reading Verasonics research scanner data to USTB
    
    %   authors:    Ole Marius Hoel Rindal <olemarius@olemarius.net>
    %               Alfonso Rodriques-Morales <alfonso.r.molares@ntnu.no>
    %
    %   $Date: 2017/03/16$
    
    properties (Access = public)
        % Verasonics objects and structs
        Trans                  % Verasonics Transducer object
        TW                     % Verasonics Transmit Waveform object
        RcvData                % Verasonics Receive Data buffer, the channeldata
        Resource               % Verasonics Resource object, a few global parameters
        Receive                % Verasonics Receive object, defining receive parameters
        TX                     % Verasonics TX object, defining transmit parameters

        
        % Some helpful parameters
        number_of_frames       % The desired number of frames wanted
        frame_order            % The order of the frame in RcvData
        
        % For CPW
        angles                 % The transmit angles of the planewaves in radians, or for pha the transmit beam angles
        
        % For "superframes" used for Share Wave Elastography
        frames_in_superframe
        number_of_superframes
        %
    end
    
    properties (Dependent) 
        Fs                     % The sampling frequency in Hz
        f0                     % The center frequency in Hz    
        c0                     % The speed of sound in m/s
        lambda                 % The wavelength in m
    end
    %% Constructor
    methods (Access = public)
        function h = verasonics()
            %empty constructor
        end
    end
    
    %% Set methods
    
    methods
        function set.Trans(h,Trans)
            assert(strcmp(Trans.units,'mm'),'Please use mm as units in Verasonics.');
            h.Trans = Trans;
        end
        
        function set.Receive(h,Receive)
            h.Receive = Receive; 
            if isfield(Receive,'aperture') == 0 % Then this is a no-mux probe and we set this to one
                h.Receive(1).aperture = 1;
            end
        end
        
        function set.Resource(h,Resource)
            h.Resource = Resource;
        end
        
        function set.TW(h,TW)
            h.TW=TW;    
        end
        
        function Fs = get.Fs(h)
            assert(isempty(h.Receive)==0,'To get Fs Receive needs to be set.');
            Fs = h.f0*h.Receive(1).samplesPerWave;
        end
        
        function f0 = get.f0(h)
            assert(isempty(h.TW)==0,'To get f0 TW need to be set.');
            f0 = double(h.TW.Parameters(1)*1e6);
        end
        
        function lambda = get.lambda(h)
            lambda = h.c0/h.f0;
        end
        
        function c0 = get.c0(h)
            assert(isempty(h.TW)==0,'To get c0 Resource need to be set.');
            c0 = h.Resource.Parameters.speedOfSound;
        end
        
        function frame_order = get.frame_order(h)
            % The order of the frames in the RcvBuffer is not necesarrily
            % in order. We need to check which one was the "last frame"
            if isfield(h.Resource.RcvBuffer,'lastFrame')
                frame_order = [h.Resource.RcvBuffer.lastFrame+1:h.Resource.RcvBuffer.numFrames 1:h.Resource.RcvBuffer.lastFrame];
            else %If the Verasonics Vantage is ran in simulation mode we don't have the lastFrame field
                frame_order = 1:h.Resource.RcvBuffer.numFrames;
            end
            
            if isempty(h.number_of_frames) ~= 1 %If number of frames is set, use that!
                frame_order = frame_order(1:h.number_of_frames);
            end
        end
    end
    
    % Private methods
    methods (Access = private)
        
        % Calculate the offset distance from start of transmitted pulse to
        % center of pulse and compensate for the lens correction
        function offset_distance = calc_lens_corr_and_center_of_pulse_in_m(h)
            % offset calculation
            offset_distance=(h.TW.peak)*h.lambda;   % in [m]
            if strcmp(h.Trans.units,'mm')
                offset_distance=offset_distance+2*h.Trans.lensCorrection*1e-3;
            elseif strcmp(h.Trans.units,'wavelengths')
                offset_distance=offset_distance+2*h.Trans.lensCorrection*h.lambda;
            end
        end
        
        % Generate a USTB probe object from the Verasonics parameters
        function prb = create_probe_object(h)
            if strcmp(h.Trans.name,'L7-4') || strcmp(h.Trans.name,'P4-2v') || strcmp(h.Trans.name,'L11-4v') || strcmp(h.Trans.name,'L11-5v') || strcmp(h.Trans.name,'GE9L-D')
                prb=uff.linear_array();
                prb.N=h.Trans.numelements;                  % number of elements
                prb.pitch=h.Trans.spacingMm/1000;           % probe pitch in azimuth [m]
                prb.element_width=h.Trans.elementWidth/1000;   % element width [m]
            else
                error('Sorry, that probe is not supported in USTB yet.');
            end
        end
        
        function trans_delays = calculate_trans_delays_in_m(h,channel_data,n_tx)
            %% Stolen from the computeTXDelays ;)
            % Hacked to work for the Verasonics definition of linear_array transmit focus with azimuth = 0
            % Delays are returned in seconds
            angle = 0;
            FocalPt(1) = channel_data.sequence(n_tx).source.x + channel_data.sequence(n_tx).source.z * sin(angle);
            FocalPt(2) = 0.0;
            FocalPt(3) = channel_data.sequence(n_tx).source.z * cos(angle);
            % Compute distance to focal point from each active element.
            X = channel_data.probe.geometry(:,1)' - FocalPt(1);
            D = sqrt(X.*X + FocalPt(3)*FocalPt(3));
            Indices = find(logical(h.TX(n_tx).Apod));
            D = max(D) - D;
            if n_tx < channel_data.N_waves/2
                D = D - D(Indices(end));
            else
                D = D - D(Indices(1));
            end
            
            %figure(101);clf;
            %plot(D,'b'); hold on;
            %plot(h.TX(n_tx).Delay*h.lambda,'r')
            
            trans_delays = D;
        end
    end
end
