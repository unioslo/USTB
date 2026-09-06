classdef image_mode < int16
    %IMAGE_MODE Enumeration for ULM image reconstruction modes.

    enumeration
        tracks(0)
        no_cell(1)
        velocity_z(2)
        velocity_norm(3)
        velocity_mean(4)
    end

    methods
        function mode = char(obj)
            mode = [];
            switch obj
                case ulm.image_mode.tracks
                    mode = '2D_tracks';
                case ulm.image_mode.no_cell
                    mode = '2D_allin';
                case ulm.image_mode.velocity_z
                    mode = '2D_vel_z';
                case ulm.image_mode.velocity_norm
                    mode = '2D_velnorm';
                case ulm.image_mode.velocity_mean
                    mode = '2D_velmean';
                otherwise
                    disp('Method not supported!')
            end
        end
        
        function s = string(obj)
            s = string(char(obj));
        end
    end     
end

