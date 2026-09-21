classdef ulm_algorithm_test < matlab.unittest.TestCase
    % Regression coverage for the ulm.algorithm enum, which maps a
    % user-facing localization algorithm choice to the LocMethod/
    % InterpMethod strings consumed by ulm.localization2D.

    methods (Test)
        function test_no_shift_maps_to_nolocalization(testCase)
            [locMethod, interpMethod] = char(ulm.algorithm.no_shift);
            testCase.verifyEqual(locMethod, 'nolocalization');
            testCase.verifyEmpty(interpMethod);
        end

        function test_wa_maps_to_wa(testCase)
            [locMethod, interpMethod] = char(ulm.algorithm.wa);
            testCase.verifyEqual(locMethod, 'wa');
            testCase.verifyEmpty(interpMethod);
        end

        function test_radial_maps_to_radial(testCase)
            [locMethod, interpMethod] = char(ulm.algorithm.radial);
            testCase.verifyEqual(locMethod, 'radial');
            testCase.verifyEmpty(interpMethod);
        end

        function test_gaussian_fit_maps_to_curve_fitting(testCase)
            [locMethod, interpMethod] = char(ulm.algorithm.gaussian_fit);
            testCase.verifyEqual(locMethod, 'curveFitting');
            testCase.verifyEmpty(interpMethod);
        end

        function test_interp_variants_map_to_interp_with_method(testCase)
            [locMethod, interpMethod] = char(ulm.algorithm.interp_cubic);
            testCase.verifyEqual(locMethod, 'interp');
            testCase.verifyEqual(interpMethod, 'cubic');

            [locMethod, interpMethod] = char(ulm.algorithm.interp_lanczos);
            testCase.verifyEqual(locMethod, 'interp');
            testCase.verifyEqual(interpMethod, 'lanczos3');

            [locMethod, interpMethod] = char(ulm.algorithm.interp_spline);
            testCase.verifyEqual(locMethod, 'interp');
            testCase.verifyEqual(interpMethod, 'spline');
        end

        function test_string_matches_char(testCase)
            testCase.verifyEqual(string(ulm.algorithm.radial), "radial");
            testCase.verifyEqual(string(ulm.algorithm.wa), "wa");
        end

        function test_default_algorithm_is_no_shift(testCase)
            % ulm.ULM defaults .algorithm to ulm.algorithm.no_shift; keep
            % that default pinned since downstream code assumes it maps
            % to 'nolocalization'.
            testCase.verifyEqual(ulm.algorithm.no_shift, ulm.algorithm(0));
        end
    end
end
