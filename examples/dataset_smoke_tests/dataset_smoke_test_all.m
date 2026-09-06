function varargout = dataset_smoke_test_all(varargin)
%DATASET_SMOKE_TEST_ALL  Compatibility wrapper for RUN_DATASET_SMOKE_TESTS.
%
%   See RUN_DATASET_SMOKE_TESTS.

if nargout > 0
    [varargout{1:nargout}] = run_dataset_smoke_tests(varargin{:});
else
    run_dataset_smoke_tests(varargin{:});
end
end
