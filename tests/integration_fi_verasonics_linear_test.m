classdef integration_fi_phased_cardiac_test < matlab.unittest.TestCase

    methods (Test)
        function test_fi_phased_cardiac_beamforming(testCase)
            url = tools.zenodo_dataset_files_base();
            filename = 'Verasonics_P2-4_parasternal_long_small.uff';
            local_path = [ustb_path(), '/data/'];
            tools.download(filename, url, local_path);

            channel_data = uff.read_object([local_path, filename], '/channel_data');

            testCase.verifyInstanceOf(channel_data, ?uff.channel_data);
            testCase.verifyGreaterThan(channel_data.N_waves, 0);
            testCase.verifyGreaterThan(channel_data.N_elements, 0);

            depth_axis = linspace(0e-3, 110e-3, 256).';
            azimuth_axis = zeros(channel_data.N_waves, 1);
            for n = 1:channel_data.N_waves
                azimuth_axis(n) = channel_data.sequence(n).source.azimuth;
            end

            scan = uff.sector_scan('azimuth_axis', azimuth_axis, ...
                                   'depth_axis', depth_axis);

            mid = midprocess.das();
            mid.code = code.matlab;
            mid.channel_data = channel_data;
            mid.dimension = dimension.both;
            mid.scan = scan;

            mid.transmit_apodization.window = uff.window.scanline;

            mid.receive_apodization.window = uff.window.tukey25;
            mid.receive_apodization.f_number = 1.7;

            b_data = mid.go();

            expected_pixels = numel(azimuth_axis) * numel(depth_axis);
            testCase.verifyEqual(size(b_data.data, 1), expected_pixels);

            finite_ratio = sum(isfinite(b_data.data(:))) / numel(b_data.data(:));
            testCase.verifyGreaterThan(finite_ratio, 0.5, ...
                'At least half the pixels should be finite');
            testCase.verifyGreaterThan(max(abs(b_data.data(isfinite(b_data.data)))), 0);
        end

        function test_cardiac_data_is_phased_array(testCase)
            url = tools.zenodo_dataset_files_base();
            filename = 'Verasonics_P2-4_parasternal_long_small.uff';
            local_path = [ustb_path(), '/data/'];
            tools.download(filename, url, local_path);

            channel_data = uff.read_object([local_path, filename], '/channel_data');

            for n = 1:channel_data.N_waves
                src = channel_data.sequence(n).source;
                testCase.verifyTrue(isfinite(src.azimuth), ...
                    'FI phased array waves should have finite azimuth angles');
            end
        end
    end

end
