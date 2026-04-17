classdef tracking < int16
    %tracking   Enumeration for ULM tracking modes.
    
    enumeration
        none(0)
        tracks(1)
        interpolation(2)
        velocity_interpolation(3)
        pala(4)
    end
    
    methods
        function s = char(obj)
            switch obj
                case ulm.tracking.none
                    s = 'none';
                case ulm.tracking.tracks
                    s = 'nointerp';
                case ulm.tracking.interpolation
                    s = 'interp';
                case ulm.tracking.velocity_interpolation
                    s = 'velocityinterp';
                case ulm.tracking.pala
                    s = 'pala';
            end
        end
        
        function s = string(obj)
            s = string(char(obj));
        end
    end
end
