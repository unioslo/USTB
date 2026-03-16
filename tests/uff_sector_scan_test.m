classdef uff_sector_scan_test < matlab.unittest.TestCase

    methods (Test)
        function test_default_construction(testCase)
            s = uff.sector_scan();
            testCase.verifyClass(s, ?uff.sector_scan);
            testCase.verifyTrue(isa(s, 'uff.scan'));
        end

        function test_axis_dimensions(testCase)
            s = uff.sector_scan();
            s.azimuth_axis = linspace(-pi/6, pi/6, 64).';
            s.depth_axis = linspace(5e-3, 80e-3, 256).';

            testCase.verifyEqual(s.N_azimuth_axis, 64);
            testCase.verifyEqual(s.N_depth_axis, 256);
        end

        function test_pixel_count(testCase)
            s = uff.sector_scan();
            s.azimuth_axis = linspace(-pi/6, pi/6, 32).';
            s.depth_axis = linspace(5e-3, 80e-3, 128).';

            testCase.verifyEqual(s.N_pixels, 32 * 128);
        end

        function test_depth_step(testCase)
            depth_ax = linspace(0, 50e-3, 201).';
            s = uff.sector_scan('azimuth_axis', linspace(-0.5, 0.5, 10).', ...
                                'depth_axis', depth_ax);

            expected_step = 50e-3 / 200;
            testCase.verifyEqual(s.depth_step, expected_step, 'RelTol', 1e-10);
        end

        function test_symmetric_azimuth_gives_symmetric_x(testCase)
            s = uff.sector_scan();
            s.azimuth_axis = linspace(-pi/6, pi/6, 32).';
            s.depth_axis = linspace(10e-3, 50e-3, 64).';

            testCase.verifyEqual(mean(s.x), 0, 'AbsTol', 1e-10);
        end
    end

end
