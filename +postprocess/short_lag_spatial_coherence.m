classdef short_lag_spatial_coherence < postprocess
% SHORT LAG SPATIAL COHERENCE (SLSC)
% This process implements the SLSC algorithm as described in 
% Lediju, M. A., Trahey, G. E., Byram, B. C., & Dahl, J. J. (2011). 
% Short-lag spatial coherence of backscattered echoes: Imaging characteristics.
% IEEE Transactions on Ultrasonics, Ferroelectrics, and Frequency Control, 58(7),
% 1377-1388. https://doi.org/10.1109/TUFFC.2011.1957
%
% To use this process, you have to reference the article above, and if you
% use it on cardiac imaging you also have to reference:
% Lediju Bell, M. A., Goswami, R., Kisslo, J. A., Dahl, J. J., & Trahey, 
% G. E. (2013). Short-Lag Spatial Coherence (SLSC) Imaging of Cardiac Ultrasound
% Data: Initial Clinical Results. Ultrasound in Medicine & Biology, 39(10), 
% 1861?1874. https://doi.org/10.1016/j.ultrasmedbio.2013.03.029
%
% Please see our citation policy http://www.ustb.no/citation/.
%
% Please see the example under examples/advanced_beamforming/FI_UFF_short_lag_spatial_coherence
% on how to use it.
% 
% $Last updated: 2017/09/10$
    
    %% constructor
    methods (Access = public)
        function h=short_lag_spatial_coherence()
            h.name='Short Lag Spatial Coherence';
            h.reference= ['Lediju, M. A., Trahey, G. E., Byram, B. C., & Dahl, J. J. (2011). Short-lag spatial coherence of backscattered echoes: Imaging characteristics. IEEE Transactions on Ultrasonics, Ferroelectrics, and Frequency Control, 58(7), 1377?1388. https://doi.org/10.1109/TUFFC.2011.1957'...
                          'Lediju Bell, M. A., Goswami, R., Kisslo, J. A., Dahl, J. J., & Trahey, G. E. (2013). Short-Lag Spatial Coherence (SLSC) Imaging of Cardiac Ultrasound Data: Initial Clinical Results. Ultrasound in Medicine & Biology, 39(10), 1861?1874. https://doi.org/10.1016/j.ultrasmedbio.2013.03.029'];
            h.implemented_by= 'Ole Marius Hoel Rindal <olemarius@olemarius.net>, Muyinatu A. Lediju Bell <mledijubell@jhu.edu>, Dongwoon Hyun <dhyun@stanford.edu>';
            h.version='v1.0.1';
            
            % initialization
            h.receive_apodization=uff.apodization();  % APODIZATION class
            h.transmit_apodization=uff.apodization(); % APODIZATION class
        end
    end
    
    %% Additional properties
    properties
        active_element_criterium=0.16;                % value to decide whether an element is used or not
        K_in_lambda;
        dimension                                     % dimension class that specifies whether the process will run only on transmit, receive, or both.
        maxM
        slsc_values
        channel_data
    end
    
    properties (Access = private)
        K_samples
    end
    
    methods
        function output=go(h)
            % check if we can skip calculation
            if h.check_hash()
                output= h.output; 
                return;
            end
            
            % select default dimension
            if isempty(h.dimension)
                if h.input.N_channels>1 
                    h.dimension=dimension.receive;
                else
                    h.dimension=dimension.transmit;
                end
            end
            
            % select default maxM
            if isempty(h.maxM)
                if h.dimension==dimension.receive
                    h.maxM = round(0.3*h.input.N_channels);
                else
                    h.maxM = round(0.3*h.input.N_waves);
                end
            end
            
            % select default apodization
            assert(h.receive_apodization.window == uff.window.none, 'Please use uff.window.none on receive, thus no apodization, when using the SLSC beamformer.');
            if ~isempty(h.transmit_apodization)
                assert(h.transmit_apodization.window == uff.window.none, 'Please use uff.window.none on transmit, thus no apodization, when using the SLSC beamformer.');
            end
            
            % declare output structure
            h.output=uff.beamformed_data(h.input); % ToDo: instead we should copy everything but the data
               
            if isa(h.input(1).scan,'uff.linear_scan')
                N_axial_pixels = h.input(1).scan.N_z_axis;
                N_lateral_pixels =  h.input(1).scan.N_x_axis;
            elseif isa(h.input(1).scan,'uff.sector_scan')
                N_axial_pixels = h.input(1).scan.N_depth_axis;
                N_lateral_pixels = h.input(1).scan.N_azimuth_axis;
            else
                error('Scan not defined');
            end
            
            
            switch h.dimension
                case dimension.both
                    error('Both dimensions are not defined for SLSC. Consider using transmit or receive dimensions.');
                case dimension.transmit
                    % auxiliary data
                    aux_data=zeros(h.input.N_pixels,h.input.N_channels,1,h.input.N_frames);
                    for n_frame = 1:h.input.N_frames
                        for n_channel = 1:h.input.N_channels
                            data_cube = reshape(h.input.data(:,n_channel,:,n_frame),N_axial_pixels,N_lateral_pixels,h.input.N_waves);
                            [image,slsc_values] = h.short_lag_spatial_coherence_implementation(data_cube);
                            aux_data(:,n_channel,:,n_frame) = image(:);
                        end
                    end
                    h.output.data = aux_data;
                    h.slsc_values = permute(slsc_values,[1 3 2]);
                case dimension.receive
                    % auxiliary data
                    aux_data=zeros(h.input.N_pixels,1,h.input.N_waves,h.input.N_frames);
                    for n_frames = 1:h.input.N_frames
                        for n_wave = 1:h.input.N_waves
                            data_cube = reshape(h.input.data(:,:,n_wave,n_frames),N_axial_pixels,N_lateral_pixels,h.input.N_channels);
                            [image,slsc_values] = h.short_lag_spatial_coherence_implementation(data_cube);
                            aux_data(:,1,n_wave,n_frames) = image(:);
                        end
                    end
                    h.output.data = aux_data;
                    h.slsc_values = permute(slsc_values,[1 3 2]);
                otherwise
                    error('Unknown dimension mode; check HELP dimension');
            end
            
            % pass reference
            output = h.output;
            
            % update hash
            h.save_hash();
        end
        
        function [SLSC_img,slsc_values] = short_lag_spatial_coherence_implementation(h,data_cube)
            %% Calculate the Normalized Spatial Coherence across the receive aperture
            temp_find_idx = squeeze(sum(real(data_cube),1));
            slsc_values = zeros(size(data_cube,1),h.maxM,size(data_cube,2));
            
            for xs = 1:size(data_cube,2)
                idx = abs(temp_find_idx(xs,:))>0;  
                f_i = sum(idx);
                lag = h.makelagmat(1,f_i,h.maxM);
                [~, cc2] =  evalc('mex.slsc_mex(squeeze(real(data_cube(:,xs,idx))),lag,h.K_samples,1);');
                cc2(isnan(cc2)) = 0;
                slsc_values(:,1:size(cc2,2),xs)=cc2;
            end
              
            for M=1:h.maxM
                slsc(:,:,M) = squeeze(sum(slsc_values(:,1:M,:),2));
            end
            
            SLSC_img = slsc(:,:,h.maxM);
            SLSC_img = SLSC_img./max(SLSC_img(:));
        end
        
        function lag = makelagmat(h,numrows,numcols,maxlag)
            % MAKELAGMAT    Generates a cell array containing lag information
            % A matrix that contains the lag number of each element with respect to
            % every other element is output by this function. These values are
            % stored in a NUMROWS*NUMCOLS by NUMROWS*NUMCOLS matrix. The output is a
            % cell array containing the indices from the lag matrix that corresponds to
            % the cell number, i.e. LAG{1} will contain all the indices of points in
            % the lag matrix that are equal to 1, and LAG{2} for those that are equal
            % to 2, etc.
            %
            % LAG = MAKELAGMAT(NUMROWS, NUMCOLS, MAXLAG) will return a cell array of
            % dimensions (MAXLAG, 1). Each cell will contain the indices from the lag
            % matrix that corresponds to the cell number.
            %
            % LAG = MAKELAGMAT(NUMROWS, NUMCOLS) will assume that MAXLAG is set to
            % the maximum possible value.
            
            % Revision History
            % 2011-05-09 dh65
            %   Created function to be used with slsc_mex
            if nargin == 2
                maxlag = round(sqrt(numrows^2+numcols^2))-1;
            end
            
            % Set up temp and lagmat
            temp = false(numrows,numcols);
            lagmat = zeros(numrows*numcols,numrows*numcols,'int32');
            
            % Iterate through every element
            for i = 1:numrows*numcols
                % "Turn on" the element so that bwdist can find all other elements'
                % distances from element i
                temp(i) = 1;
                lagdist = round(bwdist(temp));
                % Store information in lagmat
                lagmat(i,:) = lagdist(:);
                temp(i) = 0;
            end
            clear temp lagdist
            
            % Transfer information from lagmat to lag
            % Only save the upper triangle, since the matrix is symmetric
            lag = cell(maxlag,1);
            for i = 1:maxlag
                lag{i} = int32(find(triu(lagmat) == i));
            end
        end
        
        function h=set.K_in_lambda(h,K_in_lambda)
            assert(~isempty(h.input(1)),'You need to set the beamformed_data input first.')
            assert(~isempty(h.channel_data),'You need to set the channel_data.')
            
            h.K_in_lambda = K_in_lambda;
            if isa(h.input(1).scan,'uff.linear_scan')
                z_in_lambda = h.input(1).scan.z_axis./h.channel_data.lambda;
            elseif isa(h.input(1).scan,'uff.sector_scan')
                z_in_lambda = h.input(1).scan.depth_axis./h.channel_data.lambda;
            else
                error('Unkown scan when setting K in lambda.');
            end
            z_in_lambda = z_in_lambda - z_in_lambda(1);
            [~,samples] = min(abs(z_in_lambda-h.K_in_lambda));
            
            if mod(round(samples),2)    % Check if odd
                h.K_samples = round(samples);
            else
                h.K_samples = round(samples)+1;
            end
        end
    end
end
