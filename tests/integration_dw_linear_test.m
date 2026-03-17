classdef integration_dw_linear_test < matlab.unittest.TestCase

    methods (Test)
        function test_dw_pipeline_produces_image(testCase)
            pha = uff.phantom();
            pha.sound_speed = 1540;
            pha.points = [0, 0, 20e-3, 1];

            prb = uff.linear_array();
            prb.N = 128;
            prb.pitch = 300e-6;
            prb.element_width = 270e-6;
            prb.element_height = 5000e-6;

            pul = uff.pulse();
            pul.center_frequency = 5.2e6;
            pul.fractional_bandwidth = 0.6;

            N = 31;
            x0 = linspace(-19.2e-3, 19.2e-3, N);
            z0 = -20e-3;
            seq = uff.wave();
            for n = 1:N
                seq(n) = uff.wave();
                seq(n).probe = prb;
                seq(n).source.xyz = [x0(n) 0 z0];
                seq(n).sound_speed = pha.sound_speed;
            end

            sim = fresnel();
            sim.phantom = pha;
            sim.pulse = pul;
            sim.probe = prb;
            sim.sequence = seq;
            sim.sampling_frequency = 41.6e6;
            channel_data = sim.go();

            Nx = 100; Nz = 100;
            scan = uff.linear_scan('x_axis', linspace(-5e-3, 5e-3, Nx).', ...
                                   'z_axis', linspace(15e-3, 25e-3, Nz).');

            mid = midprocess.das();
            mid.code = code.matlab;
            mid.dimension = dimension.both;
            mid.channel_data = channel_data;
            mid.scan = scan;

            mid.receive_apodization.window = uff.window.hanning;
            mid.receive_apodization.f_number = 1.7;
            mid.receive_apodization.minimum_aperture = [3e-3 3e-3];

            mid.transmit_apodization.window = uff.window.hanning;
            mid.transmit_apodization.f_number = 1.7;
            mid.transmit_apodization.minimum_aperture = [3e-3 3e-3];

            b_data = mid.go();

            testCase.verifyEqual(numel(b_data.data(:)), Nx * Nz);
            testCase.verifyTrue(all(isfinite(b_data.data(:))));

            [~, idx] = max(abs(b_data.data));
            peak_x = scan.x(idx);
            peak_z = scan.z(idx);
            testCase.verifyEqual(peak_x, 0, 'AbsTol', 2e-3);
            testCase.verifyEqual(peak_z, 20e-3, 'AbsTol', 2e-3);
        end
    end

end
