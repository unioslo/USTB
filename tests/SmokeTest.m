classdef SmokeTest < matlab.unittest.TestCase

    methods (Test)
        function testUstbPathExists(testCase)
            p = ustb_path();
            testCase.verifyTrue(isfolder(p), ...
                'ustb_path() should return a valid directory');
        end

        function testUffScanClassExists(testCase)
            s = uff.scan();
            testCase.verifyClass(s, ?uff.scan);
        end
    end

end
