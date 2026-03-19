classdef window < int32
    %WINDOW   Enumeration for apodization window functions
    %
    %   WINDOW selects the window function used in UFF.APODIZATION for
    %   receive and transmit weighting.
    %
    %   Values:
    %       uff.window.none          No apodization (all ones)
    %       uff.window.boxcar        Rectangular window (alias: rectangular, flat)
    %       uff.window.hanning       Hanning (raised cosine) window
    %       uff.window.hamming       Hamming window
    %       uff.window.tukey25       Tukey window (25% roll-off)
    %       uff.window.tukey50       Tukey window (50% roll-off)
    %       uff.window.tukey75       Tukey window (75% roll-off)
    %       uff.window.sta           Single-element (STA) apodization
    %       uff.window.scanline      Scanline-based MLA apodization
    %       uff.window.triangle      Triangular (Bartlett) window
    %
    %   See also UFF.APODIZATION
    
    %   authors: Alfonso Rodriguez-Molares (alfonso.r.molares@ntnu.no)
    %   $Date: 2017/03/07 $
    
   enumeration
      none(0)           % No apodization
      boxcar(1)         % Rectangular window
      rectangular(1)    % Rectangular window (alias)
      flat(1)           % Rectangular window (alias)
      hanning(2)        % Hanning window
      hamming(3)        % Hamming window
      tukey25(4)        % Tukey window, 25% roll-off
      tukey50(5)        % Tukey window, 50% roll-off
      tukey75(6)        % Tukey window, 75% roll-off
      sta(7)            % Single-element transmit apodization
      scanline(8)       % Scanline-based MLA apodization
      triangle(9)       % Triangular (Bartlett) window
   end
end
