classdef ulm_track2mat_out_test < matlab.unittest.TestCase
    % Regression coverage for ulm.Track2MatOut, which rasterizes
    % localized/tracked microbubble positions into a super-resolved
    % density (or velocity) image.

    methods (Test)
        function test_allin_mode_increments_pixel_once_per_point(testCase)
            % [z x] positions, two points fall on the same pixel after
            % rounding, one point falls on a distinct pixel.
            positions = [2.4 3.1; 2.3 2.6; 5.0 5.0];
            sizeOut = [6 6];

            MatOut = ulm.Track2MatOut(positions, sizeOut, 'mode', '2D_allin');

            expected = zeros(sizeOut);
            expected(2, 3) = 2; % both first two points round to (2,3)
            expected(5, 5) = 1;
            testCase.verifyEqual(MatOut, expected);
        end

        function test_allin_mode_drops_out_of_grid_points(testCase)
            positions = [0.2 3; 3 0.2; 7 3; 3 7; 3 3];
            sizeOut = [6 6];

            MatOut = ulm.Track2MatOut(positions, sizeOut, 'mode', '2D_allin');

            testCase.verifyEqual(sum(MatOut(:)), 1);
            testCase.verifyEqual(MatOut(3, 3), 1);
        end

        function test_matrix_input_defaults_to_allin_mode(testCase)
            positions = [3 3; 3 3];
            sizeOut = [6 6];

            MatOut = ulm.Track2MatOut(positions, sizeOut);

            testCase.verifyEqual(MatOut(3, 3), 2);
        end

        function test_tracks_mode_counts_pixel_once_per_track(testCase)
            % A single track that revisits the same pixel should only
            % contribute one count to that pixel, but two different
            % tracks crossing the same pixel each contribute a count.
            trackRevisiting = [3 3; 3 3; 4 4];
            otherTrack = [3 3];
            tracks = {trackRevisiting, otherTrack};
            sizeOut = [6 6];

            MatOut = ulm.Track2MatOut(tracks, sizeOut, 'mode', '2D_tracks');

            testCase.verifyEqual(MatOut(3, 3), 2);
            testCase.verifyEqual(MatOut(4, 4), 1);
            testCase.verifyEqual(sum(MatOut(:)), 3);
        end

        function test_cell_input_defaults_to_tracks_mode(testCase)
            tracks = {[3 3; 3 3], [4 4]};
            sizeOut = [6 6];

            MatOut = ulm.Track2MatOut(tracks, sizeOut);

            testCase.verifyEqual(MatOut(3, 3), 1);
            testCase.verifyEqual(MatOut(4, 4), 1);
        end

        function test_velmean_mode_averages_track_velocity_per_pixel(testCase)
            % [z x velocity] columns; two tracks cross pixel (3,3) with
            % different mean velocities, which should be averaged.
            trackA = [3 3 2];
            trackB = [3 3 4; 4 4 10];
            tracks = {trackA, trackB};
            sizeOut = [6 6];

            MatOut = ulm.Track2MatOut(tracks, sizeOut, 'mode', '2D_velmean');

            testCase.verifyEqual(MatOut(3, 3), 3); % mean(2,4)
            testCase.verifyEqual(MatOut(4, 4), 10);
            testCase.verifyEqual(MatOut(1, 1), 0);
        end

        function test_unsupported_mode_raises_error(testCase)
            caughtError = [];
            try
                ulm.Track2MatOut([1 1], [5 5], 'mode', 'not_a_real_mode');
            catch caughtError
            end
            testCase.verifyNotEmpty(caughtError, ...
                'Track2MatOut should raise an error for an unsupported mode.');
        end
    end
end
