classdef uff_point_test < matlab.unittest.TestCase

    methods (Test)
        function test_default_construction(testCase)
            p = uff.point();
            testCase.verifyEqual(p.distance, 0);
            testCase.verifyEqual(p.azimuth, 0);
            testCase.verifyEqual(p.elevation, 0);
        end

        function test_xyz_at_origin(testCase)
            p = uff.point();
            testCase.verifyEqual(p.x, 0);
            testCase.verifyEqual(p.y, 0);
            testCase.verifyEqual(p.z, 0);
        end

        function test_set_xyz_roundtrip(testCase)
            p = uff.point();
            p.xyz = [5e-3, 0, 20e-3];
            testCase.verifyEqual(p.x, 5e-3, 'AbsTol', 1e-10);
            testCase.verifyEqual(p.y, 0, 'AbsTol', 1e-10);
            testCase.verifyEqual(p.z, 20e-3, 'AbsTol', 1e-10);
        end

        function test_distance_from_xyz(testCase)
            p = uff.point();
            p.xyz = [3e-3, 4e-3, 0];
            testCase.verifyEqual(p.distance, 5e-3, 'AbsTol', 1e-10);
        end

        function test_set_individual_coordinates(testCase)
            p = uff.point();
            p.xyz = [10e-3, 0, 30e-3];
            expected_dist = norm([10e-3, 0, 30e-3]);
            testCase.verifyEqual(p.distance, expected_dist, 'AbsTol', 1e-10);
        end

        function test_azimuth_from_xyz(testCase)
            p = uff.point();
            p.xyz = [0, 0, 20e-3];
            testCase.verifyEqual(p.azimuth, 0, 'AbsTol', 1e-10);
        end

        function test_point_on_x_axis(testCase)
            p = uff.point();
            p.xyz = [10e-3, 0, 0];
            testCase.verifyEqual(p.azimuth, pi/2, 'AbsTol', 1e-10);
            testCase.verifyEqual(p.distance, 10e-3, 'AbsTol', 1e-10);
        end

        function test_negative_distance_flips_sign(testCase)
            p = uff.point();
            p.distance = -5e-3;
            testCase.verifyEqual(p.distance, 5e-3);
        end

        function test_named_parameter_construction(testCase)
            p = uff.point('distance', 20e-3, 'azimuth', 0.1);
            testCase.verifyEqual(p.distance, 20e-3);
            testCase.verifyEqual(p.azimuth, 0.1);
        end
    end

end
