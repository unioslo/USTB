classdef ulm_tracking_test < matlab.unittest.TestCase
    % Regression coverage for the ulm.tracking enum, which maps a
    % tracking scheme choice to the mode string consumed by
    % ulm.tracking2D.

    methods (Test)
        function test_none_maps_to_none(testCase)
            testCase.verifyEqual(char(ulm.tracking.none), 'none');
        end

        function test_tracks_maps_to_nointerp(testCase)
            testCase.verifyEqual(char(ulm.tracking.tracks), 'nointerp');
        end

        function test_interpolation_maps_to_interp(testCase)
            testCase.verifyEqual(char(ulm.tracking.interpolation), 'interp');
        end

        function test_velocity_interpolation_maps_to_velocityinterp(testCase)
            testCase.verifyEqual(char(ulm.tracking.velocity_interpolation), 'velocityinterp');
        end

        function test_pala_maps_to_pala(testCase)
            testCase.verifyEqual(char(ulm.tracking.pala), 'pala');
        end

        function test_string_matches_char(testCase)
            testCase.verifyEqual(string(ulm.tracking.velocity_interpolation), "velocityinterp");
        end

        function test_default_tracking_is_velocity_interpolation(testCase)
            % ulm.ULM defaults .tracking to
            % ulm.tracking.velocity_interpolation; keep that default
            % pinned since ULM.go() branches on it explicitly.
            testCase.verifyEqual(ulm.tracking.velocity_interpolation, ulm.tracking(3));
        end
    end
end
