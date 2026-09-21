classdef ulm_image_mode_test < matlab.unittest.TestCase
    % Regression coverage for the ulm.image_mode enum, which maps a
    % rendering mode choice to the mode string consumed by
    % ulm.Track2MatOut.

    methods (Test)
        function test_tracks_maps_to_2D_tracks(testCase)
            testCase.verifyEqual(char(ulm.image_mode.tracks), '2D_tracks');
        end

        function test_no_cell_maps_to_2D_allin(testCase)
            testCase.verifyEqual(char(ulm.image_mode.no_cell), '2D_allin');
        end

        function test_velocity_z_maps_to_2D_vel_z(testCase)
            testCase.verifyEqual(char(ulm.image_mode.velocity_z), '2D_vel_z');
        end

        function test_velocity_norm_maps_to_2D_velnorm(testCase)
            testCase.verifyEqual(char(ulm.image_mode.velocity_norm), '2D_velnorm');
        end

        function test_velocity_mean_maps_to_2D_velmean(testCase)
            testCase.verifyEqual(char(ulm.image_mode.velocity_mean), '2D_velmean');
        end

        function test_string_matches_char(testCase)
            testCase.verifyEqual(string(ulm.image_mode.tracks), "2D_tracks");
        end
    end
end
