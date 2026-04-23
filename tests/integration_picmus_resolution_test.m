classdef integration_picmus_resolution_test < matlab.unittest.TestCase

    properties
        tolerance = 0.05;
    end

    methods (Test)
        function test_picmus_beamforming_matches_reference(testCase)
            % Original USTB webhost; file not in the minimal Zenodo bundle for this test.
            url = 'http://ustb.no/datasets/';
            filename = 'PICMUS_simulation_resolution_distortion.uff';
            tools.download(filename, url, data_path);
            filepath = [data_path filesep filename];

            channel_data = uff.read_object(filepath, '/channel_data');
            scan = uff.read_object(filepath, '/scan');
            b_data_ref = uff.read_object(filepath, '/beamformed_data');

            testCase.verifyInstanceOf(channel_data, ?uff.channel_data);
            testCase.verifyInstanceOf(scan, ?uff.scan);
            testCase.verifyFalse(isempty(b_data_ref.data));

            pipe = pipeline();
            pipe.channel_data = channel_data;
            pipe.scan = scan;

            pipe.receive_apodization.window = uff.window.tukey50;
            pipe.receive_apodization.f_number = 1.7;

            pipe.transmit_apodization.window = uff.window.tukey50;
            pipe.transmit_apodization.f_number = 1.7;

            das = midprocess.das();
            das.code = code.matlab;

            b_data_new = pipe.go({das postprocess.coherent_compounding});

            testCase.verifyEqual(size(b_data_new.data), size(b_data_ref.data));

            rel_error = norm(b_data_new.data(:) - b_data_ref.data(:)) / norm(b_data_ref.data(:));
            testCase.verifyLessThan(rel_error, testCase.tolerance);
        end

        function test_picmus_uff_contents(testCase)
            url = 'http://ustb.no/datasets/';
            filename = 'PICMUS_simulation_resolution_distortion.uff';
            tools.download(filename, url, data_path);
            filepath = [data_path filesep filename];

            channel_data = uff.read_object(filepath, '/channel_data');

            testCase.verifyGreaterThan(channel_data.N_waves, 1);
            testCase.verifyGreaterThan(channel_data.N_elements, 0);
            testCase.verifyGreaterThan(channel_data.N_samples, 0);
        end
    end

end
