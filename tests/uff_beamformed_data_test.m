classdef uff_beamformed_data_test < matlab.unittest.TestCase

    methods (Test)
        function test_default_construction(testCase)
            bd = uff.beamformed_data();
            testCase.verifyClass(bd, ?uff.beamformed_data);
        end

        function test_data_dimensions(testCase)
            bd = uff.beamformed_data();
            bd.data = randn(512, 1, 1, 3);

            testCase.verifyEqual(bd.N_pixels, 512);
            testCase.verifyEqual(bd.N_channels, 1);
            testCase.verifyEqual(bd.N_waves, 1);
            testCase.verifyEqual(bd.N_frames, 3);
        end

        function test_get_image_log_shape(testCase)
            scan = uff.linear_scan('x_axis', linspace(-5e-3, 5e-3, 16).', ...
                                   'z_axis', linspace(5e-3, 20e-3, 32).');
            bd = uff.beamformed_data();
            bd.scan = scan;
            bd.data = randn(16 * 32, 1, 1, 1) + 1i * randn(16 * 32, 1, 1, 1);

            img = bd.get_image('log');
            testCase.verifyEqual(size(img), [32, 16]);
        end

        function test_get_image_none_preserves_values(testCase)
            scan = uff.linear_scan('x_axis', linspace(-1e-3, 1e-3, 4).', ...
                                   'z_axis', linspace(1e-3, 4e-3, 8).');
            bd = uff.beamformed_data();
            bd.scan = scan;
            raw = (1:32).';
            bd.data = raw;

            img = bd.get_image('none');
            testCase.verifyEqual(img(:), raw, 'AbsTol', 1e-12);
        end

        function test_scan_assignment(testCase)
            scan = uff.linear_scan('x_axis', linspace(-1e-3, 1e-3, 8).', ...
                                   'z_axis', linspace(0, 5e-3, 16).');
            bd = uff.beamformed_data();
            bd.scan = scan;

            testCase.verifyClass(bd.scan, ?uff.linear_scan);
        end
    end

end
