classdef uff_phantom_test < matlab.unittest.TestCase

    methods (Test)
        function test_default_construction(testCase)
            p = uff.phantom();
            testCase.verifyEqual(p.sound_speed, 1540);
            testCase.verifyEqual(p.density, 1020);
            testCase.verifyEqual(p.alpha, 0.0);
            testCase.verifyEqual(p.time, 0);
        end

        function test_set_points(testCase)
            pts = [0 0 20e-3 1; 5e-3 0 30e-3 0.5];
            p = uff.phantom(pts);

            testCase.verifyEqual(p.N_points, 2);
            testCase.verifyEqual(p.x, [0; 5e-3]);
            testCase.verifyEqual(p.y, [0; 0]);
            testCase.verifyEqual(p.z, [20e-3; 30e-3]);
            testCase.verifyEqual(p.Gamma, [1; 0.5]);
        end

        function test_single_point(testCase)
            pts = [3e-3 4e-3 25e-3 1];
            p = uff.phantom(pts);

            testCase.verifyEqual(p.N_points, 1);
            expected_r = norm([3e-3 4e-3 25e-3]);
            testCase.verifyEqual(p.r, expected_r, 'RelTol', 1e-10);
        end

        function test_constructor_with_all_args(testCase)
            pts = [0 0 20e-3 1];
            p = uff.phantom(pts, 0.5, 1500, 1000, 0.3);

            testCase.verifyEqual(p.time, 0.5);
            testCase.verifyEqual(p.sound_speed, 1500);
            testCase.verifyEqual(p.density, 1000);
            testCase.verifyEqual(p.alpha, 0.3);
        end
    end

end
