classdef code < int32
%code   Enumeration for code implementation types. To see the options available write "code." and press <TAB>.
%
%   See also PROCESS

%   authors: Alfonso Rodriguez-Molares (alfonso.r.molares@ntnu.no)
%   $Date: 2017/09/22 $
    
   enumeration
      matlab(0)
      mex(1)
      matlab_gpu(2)
      mex_gpu(3)
   end
end
