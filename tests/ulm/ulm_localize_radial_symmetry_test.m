classdef ulm_localize_radial_symmetry_test < matlab.unittest.TestCase
    % Regression coverage for ulm.localizeRadialSymmetry, the default
    % sub-pixel localization kernel used by ulm.localization2D.

    methods (Test)
        function test_centered_gaussian_returns_zero_offset(testCase)
            I = testCase.gaussianRoi(0, 0, 1.3);
            [zc, xc] = ulm.localizeRadialSymmetry(I, 3, 3);

            testCase.verifyEqual(zc, 0, 'AbsTol', 1e-6);
            testCase.verifyEqual(xc, 0, 'AbsTol', 1e-6);
        end

        function test_recovers_known_subpixel_offset(testCase)
            [zc, xc] = testCase.localize(0.3, -0.2, 1.3);

            testCase.verifyEqual(zc, 0.3, 'AbsTol', 0.02);
            testCase.verifyEqual(xc, -0.2, 'AbsTol', 0.02);
        end

        function test_recovers_offset_beyond_one_pixel(testCase)
            [zc, xc] = testCase.localize(-1.1, 0.6, 1.3);

            testCase.verifyEqual(zc, -1.1, 'AbsTol', 0.02);
            testCase.verifyEqual(xc, 0.6, 'AbsTol', 0.02);
        end

        function test_recovers_small_offset(testCase)
            [zc, xc] = testCase.localize(0.05, 0.05, 1.3);

            testCase.verifyEqual(zc, 0.05, 'AbsTol', 0.01);
            testCase.verifyEqual(xc, 0.05, 'AbsTol', 0.01);
        end

        function test_axial_only_offset_does_not_leak_into_lateral(testCase)
            [zc, xc] = testCase.localize(0.4, 0, 1.3);

            testCase.verifyEqual(zc, 0.4, 'AbsTol', 0.02);
            testCase.verifyEqual(xc, 0, 'AbsTol', 0.02);
        end
    end

    methods (Access = private)
        function I = gaussianRoi(~, dz, dx, sigma)
            N = 9;
            c0 = (N + 1) / 2; % geometric center of an odd-sized ROI
            [xGrid, zGrid] = meshgrid(1:N, 1:N);
            I = exp(-((zGrid - (c0 + dz)).^2 + (xGrid - (c0 + dx)).^2) / (2 * sigma^2));
        end

        function [zc, xc] = localize(testCase, dz, dx, sigma)
            I = testCase.gaussianRoi(dz, dx, sigma);
            [zc, xc] = ulm.localizeRadialSymmetry(I, 3, 3);
        end
    end
end
