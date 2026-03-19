classdef dimension < int32
    %DIMENSION   Enumeration for selecting the beamforming dimension
    %
    %   DIMENSION specifies which dimensions of the DAS beamformer to sum
    %   over. This controls whether the Generalized Beamformer sums over
    %   receive channels (Rx), transmit events (Tx), both, or none.
    %
    %   Values:
    %       dimension.none        No summation; returns delayed data
    %       dimension.receive     Sum over Rx only, as in Eq. (24)
    %       dimension.transmit    Sum over Tx only, as in Eq. (26)
    %       dimension.both        Sum over both Rx and Tx, as in Eq. (2)
    %
    %   Example:
    %       mid = midprocess.das();
    %       mid.dimension = dimension.both;
    %
    %   See also MIDPROCESS.DAS, CODE
    %
    %   References:
    %       Rindal et al., "The Generalized Beamformer", 2025
    
    %   authors: Alfonso Rodriguez-Molares (alfonso.r.molares@ntnu.no)
    %   $Date: 2017/09/22 $
    
   enumeration
      none(0)       % No summation; returns delayed data
      receive(1)    % Sum over receive channels (Rx dimension)
      transmit(2)   % Sum over transmit events (Tx dimension)
      both(3)       % Sum over both Rx and Tx dimensions
   end
end
