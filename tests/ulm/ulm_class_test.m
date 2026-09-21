classdef ulm_class_test < matlab.unittest.TestCase
    % Regression coverage for the ulm.ULM facade class: input/scan
    % validation, the derived `process` struct, threshold defaulting,
    % and the pairing() classification statistics.
    %
    % ulm.ULM's constructor unconditionally requires a large set of
    % paid toolboxes (Bioinformatics, Curve Fitting, Statistics and
    % Machine Learning, Computer Vision, ...) on top of MATLAB itself.
    % The whole class is skipped when any of them is not installed so
    % this stays CI-safe on minimal MATLAB installs; run it on a fully
    % licensed workstation to get real coverage.

    methods (TestClassSetup)
        function skipIfMissingToolboxes(testCase)
            % Short names as understood by ver(), mirroring the
            % toolboxes ulm.ULM's constructor requires.
            requiredIds = {'comm', 'bioinfo', 'images', 'curvefit', ...
                'signal', 'stats', 'parallel', 'vision'};
            haveAll = all(cellfun(@(id) ~isempty(ver(id)), requiredIds));
            testCase.assumeTrue(haveAll, ...
                'ulm.ULM requires toolboxes that are not installed in this environment.');
        end
    end

    methods (Test)
        function test_set_input_rejects_non_beamformed_data(testCase)
            h = ulm.ULM();

            caughtError = [];
            try
                h.input = 5;
            catch caughtError
            end

            testCase.verifyClass(caughtError, 'MException');
        end

        function test_set_scan_rejects_non_scan(testCase)
            h = ulm.ULM();

            caughtError = [];
            try
                h.scan = 5;
            catch caughtError
            end

            testCase.verifyClass(caughtError, 'MException');
        end

        function test_update_derives_thresholds_from_lambda(testCase)
            h = ulm.ULM();
            h.lambda = 4e-4;
            h.threshold_pairing = [];
            h.threshold_tp = [];

            h.update();

            testCase.verifyEqual(h.threshold_pairing, 2e-4);
            testCase.verifyEqual(h.threshold_tp, 1e-4);
        end

        function test_update_does_not_override_explicit_thresholds(testCase)
            h = ulm.ULM();
            h.lambda = 4e-4;
            h.threshold_pairing = 9e-4;
            h.threshold_tp = 8e-4;

            h.update();

            testCase.verifyEqual(h.threshold_pairing, 9e-4);
            testCase.verifyEqual(h.threshold_tp, 8e-4);
        end

        function test_process_struct_reflects_configuration(testCase)
            scan = uff.linear_scan('x_axis', linspace(-1e-3, 1e-3, 16).', ...
                                    'z_axis', linspace(0, 2e-3, 32).');
            bd = uff.beamformed_data();
            bd.scan = scan;
            bd.data = randn(scan.N_pixels, 1, 1, 5);

            h = ulm.ULM();
            h.scan = scan;
            h.input = bd;
            h.verbose = false;
            h.workbars = false;

            process = h.process;

            testCase.verifyEqual(process.numberOfParticles, 70);
            testCase.verifyEqual(process.res, 10);
            testCase.verifyEqual(process.max_linking_distance, 2);
            testCase.verifyEqual(process.min_length, 15);
            testCase.verifyEqual(process.fwhm, [3 3]);
            testCase.verifyEqual(process.max_gap_closing, 0);
            testCase.verifyEqual(process.size, [32, 16, 5]);
            testCase.verifyEqual(process.scale, [1 1 1/60]);
            testCase.verifyEqual(process.numberOfFramesProcessed, 5);
            testCase.verifyEqual(process.interp_factor, 1/10);
            testCase.verifyEqual(process.parameters.NLocalMax, 3);
            testCase.verifyEqual(process.SRscale, 0.1);
            testCase.verifyEqual(process.SRsize, [320, 160]);
            % default algorithm is no_shift -> 'nolocalization'
            testCase.verifyEqual(process.LocMethod, 'nolocalization');
            testCase.verifyEmpty(process.parameters.InterpMethod);
        end

        function test_pairing_classification_counts(testCase)
            scan = uff.linear_scan('x_axis', linspace(-1e-3, 1e-3, 50).', ...
                                    'z_axis', linspace(0, 2e-3, 50).');

            h = ulm.ULM();
            h.scan = scan;
            h.lambda = 0.2e-3; % => threshold_pairing=1e-4, threshold_tp=5e-5
            h.numberOfFrames = 1;
            h.verbose = false;
            h.workbars = false;

            % Reference (simulated) bubbles, [x y z reflectivity]: one
            % that will be recovered as a true positive, one that will
            % be missed entirely.
            position_reference = zeros(2, 4, 1);
            position_reference(1, :, 1) = [0, 0, 1e-3, 1];
            position_reference(2, :, 1) = [0.5e-3, 0, 1.5e-3, 1];

            % Localized detections, [z x frame]: one close to the first
            % reference bubble (true positive), one far from both
            % (false positive).
            track_in = [ ...
                1e-3 + 1e-5, 1e-5, 1; ...
                1.9e-3, -0.9e-3, 1 ...
            ];

            [stat, ~, finalPairs, missingPoint, wrongLoc] = h.pairing(track_in, position_reference);

            testCase.verifyEqual(stat, [2 2 1 1 1]); % [Npos_in Npos_loc T_pos F_neg F_pos]
            testCase.verifyEqual(finalPairs{1}(:, 1:2), [1 1]);
            testCase.verifyEqual(missingPoint{1}, 2);
            testCase.verifyEqual(wrongLoc{1}, 2);
        end
    end
end
