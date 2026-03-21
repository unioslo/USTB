classdef code < int32
    %CODE   Enumeration for selecting the beamformer implementation
    %
    %   CODE specifies which implementation of the DAS beamformer to use.
    %
    %   Values:
    %       code.matlab       Pure MATLAB implementation
    %       code.mex          MEX C implementation (default, faster)
    %       code.matlab_gpu   MATLAB GPU implementation
    %       code.mex_gpu      MEX CUDA GPU implementation
    %
    %   Example:
    %       mid = midprocess.das();
    %       mid.code = code.matlab;
    %
    %   See also MIDPROCESS.DAS, DIMENSION
    %
    %   authors: Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>
    %            Stefano Fiorentini <stefano.fiorentini@ntnu.no>
    %
    %   $Last Update: 01/02/2023 $
    
   enumeration
      matlab(0)      % Pure MATLAB implementation
      mex(1)         % MEX C implementation
      matlab_gpu(3)  % MATLAB GPU implementation
      mex_gpu(4)     % MEX CUDA GPU implementation
   end
end
