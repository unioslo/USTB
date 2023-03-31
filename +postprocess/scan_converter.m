classdef scan_converter < postprocess
    %SCAN_CONVERTER postprocess that performs scan convertion on a
    %beamformed_data object
    %   authors:    Stefano Fiorentini (stefano.fiorentini@ntnu.no)
    %   $Date: 2022/12/19$
    methods (Access = public)
        function h = scan_converter()
            h.name = 'Scan converter';
            h.reference='';
            h.implemented_by='Stefano Fiorentini <stefano.fiorentini@ntnu.no>';
            h.version='v1.0.0';
        end
    end
    
    properties
        scan % UFF.SCAN object defining the desired scan for the output beamformed data
    end
    
    methods
        function output=go(h)
            % check if we can skip calculation
            if h.check_hash()
                output = h.output;
                return;
            end
            assert(isa(h.input.scan, 'uff.sector_scan'), 'Input beamformed data must be defined on a sector scan!');

            output = uff.beamformed_data();   
 
            % Allocate memory for scan converted data
            output.data = zeros([h.scan.N_pixels, h.input.N_channels, h.input.N_waves, h.input.N_frames], 'like', h.input.data);
            
            % Define the interpolation object. Define scatteredInterpolant
            % once and only change the data to be interpolated to preserve
            % the underlying triangulation
            F = scatteredInterpolant(h.input.scan.x, h.input.scan.z, ...
               h.input.data(:,1), 'linear', 'none');
                                    
            % Waitbar
            h = waitbar(0, 'Scan convertion...');
            
            for n_frames = 1:h.input.N_frames               
                for n_wave = 1:h.input.N_waves
                    for n_channel = 1:h.input.N_channels
                        
                        % Update waitbar
                        waitbar((n_channel + n_wave*h.input.N_channels + ...
                            n_frame*h.input.N_channels*h.input.N_waves) / ...
                            (h.input.N_channels*h.input.N_waves*h.input.N_frames), h)

                        F.values = h.input.data(:,n_channel,n_wave,n_frames);
                        output.data(:,n_channel,n_wave,n_frames) = ...
                            F(h.scan.x, h.scan.z);
                    end
                end
            end
            
            % Close waitbar
            close(h)
            
            output.sequence = h.input.sequence;
            output.probe = h.input.probe;
            output.sampling_frequency = h.input.sampling_frequency;
            output.modulation_frequency = h.input.modulation_frequency;
            output.scan = h.scan;    
            
            h.output = output;       
         end 
    end % methods
    
    %% set methods
    methods
        function set.scan(h, in_scan)
            assert(isa(in_scan, 'uff.linear_scan'), 'Scan conversion can only be performed into a 2D/3D linear scan!');
            h.scan = in_scan;
        end
    end % methods
end % classdef

