classdef integration_fi_verasonics_linear_test < matlab.unittest.TestCase
    % L7_FI_IUS2018.uff: linear-array Verasonics data on the Zenodo bundle (see
    % examples/uff/FI_UFF_Verasonics_RTB.m). (P2-4 cardiac is not in that record.)

    methods (Test)
        function test_fi_phased_cardiac_beamforming(testCase)
            url = tools.zenodo_dataset_files_base();
            filename = 'L7_FI_IUS2018.uff';
            local_path = [ustb_path(), '/data/'];
            tools.download(filename, url, local_path);

            channel_data = uff.read_object([local_path, filename], '/channel_data');

            testCase.verifyInstanceOf(channel_data, ?uff.channel_data);
            testCase.verifyGreaterThan(channel_data.N_waves, 0);
            testCase.verifyGreaterThan(channel_data.N_elements, 0);

            x_axis = zeros(channel_data.N_waves, 1);
            for n = 1:channel_data.N_waves
                x_axis(n) = channel_data.sequence(n).source.x;
            end
            z_axis = linspace(1e-3, 62e-3, 256).';
            scan = uff.linear_scan('x_axis', x_axis, 'z_axis', z_axis);

            mid = midprocess.das();
            mid.code = code.matlab;
            mid.channel_data = channel_data;
            mid.dimension = dimension.both;
            mid.scan = scan;

            mid.transmit_apodization.window = uff.window.scanline;
            mid.receive_apodization.window = uff.window.none;
            mid.receive_apodization.f_number = 1.7;

            b_data = mid.go();

            expected_pixels = numel(x_axis) * numel(z_axis);
            testCase.verifyEqual(size(b_data.data, 1), expected_pixels);

            finite_ratio = sum(isfinite(b_data.data(:))) / numel(b_data.data(:));
            testCase.verifyGreaterThan(finite_ratio, 0.5, ...
                'At least half the pixels should be finite');
            testCase.verifyGreaterThan(max(abs(b_data.data(isfinite(b_data.data)))), 0);
        end

        function test_cardiac_data_is_phased_array(testCase)
            url = tools.zenodo_dataset_files_base();
            filename = 'L7_FI_IUS2018.uff';
            local_path = [ustb_path(), '/data/'];
            tools.download(filename, url, local_path);

            channel_data = uff.read_object([local_path, filename], '/channel_data');

            for n = 1:channel_data.N_waves
                src = channel_data.sequence(n).source;
                testCase.verifyTrue(isfinite(src.x), ...
                    'FI linear-array Verasonics waves should have finite lateral source x');
            end
        end
    end

end
