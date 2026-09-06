classdef integration_fourier_beamforming_sta_test < matlab.unittest.TestCase

    methods (Test)
        function test_sta_fourier_beamforming_pipeline(testCase)
            % Matches examples/Fourier_beamforming/STAI_Fourier_beamforming.m (dataset + preprocessing),
            % with a coarser reconstruction grid so CI completes in reasonable time.
            fn = 'STAI_UFF_CIRS_phantom.uff';
            url = tools.zenodo_record_files_base('19860810');
            tools.download(fn, url, data_path());
            channel_data = uff.read_object(fullfile(data_path(), fn), '/channel_data');

            scan = uff.linear_scan('x_axis', linspace(-20e-3, 20e-3, 256).', ...
                'z_axis', linspace(10e-3, 80e-3, 256).');

            demod = preprocess.demodulation();
            demod.input = channel_data;
            demod.plot_on = false;
            channel_data_demod = demod.go();

            mid_fb = midprocess.Fourier_beamforming();
            mid_fb.channel_data = channel_data_demod;
            mid_fb.scan = scan;
            mid_fb.spatial_padding = 2;
            mid_fb.temporal_padding = 2;
            mid_fb.DAS_consistent = false;
            mid_fb.USTB_scan = false;
            mid_fb.temp_origin = 40e-3;
            mid_fb.angle_apodization = 30;
            w_data = mid_fb.go();
            wa_img = abs(w_data.data(:));
            wa_img = wa_img / max(wa_img);

            mid_dcwa = midprocess.Fourier_beamforming();
            mid_dcwa.channel_data = channel_data_demod;
            mid_dcwa.scan = scan;
            mid_dcwa.spatial_padding = 2;
            mid_dcwa.temporal_padding = 2;
            mid_dcwa.DAS_consistent = true;
            mid_dcwa.USTB_scan = false;
            mid_dcwa.temp_origin = 40e-3;
            mid_dcwa.angle_apodization = 30;
            dcwa_data = mid_dcwa.go();
            dcwa_img = abs(dcwa_data.data(:));
            dcwa_img = dcwa_img / max(dcwa_img);

            mid_das = midprocess.das();
            if isempty(which('das_c'))
                mid_das.code = code.matlab;
            else
                mid_das.code = code.mex;
            end
            mid_das.dimension = dimension.both;
            mid_das.channel_data = channel_data_demod;
            mid_das.scan = w_data.scan;
            apod_angle = 30;
            f_number = cot(deg2rad(apod_angle)) / 2;
            mid_das.transmit_apodization.f_number = f_number;
            mid_das.transmit_apodization.window = uff.window.tukey25;
            mid_das.transmit_apodization.minimum_aperture = [0 0];
            mid_das.transmit_apodization.maximum_aperture = [1e5 1e5];
            mid_das.receive_apodization.f_number = f_number;
            mid_das.receive_apodization.window = uff.window.tukey25;
            mid_das.receive_apodization.minimum_aperture = [0 0];
            mid_das.receive_apodization.maximum_aperture = [1e5 1e5];
            b_data = mid_das.go();
            das_img = abs(b_data.data(:));
            das_img = das_img / max(das_img);

            n_pix = numel(wa_img);
            testCase.verifyEqual(numel(dcwa_img), n_pix);
            testCase.verifyEqual(numel(das_img), n_pix);
            testCase.verifyTrue(all(isfinite(wa_img)));
            testCase.verifyTrue(all(isfinite(dcwa_img)));
            testCase.verifyTrue(all(isfinite(das_img)));

            % DCWA and DAS produce almost equal images; expect strong agreement.
            rho = sum(das_img .* dcwa_img) / (norm(das_img) * norm(dcwa_img) + eps);
            testCase.verifyGreaterThan(rho, 0.85);

            % All three should have a clear global maximum (phantom + speckle).
            testCase.verifyGreaterThan(max(wa_img), 0.5);
            testCase.verifyGreaterThan(max(dcwa_img), 0.5);
            testCase.verifyGreaterThan(max(das_img), 0.5);
        end
    end

end
