classdef ulm_localization2d_test < matlab.unittest.TestCase
    % Regression coverage for ulm.localization2D, the detection +
    % sub-pixel localization step of the ULM pipeline. Requires the
    % Image Processing Toolbox (imregionalmax); skipped when it is not
    % installed so this stays CI-safe on minimal MATLAB installs.

    methods (TestClassSetup)
        function skipIfImageProcessingToolboxMissing(testCase)
            testCase.assumeTrue(~isempty(ver('images')), ...
                'ulm.localization2D requires the Image Processing Toolbox.');
        end
    end

    methods (Test)
        function test_single_bubble_is_localized_near_its_pixel(testCase)
            frame = zeros(20, 20);
            frame(10, 12) = 1;
            MatIn = frame;

            ULM = testCase.baseParams();
            ULM.numberOfParticles = 1;

            MatTracking = ulm.localization2D(MatIn, ULM);

            testCase.verifySize(MatTracking, [1, 4]);
            testCase.verifyEqual(MatTracking(1, 2), 10, 'AbsTol', 0.5); % z
            testCase.verifyEqual(MatTracking(1, 3), 12, 'AbsTol', 0.5); % x
            testCase.verifyEqual(MatTracking(1, 4), 1); % frame index
            testCase.verifyEqual(MatTracking(1, 1), 1); % intensity
        end

        function test_frame_index_matches_third_dimension(testCase)
            MatIn = zeros(20, 20, 3);
            MatIn(8, 8, 1) = 1;
            MatIn(9, 9, 2) = 1;
            MatIn(10, 10, 3) = 1;

            ULM = testCase.baseParams();
            ULM.numberOfParticles = 1;

            MatTracking = ulm.localization2D(MatIn, ULM);

            testCase.verifySize(MatTracking, [3, 4]);
            testCase.verifyEqual(sort(MatTracking(:, 4)), [1; 2; 3]);
        end

        function test_only_top_particles_are_kept(testCase)
            frame = zeros(20, 20);
            frame(5, 5) = 3;
            frame(10, 10) = 2;
            frame(15, 15) = 1;

            ULM = testCase.baseParams();
            ULM.numberOfParticles = 2;

            MatTracking = ulm.localization2D(frame, ULM);

            % Only the two brightest local maxima should survive.
            testCase.verifySize(MatTracking, [2, 4]);
            testCase.verifyEqual(sort(MatTracking(:, 1)), [2; 3]);
        end

        function test_nolocalization_keeps_maxima_at_integer_pixel(testCase)
            frame = zeros(20, 20);
            frame(10, 12) = 1;

            ULM = testCase.baseParams();
            ULM.LocMethod = 'nolocalization';
            ULM.numberOfParticles = 1;

            MatTracking = ulm.localization2D(frame, ULM);

            testCase.verifyEqual(MatTracking(1, 2), 10);
            testCase.verifyEqual(MatTracking(1, 3), 12);
        end

        function test_empty_frame_yields_no_tracking_points(testCase)
            frame = zeros(20, 20);

            ULM = testCase.baseParams();
            ULM.numberOfParticles = 3;

            MatTracking = ulm.localization2D(frame, ULM);

            testCase.verifySize(MatTracking, [0, 4]);
        end
    end

    methods (Access = private)
        function ULM = baseParams(~)
            ULM = struct( ...
                'LocMethod', 'radial', ...
                'numberOfParticles', 3, ...
                'fwhm', [3 3], ...
                'workbars', false, ...
                'parameters', struct('NLocalMax', 3));
        end
    end
end
