classdef uff_window_test < matlab.unittest.TestCase

    methods (Test)
        function test_all_enum_values_exist(testCase)
            testCase.verifyClass(uff.window.none, ?uff.window);
            testCase.verifyClass(uff.window.boxcar, ?uff.window);
            testCase.verifyClass(uff.window.hanning, ?uff.window);
            testCase.verifyClass(uff.window.hamming, ?uff.window);
            testCase.verifyClass(uff.window.tukey25, ?uff.window);
            testCase.verifyClass(uff.window.tukey50, ?uff.window);
            testCase.verifyClass(uff.window.tukey75, ?uff.window);
            testCase.verifyClass(uff.window.sta, ?uff.window);
            testCase.verifyClass(uff.window.scanline, ?uff.window);
            testCase.verifyClass(uff.window.triangle, ?uff.window);
        end

        function test_boxcar_rectangular_flat_are_equal(testCase)
            testCase.verifyEqual(uff.window.boxcar, uff.window.rectangular);
            testCase.verifyEqual(uff.window.boxcar, uff.window.flat);
        end

        function test_none_differs_from_boxcar(testCase)
            testCase.verifyNotEqual(uff.window.none, uff.window.boxcar);
        end

        function test_enum_comparison(testCase)
            w = uff.window.hamming;
            testCase.verifyTrue(w == uff.window.hamming);
            testCase.verifyFalse(w == uff.window.hanning);
        end
    end

end
