classdef integration_uff_cpwc_verasonics_test < matlab.unittest.TestCase

    methods (Test)
        function test_uff_read_and_cpwc_beamforming(testCase)
            url = tools.zenodo_dataset_files_base();
            % L7_CPWC_193328 not in current Zenodo deposit; L7_FI_IUS2018 is
            filename = 'L7_FI_IUS2018.uff';
            tools.download(filename, url, data_path);

            channel_data = uff.read_object([data_path filesep filename], '/channel_data');

            testCase.verifyInstanceOf(channel_data, ?uff.channel_data);
            testCase.verifyGreaterThan(channel_data.N_elements, 0);
            testCase.verifyGreaterThan(channel_data.N_waves, 0);
            testCase.verifyFalse(isempty(channel_data.data));

            Nx = 128; Nz = 128;
            scan = uff.linear_scan();
            scan.x_axis = linspace(channel_data.probe.x(1), channel_data.probe.x(end), Nx).';
            scan.z_axis = linspace(0, 50e-3, Nz).';

            mid = midprocess.das();
            mid.code = code.matlab;
            mid.dimension = dimension.both;
            mid.channel_data = channel_data;
            mid.scan = scan;

            mid.transmit_apodization.window = uff.window.none;
            mid.transmit_apodization.f_number = 1.7;

            mid.receive_apodization.window = uff.window.none;
            mid.receive_apodization.f_number = 1.7;

            b_data = mid.go();

            testCase.verifyEqual(size(b_data.data, 1), Nx * Nz);
            testCase.verifyTrue(all(isfinite(b_data.data(:))));

            img_db = 20 * log10(abs(b_data.data(:)) / max(abs(b_data.data(:))));
            dynamic_range = abs(min(img_db(isfinite(img_db))));
            testCase.verifyGreaterThan(dynamic_range, 20);
        end

        function test_uff_channel_data_properties(testCase)
            url = tools.zenodo_dataset_files_base();
            % L7_CPWC_193328 not in current Zenodo deposit; L7_FI_IUS2018 is
            filename = 'L7_FI_IUS2018.uff';
            tools.download(filename, url, data_path);

            channel_data = uff.read_object([data_path filesep filename], '/channel_data');

            testCase.verifyGreaterThan(channel_data.sampling_frequency, 0);
            testCase.verifyGreaterThan(channel_data.sound_speed, 0);
            testCase.verifyInstanceOf(channel_data.probe, ?uff.probe);

            for n = 1:channel_data.N_waves
                testCase.verifyInstanceOf(channel_data.sequence(n), ?uff.wave);
            end
        end
    end

end
