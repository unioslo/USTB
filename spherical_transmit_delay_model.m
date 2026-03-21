classdef spherical_transmit_delay_model < int32
    %SPHERICAL_TRANSMIT_DELAY_MODEL   Enumeration for transmit delay models
    %
    %   SPHERICAL_TRANSMIT_DELAY_MODEL selects the model used to calculate
    %   the transmit distance T(x) when the virtual source is in front of
    %   the transducer (focused imaging). The standard spherical model has
    %   a discontinuity at the sides of the focal point; the hybrid and
    %   unified models address this.
    %
    %   Values:
    %       spherical_transmit_delay_model.spherical   Standard virtual source model, Eq. (7)
    %       spherical_transmit_delay_model.unified     Unified model from Nguyen & Prager (2016)
    %       spherical_transmit_delay_model.hybrid      Hybrid spherical/plane model (default)
    %       spherical_transmit_delay_model.blended     Blended spherical/plane model
    %
    %   Example:
    %       mid = midprocess.das();
    %       mid.spherical_transmit_delay_model = spherical_transmit_delay_model.hybrid;
    %
    %   See also MIDPROCESS.DAS, CODE, DIMENSION
    %
    %   References:
    %       Nguyen & Prager, "High-Resolution Ultrasound Imaging With Unified
    %       Pixel-Based Beamforming", IEEE TMI, vol. 35(1), pp. 98-108, 2016
    %
    %       Rindal et al., "A simple, artifact-free, virtual source model",
    %       IEEE IUS, 2018
    
    %   authors: Ole Marius Hoel Rindal (olemarius@olemarius.net)
    %   $Date: 2018/05/20 $
    
   enumeration
      spherical(1)   % Standard spherical virtual source model
      unified(2)     % Unified model (Nguyen & Prager, 2016)
      hybrid(3)      % Hybrid spherical/plane wave model (default)
      blended(4)     % Blended spherical/plane wave model
   end
end
