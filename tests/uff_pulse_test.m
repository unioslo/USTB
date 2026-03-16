classdef uff_pulse_test < matlab.unittest.TestCase

    methods (Test)
        function test_construction(testCase)
            p = uff.pulse();
            p.center_frequency = 5e6;
            p.fractional_bandwidth = 0.6;

            testCase.verifyEqual(p.center_frequency, 5e6);
            testCase.verifyEqual(p.fractional_bandwidth, 0.6);
        end

        function test_signal_returns_correct_length(testCase)
            p = uff.pulse();
            p.center_frequency = 5e6;
            p.fractional_bandwidth = 0.6;

            t = linspace(-1e-6, 1e-6, 512);
            s = p.signal(t);
            testCase.verifyEqual(numel(s), 512);
        end

        function test_signal_peak_at_zero(testCase)
            p = uff.pulse();
            p.center_frequency = 5e6;
            p.fractional_bandwidth = 0.6;

            t = linspace(-1e-6, 1e-6, 1001);
            s = p.signal(t);
            [~, idx_max] = max(s);
            testCase.verifyEqual(t(idx_max), 0, 'AbsTol', 2e-9);
        end

        function test_signal_symmetry(testCase)
            p = uff.pulse();
            p.center_frequency = 5e6;
            p.fractional_bandwidth = 0.6;

            t = linspace(-1e-6, 1e-6, 1000);
            s = p.signal(t);
            s_flipped = p.signal(-t);
            testCase.verifyEqual(s, s_flipped, 'AbsTol', 1e-12);
        end

        function test_signal_decays_away_from_center(testCase)
            p = uff.pulse();
            p.center_frequency = 5e6;
            p.fractional_bandwidth = 0.6;

            s_center = abs(p.signal(0));
            s_far = abs(p.signal(1e-6));
            testCase.verifyGreaterThan(s_center, s_far);
        end
    end

end
