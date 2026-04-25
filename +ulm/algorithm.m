classdef algorithm < int16
%algorithm   Enumeration for ULM localization algorithm types.

    enumeration
        no_shift(0)
        wa(1)
        interp_cubic(2)
        interp_lanczos(3)
        interp_spline(4)
        gaussian_fit(5)
        radial(6)
    end

    methods
        function [LocMethod, InterpMethod] = char(obj)
            InterpMethod = [];
            switch obj
                case ulm.algorithm.no_shift
                    LocMethod = 'nolocalization';
                case ulm.algorithm.wa
                    LocMethod = 'wa';
                case ulm.algorithm.radial
                    LocMethod = 'radial';
                case ulm.algorithm.interp_cubic
                    LocMethod = 'interp';
                    InterpMethod = 'cubic';
                case ulm.algorithm.interp_lanczos
                    LocMethod = 'interp';
                    InterpMethod = 'lanczos3';
                case ulm.algorithm.interp_spline
                    LocMethod = 'interp';
                    InterpMethod = 'spline';
                case ulm.algorithm.gaussian_fit
                    LocMethod = 'curveFitting';
                otherwise
                    disp('Method not supported!')
            end
        end
        
        function s = string(obj)
            s = string(char(obj));
        end
    end
end


%
            