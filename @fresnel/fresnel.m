classdef fresnel < handle
%FRESNEL lightweight, open-source ultrasound simulator
%
%   See also PULSE, BEAM, PHANTOM, PROBE
%
%   authors: Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>
%            Stefano Fiorentini <stefano.fiorentini@ntnu.no>
%
%   $Date: 2022/22/12$

    %% public properties
    properties  (Access = public)
        phantom             % phantom class
        pulse               % pulse class
        probe               % probe class
        sequence            % collection of wave classes
        sampling_frequency  % sampling frequency [Hz]
        PRF                 % pulse repetition frequency [Hz]
    end
    
    %% dependent properties
    properties  (Dependent)   
        N_elements         % number of elements in the probe
        N_points           % number of points in the phantom
        N_waves            % number of waves
        N_events           % number of events (waves*frames)
        N_frames           % number of frames
    end
    
    %% private properties
    properties  (Access = private)   
        version='v2.0.0';  % fresnel version
    end
    
    %% constructor
    methods (Access = public)
        function h=fresnel()
            %fresnel   Constructor of fresnel class
            %
            %   Syntax:
            %   h = fresnel()
            %
            %   See also BEAM, PHANTOM, PROBE, PULSE                      
            
        end
    end
    
    %% set methods
    methods  
        function out_dataset = go(h)
            fprintf(1, 'USTB Fresnel impulse response simulator (%s)\n', h.version);
            
            %% checking we have all we need
            assert(~isempty(h.probe),'The PROBE parameter is not set.');
            assert(~isempty(h.phantom),'The PHANTOM parameter is not set.');
            assert(~isempty(h.pulse),'The PULSE parameter is not set.');
            assert(~isempty(h.sequence),'The SEQUENCE parameter is not set.');
            assert(~isempty(h.sampling_frequency),'The SAMPLING_FREQUENCY parameter is not set.');

            % checking number of elements
            assert(any(h.probe.N_elements==[h.sequence.N_elements]),'Mismatch in the number of elements in probe and the size of delay and apodization vectors in beam');
            
            c0 = h.phantom.sound_speed;
            f0 = h.pulse.center_frequency;
            w0 = 2*pi*f0;
            k0 = w0/c0;
            fs = h.sampling_frequency;
            bw = h.pulse.fractional_bandwidth;
            
            %% minimum distance for including geometric dispersion
            delta0 = 4*pi*0.1e-3;

            % save the data into a CHANNEL_DATA structure
            out_dataset = uff.channel_data();
            out_dataset.probe = h.probe();
            out_dataset.pulse = h.pulse();
            out_dataset.phantom = h.phantom();
            out_dataset.sequence = h.sequence();
            out_dataset.sampling_frequency = h.sampling_frequency();
            out_dataset.sound_speed = h.phantom.sound_speed;
            out_dataset.PRF = h.PRF;
 
            % computing geometry relations to the point
            distance  = sqrt((h.phantom.x.'-h.probe.x).^2+(h.phantom.y.'-h.probe.y).^2+(h.phantom.z.'-h.probe.z).^2);
            theta = atan2(h.phantom.x.'-h.probe.x, h.phantom.z.'-h.probe.z)-h.probe.theta;
            phi = atan2(h.phantom.y.'-h.probe.y, h.phantom.z.'-h.probe.z)-h.probe.phi;
            
            % directivity between probe and the point
            directivity = sinc(k0*h.probe.width/2/pi.*tan(theta)).*sinc(k0*h.probe.height/2/pi.*tan(phi)./cos(theta));
            
            % delay between probe and the point
            propagation_delay = permute(distance/c0, [3,1,2]);
            
            % attenuation (absorption & geometrical dispersion)
            attenuation = permute(10.^(-h.phantom.alpha*(distance*1e2)*(f0*1e-6)).*directivity.*delta0./(4*pi*distance), [3,1,2]);
            
            min_range = min(distance, [], 'all');
            max_range = max(distance, [], 'all');
            min_delay = min([h.sequence(:).delay_values], [], 'all');
            max_delay = max([h.sequence(:).delay_values], [], 'all');
            
            time_1w = ((min_range/c0 - 8/f0/bw + min_delay):1/fs:(max_range/c0 + 8/f0/bw + max_delay)).';                                                  % time vector [s]
            time_2w = (2*(min_range/c0 - 8/f0/bw + min_delay):1/fs:2*(max_range/c0 + 8/f0/bw + max_delay)).';                                               % time vector [s]
            N_samples = length(time_2w);  % number of time samples
            

            F = griddedInterpolant();
            F.Method = 'linear';
            F.ExtrapolationMethod = 'none';
            F.GridVectors = {time_1w};

            % Preallocating memory
            receive_signal = zeros([N_samples, h.N_elements, h.phantom.N_points]);
            channel_data = zeros([N_samples, h.N_elements, h.N_waves]);
            
            w = waitbar(0, 'Generating channel data...');
            for n_wave=1:h.N_waves
                
                waitbar(n_wave/h.N_waves, w)
                
                % Computing the transmit signal
                transmit_delay = time_1w - propagation_delay - h.sequence(n_wave).delay_values.';
                transmit_signal = sum(h.pulse.signal(transmit_delay).*h.sequence(n_wave).apodization_values.*attenuation, 2);
                
                receive_delay = time_2w - propagation_delay + h.sequence(n_wave).delay;

                % Computing the receive signal
                for n_point = 1:h.phantom.N_points
                    F.Values = transmit_signal(:,1,n_point);
                    receive_signal(:,:,n_point) = F(receive_delay(:,:,n_point));
                end
                
                % Sum the contributions from all of the point
                channel_data(:,:,n_wave) = sum(receive_signal.*attenuation, 3, 'omitnan');
            end
            close(w)
            
            out_dataset.initial_time = time_2w(1);
            out_dataset.data = channel_data;
        end
    end
    
    %% set methods
    methods  
        function set.phantom(h,in_phantom)
            validateattributes(in_phantom, {'uff.phantom'}, {'scalar'})
            h.phantom = in_phantom;
        end
        function set.pulse(h,in_pulse)
            validateattributes(in_pulse, {'uff.pulse'}, {'scalar'})
            h.pulse = in_pulse;
        end
        function set.probe(h,in_probe)
            validateattributes(in_probe, {'uff.probe'}, {'scalar'})
            h.probe = in_probe;
        end
        function set.sequence(h,in_sequence)
            validateattributes(in_sequence, {'uff.wave'}, {'vector'})
            h.sequence = in_sequence;
        end
        function set.sampling_frequency(h,in_sampling_frequency)
            validateattributes(in_sampling_frequency, {'single', 'double'}, {'scalar'})
            h.sampling_frequency = in_sampling_frequency;
        end       
        function set.PRF(h,in_PRF)
            validateattributes(in_PRF, {'single', 'double'}, {'scalar'})
            h.PRF = in_PRF;
        end       
    end
    
    %% get methods
    methods  
        function value=get.N_elements(h)
            value=h.probe.N_elements;
        end
        function value=get.N_points(h)
            value=h.phantom.N_points;
        end
        function value=get.N_waves(h)
            value=numel(h.sequence);
        end
        function value=get.N_events(h)
            value=length(h.phantom);
        end
        function value=get.N_frames(h)
            value=ceil(h.N_events/h.N_waves);
        end
    end   
end