classdef uff_linear_scan_test < matlab.unittest.TestCase

    methods (Test)
        function test_default_construction(testCase)
            s = uff.linear_scan();
            testCase.verifyClass(s, ?uff.linear_scan);
            testCase.verifyTrue(isa(s, 'uff.scan'));
        end

        function test_axis_dimensions(testCase)
            s = uff.linear_scan();
            s.x_axis = linspace(-10e-3, 10e-3, 128).';
            s.z_axis = linspace(5e-3, 40e-3, 256).';

            testCase.verifyEqual(s.N_x_axis, 128);
            testCase.verifyEqual(s.N_z_axis, 256);
        end

        function test_pixel_count(testCase)
            s = uff.linear_scan();
            s.x_axis = linspace(-10e-3, 10e-3, 64).';
            s.z_axis = linspace(5e-3, 40e-3, 128).';

            testCase.verifyEqual(s.N_pixels, 64 * 128);
        end

        function test_step_sizes(testCase)
            x_ax = linspace(-10e-3, 10e-3, 101).';
            z_ax = linspace(0, 50e-3, 201).';
            s = uff.linear_scan('x_axis', x_ax, 'z_axis', z_ax);

            expected_x_step = 20e-3 / 100;
            expected_z_step = 50e-3 / 200;
            testCase.verifyEqual(s.x_step, expected_x_step, 'RelTol', 1e-10);
            testCase.verifyEqual(s.z_step, expected_z_step, 'RelTol', 1e-10);
        end

        function test_pixel_positions_cover_axes(testCase)
            x_ax = linspace(-5e-3, 5e-3, 10).';
            z_ax = linspace(10e-3, 20e-3, 20).';
            s = uff.linear_scan('x_axis', x_ax, 'z_axis', z_ax);

            testCase.verifyEqual(min(s.x), -5e-3, 'AbsTol', 1e-12);
            testCase.verifyEqual(max(s.x), 5e-3, 'AbsTol', 1e-12);
            testCase.verifyEqual(min(s.z), 10e-3, 'AbsTol', 1e-12);
            testCase.verifyEqual(max(s.z), 20e-3, 'AbsTol', 1e-12);
        end

        function test_named_parameter_construction(testCase)
            s = uff.linear_scan('x_axis', linspace(-1e-3, 1e-3, 16).', ...
                                'z_axis', linspace(0, 10e-3, 32).');
            testCase.verifyEqual(s.N_x_axis, 16);
            testCase.verifyEqual(s.N_z_axis, 32);
            testCase.verifyEqual(s.N_pixels, 16 * 32);
        end

        function test_y_defaults_to_zero(testCase)
            s = uff.linear_scan('x_axis', linspace(-1e-3, 1e-3, 8).', ...
                                'z_axis', linspace(0, 5e-3, 8).');
            testCase.verifyTrue(all(s.y == 0));
        end
    end

end
