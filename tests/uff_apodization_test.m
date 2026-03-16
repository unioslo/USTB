classdef uff_apodization_test < matlab.unittest.TestCase

    methods (Test)
        function test_default_construction(testCase)
            apo = uff.apodization();
            testCase.verifyClass(apo, ?uff.apodization);
        end

        function test_default_window_is_none(testCase)
            apo = uff.apodization();
            testCase.verifyEqual(apo.window, uff.window.none);
        end

        function test_default_f_number(testCase)
            apo = uff.apodization();
            testCase.verifyEqual(apo.f_number, [1, 1]);
        end

        function test_set_window_types(testCase)
            apo = uff.apodization();

            apo.window = uff.window.hamming;
            testCase.verifyEqual(apo.window, uff.window.hamming);

            apo.window = uff.window.hanning;
            testCase.verifyEqual(apo.window, uff.window.hanning);

            apo.window = uff.window.boxcar;
            testCase.verifyEqual(apo.window, uff.window.boxcar);

            apo.window = uff.window.tukey25;
            testCase.verifyEqual(apo.window, uff.window.tukey25);
        end

        function test_set_f_number(testCase)
            apo = uff.apodization();
            apo.f_number = [1.75, 1.75];
            testCase.verifyEqual(apo.f_number, [1.75, 1.75]);
        end

        function test_probe_assignment(testCase)
            prb = uff.linear_array();
            prb.N = 64;
            prb.pitch = 300e-6;

            apo = uff.apodization();
            apo.probe = prb;
            testCase.verifyClass(apo.probe, ?uff.linear_array);
        end
    end

end
