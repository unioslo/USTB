classdef spherical_transmit_delay_model < int32
%DIMENSION   Enumeration for transmit delay models for when the source is placed in front of the transducer. To see the options available write "tx_delay_model." and press <TAB>.
%
%   See also DAS and examples/uff/FI_UFF_phased_array_MLA_and_RTB_fix.m

%   authors: Ole Marius Hoel Rindal (olemarius@olemarius.net)
%   $Date: 2018/05/20 $
    
   enumeration
      spherical(1)   % This is the standard spherical virtual source model
      unified(2)     % This is the unifed model introduced in Nguyen, N. Q., &
                     % Prager, R. W. (2016). High-Resolution Ultrasound Imaging With Unified Pixel-Based 
                     % Beamforming. IEEE Trans. Med. Imaging, 35(1), 98-108.
      hybrid(3)      % This is our model, a hybrid between the spherical and a plane wave model hopefully publised at IUS 2018
   end
end
