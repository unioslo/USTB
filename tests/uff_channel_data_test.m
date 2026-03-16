classdef uff_channel_data_test < matlab.unittest.TestCase

    methods (Test)
        function test_default_construction(testCase)
            cd = uff.channel_data();
            testCase.verifyClass(cd, ?uff.channel_data);
        end

        function test_default_sound_speed(testCase)
            cd = uff.channel_data();
            testCase.verifyEqual(cd.sound_speed, 1540);
        end

        function test_default_modulation_frequency(testCase)
            cd = uff.channel_data();
            testCase.verifyEqual(cd.modulation_frequency, 0);
        end

        function test_data_dimensions(testCase)
            cd = uff.channel_data();
            cd.data = randn(100, 64, 11, 2);

            testCase.verifyEqual(cd.N_samples, 100);
            testCase.verifyEqual(cd.N_channels, 64);
            testCase.verifyEqual(cd.N_waves, 11);
            testCase.verifyEqual(cd.N_frames, 2);
        end

        function test_single_frame_data(testCase)
            cd = uff.channel_data();
            cd.data = randn(200, 32, 5);

            testCase.verifyEqual(cd.N_samples, 200);
            testCase.verifyEqual(cd.N_channels, 32);
            testCase.verifyEqual(cd.N_waves, 5);
            testCase.verifyEqual(cd.N_frames, 1);
        end

        function test_probe_assignment(testCase)
            prb = uff.linear_array();
            prb.N = 64;
            prb.pitch = 300e-6;

            cd = uff.channel_data();
            cd.probe = prb;
            testCase.verifyEqual(cd.N_elements, 64);
        end
    end

end
