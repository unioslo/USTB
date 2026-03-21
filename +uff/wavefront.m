classdef wavefront < int32
    %WAVEFRONT   Enumeration for transmitted wave types
    %
    %   WAVEFRONT selects the type of wave emitted by the transducer.
    %
    %   Values:
    %       uff.wavefront.plane          Plane wave (steered by source angles)
    %       uff.wavefront.spherical      Spherical wave (diverging or focused)
    %       uff.wavefront.photoacoustic  Photoacoustic (no transmit wave)
    %
    %   See also UFF.WAVE, UFF.POINT
    
    %   authors: Alfonso Rodriguez-Molares (alfonso.r.molares@ntnu.no)
    %   $Lat updated: 2017/10/13 $
    
   enumeration
      plane(0)          % Plane wave
      spherical(1)      % Spherical (diverging or focused) wave
      photoacoustic(2)  % Photoacoustic acquisition
   end
end
