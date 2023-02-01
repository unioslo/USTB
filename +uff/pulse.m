classdef pulse < uff
    %pulse   Pulse definition
    %
    %   See also PULSE, PHANTOM
    
    %   authors: Alfonso Rodriguez-Molares (alfonso.r.molares@ntnu.no)
    %   $Date: 2017/09/15 $
    
    %% public properties
    properties  (Access = public)
        center_frequency           % center frequency [Hz]
        fractional_bandwidth       % probe fractional bandwidth [unitless]
        phase                      % initial phase [rad]
        waveform                   % transmitted waveform (for example used for match filtering)
    end
    
    
    %% constructor
    methods (Access = public)
        function h=pulse(varargin)
            h = h@uff(varargin{:});
        end
    end
    
    %% plot methods
    methods
        function figure_handle=plot(h,figure_handle_in,title_in,LineStyle)
            t0=linspace(-2/h.center_frequency/h.fractional_bandwidth,2/h.center_frequency/h.fractional_bandwidth,512);
            
            % plotting pulse
            if (nargin>1 && ~isempty(figure_handle_in) && isa(figure_handle_in,'matlab.ui.Figure')) || ...
                    (nargin>1 && ~isempty(figure_handle_in) && isa(figure_handle_in,'double'))
                figure_handle=figure(figure_handle_in);
                axis_handle = gca(figure_handle_in);
                hold on;
            elseif nargin>1 && ~isempty(figure_handle_in) && isa(figure_handle_in,'matlab.graphics.axis.Axes')
                figure_handle = figure_handle_in;
                axis_handle = figure_handle_in;
            else
                figure_handle=figure();
                axis_handle = gca(figure_handle);
                title('Pulse'); hold on;
            end
            if nargin < 4
                LineStyle = '-';
            end
            

            plot(axis_handle,t0*1e6,h.signal(t0), 'LineStyle', LineStyle); grid on; axis tight;
            xlabel('time [\mu{}s]','Interpreter','tex');
            set(gca,'ZDir','Reverse');
            set(gca,'fontsize',14);
            
            if nargin>2
                title(title_in);
            end
        end
    end
    
    %% get the signal for a given time
    methods
        function s=signal(h, time)
            % gaussian-pulsed pulse
            s=cos(2*pi*h.center_frequency*time).*exp(-1.7886*(time*h.fractional_bandwidth*h.center_frequency).^2);
        end
    end
end