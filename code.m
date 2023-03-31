classdef code < int32
%CODE   Enumeration class for code implementation types. 
%To see the options available write "code." and press <TAB>.
%
%   See also PROCESS
%
%   authors: Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>
%            Stefano Fiorentini <stefano.fiorentini@ntnu.no>
%
%   $Last Update: 01/02/2023 $
    
   enumeration
      matlab(0)
      mex(1)
      matlab_gpu(3)
      mex_gpu(4)
   end
end
