classdef wave < uff
    %WAVE   UFF data class describing a transmitted or received wave event
    %
    %   WAVE defines a single transmit event in the acquisition sequence.
    %   The wave type is set by the wavefront property. A virtual source
    %   model determines the transmit delays used in beamforming.
    %
    %   For spherical waves (diverging or focused imaging) the source
    %   property defines the virtual source position. If source.z < 0 the
    %   wave is diverging; if source.z > 0 the wave is converging (focused).
    %   For plane waves the source azimuth and elevation angles set the
    %   steering direction.
    %
    %   Properties:
    %       wavefront           UFF.WAVEFRONT type (plane, spherical, photoacoustic)
    %       source              UFF.POINT virtual source location
    %       origin              UFF.POINT origin for delay calculations
    %       apodization         UFF.APODIZATION transmit apodization
    %       probe               UFF.PROBE reference
    %       event               index of the transmit/receive event
    %       delay               time between t0 and acquisition start [s]
    %       sound_speed         reference speed of sound [m/s]
    %
    %   Dependent properties:
    %       N_elements          number of probe elements
    %       delay_values        per-element transmit delays [s]
    %       apodization_values  per-element transmit apodization weights
    %
    %   Example:
    %       w = uff.wave();
    %       w.wavefront = uff.wavefront.plane;
    %       w.source.azimuth = 0.1;
    %
    %   See also UFF.CHANNEL_DATA, UFF.WAVEFRONT, UFF.POINT, UFF.APODIZATION
    
    %   authors: Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>
    %            Ole Marius Hoel Rindal <olemarius@olemarius.net>
    %            Anders E. Vrålstad <anders.e.vralstad@ntnu.no>
    %
    %   $Last updated: 2022/12/09$
    
    %% compulsory properties
    properties  (Access = public)
        wavefront                       % WAVEFRONT enumeration class
        source                          % POINT class
        origin                          % POINT class
        apodization                     % APODIZATION class
    end
    
    %% optional properties
    properties  (Access = public)
        probe              % PROBE class 
        event              % index of the transmit/receive event this wave refers to
        delay = 0          % time interval between t0 and acquistion start
        sound_speed = 1540 % reference speed of sound
        apodization_values % apodization [unitless]
    end
    
    
    %% dependent properties
    properties  (Dependent)
        N_elements         % number of elements
        delay_values       % delay [s]
        t0_origin          % delay [s] needed in case the t0 should be calculated from origin.xyz rather than [0, 0, 0]
    end
    
    %% constructor -> uff constructor
    methods (Access = public)
        function h=wave(varargin)
            h = h@uff(varargin{:});  

            if isempty(h.wavefront)
                h.wavefront = uff.wavefront.spherical;
            end
            
            if isempty(h.source)
                h.source = uff.point();
            end

            if isempty(h.origin)
                h.origin = uff.point();
            end

            if isempty(h.apodization)
                h.apodization = uff.apodization();
            end
        end
    end
    
    %% plot methods
    methods
        function fig_handle=plot(h,figure_handle_in)
            
            if nargin>1 && not(isempty(figure_handle_in))
                fig_handle=figure(figure_handle_in);
            else
                fig_handle=figure();
            end
            
            % probe geometry
            x = [(h.probe.x-h.probe.width/2.*cos(h.probe.theta)).'; (h.probe.x+h.probe.width/2.*cos(h.probe.theta)).'; (h.probe.x+h.probe.width/2.*cos(h.probe.theta)).'; (h.probe.x-h.probe.width/2.*cos(h.probe.theta)).'];
            y = [(h.probe.y-h.probe.height/2.*cos(h.probe.phi)).'; (h.probe.y-h.probe.height/2.*cos(h.probe.phi)).'; (h.probe.y+h.probe.height/2.*cos(h.probe.phi)).'; (h.probe.y+h.probe.height/2.*cos(h.probe.phi)).'; ];
            z = zeros(size(x));
            c = linspace(0,1,h.probe.N_elements);
            
            subplot(1,2,1);
            % draw flatten elements
            %fill3(x*1e3,y*1e3,z*1e3,c); grid on; axis equal tight; hold on;
            % draw delays
            %plot3(h.probe.x*1e3,h.probe.y*1e3,h.delay*1e6,'r.'); grid on; axis tight;
            plot(h.probe.x*1e3,h.delay_values*1e6,'r.'); grid on; axis tight;
            xlabel('x [mm]');
            %ylabel('y [mm]');
            ylabel('delay [\mus]');
            ylim([min([min(h.delay*1e6) -1e-3]) max([max(h.delay*1e6) 1e-3])]);
            set(gca,'fontsize',14);
            title('Delays');
            
            subplot(1,2,2);
            % draw flatten elements
            %fill3(x*1e3,y*1e3,z*1e3,c); grid on; axis equal tight; hold on;
            % draw apodization
            %plot3(h.probe.x*1e3,h.probe.y*1e3,h.apodization_values,'r.'); grid on; axis tight;
            plot(h.probe.x*1e3,h.apodization_values,'r.'); grid on; axis tight;
            xlabel('x [mm]');
            %ylabel('y [mm]');
            ylabel('Apodization');
            set(gca,'fontsize',14);
            title('Apodization');
            
        end
    end
    
    %% set methods
    methods
        function set.apodization(h,in_apodization)
            validateattributes(in_apodization, {'uff.apodization'}, {'scalar'})
            h.apodization=in_apodization;
        end
        function set.source(h,in_source)
            validateattributes(in_source, {'uff.point'}, {'scalar'})
            h.source=in_source;
        end
        function set.origin(h,in_origin)
            validateattributes(in_origin, {'uff.point'}, {'scalar'})
            h.origin=in_origin;
        end
        function set.probe(h,in_probe)
            validateattributes(in_probe, {'uff.probe'}, {'scalar'})
            h.probe=in_probe;
        end
        function set.wavefront(h,in_wavefront)
            validateattributes(in_wavefront, {'uff.wavefront'}, {'scalar'})
            h.wavefront=in_wavefront;
        end
    end

    %% get methods
    methods
        function value = get.t0_origin(h)
            % The sign is automatically calculated whether the source is 
            % located in front or behind the transducer, so that this 
            % quantity can be simply added to wave.delay

            if(h.source.z<0)
                value = -sqrt(sum(h.source.xyz.^2)) + sqrt(sum((h.source.xyz-h.origin.xyz).^2));
            else
                value = sqrt(sum(h.source.xyz.^2)) - sqrt(sum((h.source.xyz-h.origin.xyz).^2));
            end

            value = value/h.sound_speed;
        end


        function value=get.N_elements(h)
            value=h.probe.N_elements;
        end

        function value=get.delay_values(h)
            assert(~isempty(h.probe),'The PROBE must be inserted for delay calculation');
            assert(~isempty(h.sound_speed),'The sound speed must be inserted for delay calculation');

            source_origin_dist = sqrt(sum(h.source.xyz.^2));
            if ~isinf(source_origin_dist)
                dst=sqrt((h.probe.x-h.source.x).^2+(h.probe.y-h.source.y).^2+(h.probe.z-h.source.z).^2);
                if(h.source.z<0)
                    value=dst/h.sound_speed-abs(source_origin_dist/h.sound_speed);
                else
                    value=source_origin_dist/h.sound_speed-dst/h.sound_speed;
                end
            else
                value=(h.probe.x)*sin(h.source.azimuth)/h.sound_speed+(h.probe.y)*sin(h.source.elevation)/h.sound_speed;
            end
        end
        
        function value=get.apodization_values(h)
            if isempty(h.apodization)
                value=ones(1,h.probe.N_elements);
            else
                h.apodization.probe=h.probe; % set values not yet in apodization
                value=h.apodization.data();
            end
        end
    end    
end