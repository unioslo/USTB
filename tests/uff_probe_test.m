classdef uff_probe_test < matlab.unittest.TestCase

    methods (Test)
        function test_linear_array_construction(testCase)
            prb = uff.linear_array();
            prb.N = 128;
            prb.pitch = 300e-6;

            testCase.verifyEqual(prb.N_elements, 128);
        end

        function test_elements_centered_at_origin(testCase)
            prb = uff.linear_array();
            prb.N = 64;
            prb.pitch = 300e-6;

            testCase.verifyEqual(mean(prb.x), 0, 'AbsTol', 1e-12);
        end

        function test_element_spacing_matches_pitch(testCase)
            pitch = 250e-6;
            prb = uff.linear_array();
            prb.N = 32;
            prb.pitch = pitch;

            dx = diff(prb.x);
            testCase.verifyEqual(dx, repmat(pitch, 31, 1), 'AbsTol', 1e-12);
        end

        function test_element_width_defaults_to_pitch(testCase)
            pitch = 300e-6;
            prb = uff.linear_array();
            prb.N = 16;
            prb.pitch = pitch;

            testCase.verifyEqual(prb.element_width, pitch);
        end

        function test_geometry_shape(testCase)
            prb = uff.linear_array();
            prb.N = 64;
            prb.pitch = 300e-6;

            testCase.verifyEqual(size(prb.geometry), [64, 7]);
        end

        function test_elements_on_z_equals_zero(testCase)
            prb = uff.linear_array();
            prb.N = 32;
            prb.pitch = 300e-6;

            testCase.verifyEqual(prb.z, zeros(32, 1));
            testCase.verifyEqual(prb.y, zeros(32, 1));
        end
    end

end
