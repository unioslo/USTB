classdef svd_filter < preprocess
    % SVD_FILTER Apply SVD spatiotemporal clutter filter to RF Channel Data.
    %   The SVD_FILTER class performs singular value decomposition (SVD) based 
    %   filtering on channel data by decomposing the data and reconstructing it
    %   using a selected subset of singular values.
    %
    %   SVD_FILTER Properties:
    %       cutoff - Defines which singular values to keep in reconstruction
    %           Can be specified as:
    %           * Scalar - Uses singular values from that index to the end
    %           * Two-element vector - Uses singular values within specified range
    %           * Vector - Uses the specified indices for reconstruction
    %
    %   SVD_FILTER Methods:
    %       svd_filter - Create a SVD filter object
    %       go - Apply the SVD filter to input channel data
    %
    %   Example:
    %       % Create filter object
    %       h = svd_filter();
    %       
    %       % Set input data and cutoff
    %       h.input = channel_data_object;
    %       h.cutoff = 5;  % Keep singular values from 5 onwards
    %       
    %       % Apply filter
    %       output = h.go();
    %    
    % Author: 
    %    Demene, C., Deffieux, T., Pernot, M., Osmanski, B.-F., Biran, V., Gennisson, J.-L., Sieu, L.-A., Bergel, A., Franqui, S., Correas, J.-M., Cohen, I., Baud, O., & Tanter, M. 
    %    (2015). Spatiotemporal Clutter Filtering of Ultrafast Ultrasound Data Highly Increases Doppler and fUltrasound Sensitivity. 
    %    IEEE Transactions on Medical Imaging, 34(11), 2271–2285. 
    %    https://doi.org/10.1109/TMI.2015.2428634
    %
    % Implemented for USTB by
    %    Simon Andreas Bjørn 25/09/2024
    %
    % See also PREPROCESS, UFF.CHANNEL_DATA, SVD
    
    % Constructor
    methods
        function h = svd_filter()
        end
    end

    % Properties
    properties
        cutoff
    end

    %% Methods
    methods(Access = public)
        function [output] = go(h)
            % GO Apply SVD filter to input channel data
            %   OUTPUT = GO(H) applies the SVD filter to the input channel data
            %   and returns the filtered data as a channel_data object.
            %
            %   The function performs the following steps:
            %   1. Reshapes input data into a Casorati matrix (space × time)
            %   2. Performs SVD on the autocorrelated matrix
            %   3. Calculates singular vectors
            %   4. Reconstructs filtered data using selected singular values
            %   5. Reshapes result back to original dimensions
            %
            %   Input data is accessed through h.input (uff.channel_data object)
            %   where the last dimension is temporal.
            initsize = size(h.input.data);

            % Assumed temporal dimension is last
            if h.cutoff(end)>initsize(end)
                h.cutoff = h.cutoff(1):initsize(end);
            end

            % Fix cutoff value
            if isscalar(h.cutoff)
                h.cutoff = h.cutoff(1):initsize(end);
            elseif numel(h.cutoff)==2
                h.cutoff = h.cutoff(1):h.cutoff(2);
            end
                

            if or(isequal(h.cutoff,1:initsize(end)),h.cutoff(1)<2)
                h.output = uff.channel_data(h.input); % Just copy over data
                output = h.output;
                return
            end
            
            % Reshape into Casorati matrix. Important to include all
            % dimensions not temporal into one large column vector
            X = reshape(h.input.data,prod(initsize(1:end-1)),initsize(end)); 

            % calculate svd of the autocorrelated matrix
            [U,~] = svd(X'*X);

            % Calculate the singular vectors.
            V = X*U;

            % Singular value decomposition with cutoff in temporal
            % dimension.
            Reconst = V(:,h.cutoff)*U(:,h.cutoff)'; 
            
            h.output = uff.channel_data(h.input);

            % Reconstruction of the final filtered matrix
            h.output.data = reshape(Reconst,initsize);
            output = h.output;
        end
    end

end