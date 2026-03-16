classdef uff_wave_test < matlab.unittest.TestCase

    methods (Test)
        function test_default_construction(testCase)
            w = uff.wave();
            testCase.verifyClass(w, ?uff.wave);
        end

        function test_default_wavefront_is_spherical(testCase)
            w = uff.wave();
            testCase.verifyEqual(w.wavefront, uff.wavefront.spherical);
        end

        function test_default_source_at_origin(testCase)
            w = uff.wave();
            testCase.verifyClass(w.source, ?uff.point);
            testCase.verifyEqual(w.source.distance, 0);
        end

        function test_default_sound_speed(testCase)
            w = uff.wave();
            testCase.verifyEqual(w.sound_speed, 1540);
        end

        function test_set_plane_wavefront(testCase)
            w = uff.wave();
            w.wavefront = uff.wavefront.plane;
            testCase.verifyEqual(w.wavefront, uff.wavefront.plane);
        end

        function test_plane_wave_with_angle(testCase)
            w = uff.wave();
            w.wavefront = uff.wavefront.plane;
            w.source.azimuth = 0.1;
            w.source.distance = Inf;

            testCase.verifyEqual(w.source.azimuth, 0.1);
            testCase.verifyTrue(isinf(w.source.distance));
        end

        function test_default_delay_is_zero(testCase)
            w = uff.wave();
            testCase.verifyEqual(w.delay, 0);
        end
    end

end
