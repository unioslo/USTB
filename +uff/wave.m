classdef wave < uff
    %WAVE   UFF class that describes a transmitted wave 
    %   WAVE contains information to describe a wave: plannar, spherical,
    %   or photoacoustic, and the apodization used to produce it.
    %
    %   WAVE.WAVEFRONT defines the type of wave produced: uff.wavefront.plane, 
    %   uff.wavefront.plane, uff.wavefront.spherical, or uff.wavefront.photoacoustic.  
    %
    %   WAVE.SOURCE defines the wave attitude. If WAVE.WAVEFRONT is uff.wavefront.spherical 
    %   then WAVE.SOURCE defines the point in space from which the wave originated. 
    %   If WAVE.SOURCE is behind the plane z=0 then the spherical wave will be
    %   diverging. If WAVE.SOURCE is in front of the plane z=0 the the spherical 
    %   wave will be converging. If the WAVE.TYPWAVEFRONTE is uff.wavefront.plane then 
    %   WAVE.SOURCE defines the orientation through the azimuth and elevation 
    %   angles, i.e. WAVE.SOURCE.DISTANCE becomes meaningless. If the WAVE.WAVEFRONT is
    %   uff.wavefront.photoacoustic then WAVE.SOURCE is ignored.
    %
    %   WAVE.APODIZATION is a UFF.APODIZATION class used to compute the apodization
    %   values that generate the UFF.WAVE.
    %
    %   WAVE.INITIAL_TIME defines the time interval between the reference
    %   time t0 and the start of acquisition for this particular wave. We 
    %   refer to reference time, or time zero, as the moment the wave passes 
    %   through the origin of coordinates (0,0,0).
    %
    %   Compulsory properties:
    %    wavefront          % WAVEFRONT enumeration class
    %    source             % POINT class
    %    apodization        % APODIZATION class
    %
    %   Optional properties:
    %    probe              % PROBE class 
    %    event              % index of the transmit/receive events this wave refers to
    %    sound_speed        % reference speed of sound
    %    initial_time       % time interval between generation and acquistion 
    %
    %   Example:
    %         wave = uff.wave();
    %
    %   See also UFF.POINT, UFF.BEAMFORMED_DATA, UFF.PROBE
    
    %   authors: Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>
    %            Ole Marius Hoel Rindal <olemarius@olemarius.net>
    %
    %   $Last updated: 2017/10/13$
    
    %% compulsory properties
    properties  (Access = public)
        wavefront = uff.wavefront.spherical % WAVEFRONT enumeration class
        source            % POINT class
        apodization       % APODIZATION class
    end
    
    %% optional properties
    properties  (Access = public)
        probe              % PROBE class 
        event              % index of the transmit/receive event this wave refers to
        delay = 0          % time interval between t0 and acquistion start
        sound_speed = 1540 % reference speed of sound
    end
    
    
    %% dependent properties
    properties  (Dependent)
        N_elements         % number of elements
        delay_values       % delay [s]
        apodization_values % apodization [unitless]
    end
    
    %% constructor -> uff constructor
    methods (Access = public)
        function h=wave(varargin)
            h = h@uff(varargin{:});
            
            % default values
            if ~isa(h.source, 'uff.point'), h.source = uff.point(); end
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
        function h=set.apodization(h,in_apodization)
            assert(isa(in_apodization,'uff.apodization'), 'The apodization is not an APODIZATION class. Check HELP APODIZATOR');
            h.apodization=in_apodization;
        end
        function h=set.source(h,in_source)
            assert(isa(in_source,'uff.point'), 'The source is not a POINT class. Check HELP POINT');
            h.source=in_source;
        end
        function h=set.probe(h,in_probe)
            assert(isa(in_probe,'uff.probe'), 'The probe is not a PROBE class. Check HELP PROBE');
            h.probe=in_probe;
        end
        function h=set.wavefront(h,in_wavefront)
            assert(isa(in_wavefront,'uff.wavefront'), 'The probe is not a WAVEFRONT class. Check HELP WAVEFRONT');
            h.wavefront=in_wavefront;
            if (h.wavefront == uff.wavefront.plane) h.source.distance = Inf; end
        end
    end
    
    %% get methods
    methods
        function value=get.N_elements(h)
            value=h.probe.N_elements;
        end
        
        function value=get.delay_values(h)
            assert(~isempty(h.probe),'The PROBE must be inserted for delay calculation');
            assert(~isempty(h.sound_speed),'The sound speed must be inserted for delay calculation');
            
            if ~isinf(h.source.distance)
                dst=sqrt((h.probe.x-h.source.x).^2+(h.probe.y-h.source.y).^2+(h.probe.z-h.source.z).^2);
                if(h.source.z<0)
                    value=dst/h.sound_speed-abs(h.source.distance/h.sound_speed);
                else
                    value=h.source.distance/h.sound_speed-dst/h.sound_speed;
                end
            else
                value=h.probe.x*sin(h.source.azimuth)/h.sound_speed+h.probe.y*sin(h.source.elevation)/h.sound_speed;
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