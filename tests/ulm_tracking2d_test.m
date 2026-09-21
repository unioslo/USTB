classdef ulm_tracking2d_test < matlab.unittest.TestCase
    % Regression coverage for ulm.tracking2D, which links per-frame
    % bubble positions into trajectories and post-processes them
    % (interpolation, velocity). The 'velocityinterp'/'interp'/'pala'
    % modes additionally require the Curve Fitting Toolbox (smooth());
    % that single test is skipped when it is not installed so the rest
    % of the suite stays CI-safe on minimal MATLAB installs.

    methods (Test)
        function test_nointerp_recovers_single_straight_track(testCase)
            % A single bubble moving diagonally by (1,1) px per frame
            % over 20 frames.
            nFrames = 20;
            MatTracking = testCase.straightLineTrack(nFrames, [1 1], [10 10]);

            ULM = testCase.baseParams(nFrames);

            Tracks = ulm.tracking2D(MatTracking, ULM, 'nointerp');

            testCase.verifyNumElements(Tracks, 1);
            track = Tracks{1};
            testCase.verifyGreaterThan(size(track, 1), ULM.min_length);
            testCase.verifyEqual(track(1, 1:2), [10 10], 'AbsTol', 1e-6);
            testCase.verifyEqual(track(end, 1:2), [10 10] + (nFrames - 1) * [1 1], 'AbsTol', 1e-6);
        end

        function test_short_tracks_yield_placeholder_track(testCase)
            % Current behaviour: when every candidate track is shorter
            % than min_length, tracking2D does not return an empty
            % result -- it falls back to a single [0 0 0 0] placeholder
            % track. This is pinned so a future change to that fallback
            % (e.g. in feature/update_ULM_code) is caught explicitly.
            nFrames = 5; % shorter than min_length below
            MatTracking = testCase.straightLineTrack(nFrames, [1 1], [3 3]);

            ULM = testCase.baseParams(nFrames);
            ULM.min_length = 15;

            Tracks = ulm.tracking2D(MatTracking, ULM, 'nointerp');

            testCase.verifyNumElements(Tracks, 1);
            testCase.verifyEqual(Tracks{1}, [0 0 0 0]);
        end

        function test_far_apart_points_are_not_linked_into_one_track(testCase)
            nFrames = 20;
            trackA = testCase.straightLineTrack(nFrames, [1 1], [5 5]);
            trackB = testCase.straightLineTrack(nFrames, [1 1], [200 200]);

            MatTracking = [trackA; trackB];

            ULM = testCase.baseParams(nFrames);

            Tracks = ulm.tracking2D(MatTracking, ULM, 'nointerp');

            testCase.verifyNumElements(Tracks, 2);
        end

        function test_velocityinterp_returns_position_and_velocity_columns(testCase)
            testCase.assumeTrue(~isempty(ver('curvefit')), ...
                'velocityinterp mode requires the Curve Fitting Toolbox (smooth()).');

            nFrames = 20;
            MatTracking = testCase.straightLineTrack(nFrames, [1 0], [10 10]);

            ULM = testCase.baseParams(nFrames);
            ULM.scale = [1 1 1]; % 1 second per frame

            Tracks = ulm.tracking2D(MatTracking, ULM, 'velocityinterp');

            testCase.verifyNumElements(Tracks, 1);
            track = Tracks{1};
            testCase.verifySize(track, [size(track, 1), 5]); % z x vz vx t

            % Constant axial speed of 1 px/frame => 1 px/s given scale(3)=1.
            testCase.verifyEqual(mean(track(:, 3)), 1, 'AbsTol', 0.2);
            testCase.verifyEqual(mean(track(:, 4)), 0, 'AbsTol', 0.2);
        end
    end

    methods (Access = private)
        function ULM = baseParams(~, nFrames)
            ULM = struct( ...
                'max_linking_distance', 2, ...
                'max_gap_closing', 0, ...
                'min_length', 10, ...
                'scale', [1 1 1], ...
                'res', 10, ...
                'size', [256 256 nFrames]);
        end

        function MatTracking = straightLineTrack(~, nFrames, stepPerFrame, startPos)
            % Builds a MatTracking table [intensity z x frame] for a
            % single bubble moving linearly across nFrames frames.
            frames = (1:nFrames)';
            z = startPos(1) + (frames - 1) * stepPerFrame(1);
            x = startPos(2) + (frames - 1) * stepPerFrame(2);
            intensity = ones(nFrames, 1);
            MatTracking = [intensity, z, x, frames];
        end
    end
end
