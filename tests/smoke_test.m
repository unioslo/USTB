classdef smoke_test < matlab.unittest.TestCase

    methods (Test)
        function test_ustb_path_exists(testCase)
            p = ustb_path();
            testCase.verifyTrue(isfolder(p), ...
                'ustb_path() should return a valid directory');
        end

        function test_uff_scan_class_exists(testCase)
            s = uff.scan();
            testCase.verifyClass(s, ?uff.scan);
        end
    end

end
