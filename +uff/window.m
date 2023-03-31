classdef window < int32
%window   Enumeration for window types. To see the options available write "window." and press <TAB>.
%
%   See also PULSE, BEAM, PHANTOM, PROBE

%   authors: Alfonso Rodriguez-Molares (alfonso.r.molares@ntnu.no)
%   $Date: 2017/03/07 $
    
   enumeration
      none(0)
      boxcar(1)
      rectangular(1)
      flat(1)
      hanning(2) 
      hamming(3)
      tukey25(4) 
      tukey50(5) 
      tukey75(6)
      tukey80(7)
      sta(7)
      scanline(8)
   end
end
