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

        function test_default_origin_at_zero(testCase)
            w = uff.wave();
            testCase.verifyEqual(w.origin.xyz, [0 0 0]);
        end

        %% fix_origin_from_source tests

        function test_fix_origin_focused_wave_sets_xy_from_source(testCase)
            % Focused wave (source in front of transducer, z > 0)
            % Origin should be set to (source.x, source.y, 0)
            w = uff.wave();
            w.wavefront = uff.wavefront.spherical;
            w.source.xyz = [-0.01, 0, 0.03];
            w.origin = uff.point();  % default [0,0,0]

            w.fix_origin_from_source();

            testCase.verifyEqual(w.origin.x, -0.01, 'AbsTol', 1e-10);
            testCase.verifyEqual(w.origin.y, 0, 'AbsTol', 1e-10);
            testCase.verifyEqual(w.origin.z, 0, 'AbsTol', 1e-10);
        end

        function test_fix_origin_diverging_wave_sets_xyz_from_source(testCase)
            % Diverging wave (source behind transducer, z < 0)
            % Origin should be set to full source position
            w = uff.wave();
            w.wavefront = uff.wavefront.spherical;
            w.source.xyz = [-0.01, 0, -0.06];
            w.origin = uff.point();  % default [0,0,0]

            w.fix_origin_from_source();

            testCase.verifyEqual(w.origin.x, -0.01, 'AbsTol', 1e-10);
            testCase.verifyEqual(w.origin.y, 0, 'AbsTol', 1e-10);
            testCase.verifyEqual(w.origin.z, -0.06, 'AbsTol', 1e-10);
        end

        function test_fix_origin_does_not_overwrite_explicit_origin(testCase)
            % If origin was explicitly set to non-zero, don't overwrite
            w = uff.wave();
            w.wavefront = uff.wavefront.spherical;
            w.source.xyz = [-0.01, 0, 0.03];
            w.origin = uff.point();
            w.origin.xyz = [0.005, 0, 0];  % explicitly set

            w.fix_origin_from_source();

            testCase.verifyEqual(w.origin.x, 0.005, 'AbsTol', 1e-10, ...
                'Should not overwrite explicit origin');
        end

        function test_fix_origin_skips_plane_wave(testCase)
            % Plane waves should keep origin at [0,0,0]
            w = uff.wave();
            w.wavefront = uff.wavefront.plane;
            w.source.azimuth = 0.1;
            w.source.distance = Inf;
            w.origin = uff.point();

            w.fix_origin_from_source();

            testCase.verifyEqual(w.origin.xyz, [0 0 0], ...
                'Plane wave origin should stay at zero');
        end

        function test_fix_origin_skips_centered_source(testCase)
            % Source at (0,0,z) — origin should stay at [0,0,0]
            w = uff.wave();
            w.wavefront = uff.wavefront.spherical;
            w.source.xyz = [0, 0, 0.03];
            w.origin = uff.point();

            w.fix_origin_from_source();

            testCase.verifyEqual(w.origin.xyz, [0 0 0], ...
                'On-axis source should not change origin');
        end

        function test_fix_origin_applied_to_fresnel_channel_data(testCase)
            % Fresnel simulator should auto-fix origin on output
            prb = uff.curvilinear_array();
            prb.N = 32;
            prb.pitch = 508e-6;
            prb.element_width = 408e-6;
            prb.radius = 60e-3;

            pul = uff.pulse();
            pul.center_frequency = 3.2e6;
            pul.fractional_bandwidth = 0.6;

            pha = uff.phantom();
            pha.sound_speed = 1540;
            pha.points = [0 0 50e-3 1];

            seq = uff.wave();
            seq.probe = prb;
            seq.source.xyz = [-10e-3, 0, -prb.radius];
            seq.sound_speed = 1540;

            sim = fresnel();
            sim.phantom = pha;
            sim.pulse = pul;
            sim.probe = prb;
            sim.sequence = seq;
            sim.sampling_frequency = 41.6e6;
            ch = sim.go();

            testCase.verifyEqual(ch.sequence(1).origin.x, -10e-3, 'AbsTol', 1e-10, ...
                'Fresnel output should have origin.x set from source');
            testCase.verifyEqual(ch.sequence(1).origin.z, -prb.radius, 'AbsTol', 1e-10, ...
                'Fresnel output should have origin.z set from source');
        end
    end

end
