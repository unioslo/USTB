classdef generalized_coherence_factor_OMHR < postprocess
    %GENERALIZED COHERENCE FACTOR MATLAB implementation of the Generalized
    % Coherence Factor
    %
    %   MATLAB implementation of the Generalized Coherence Factor
    %   method as described in the paper:
    %
    %   Li, P. C., & Li, M. L. (2003). Adaptive imaging using the generalized
    %   coherence factor. IEEE Transactions on Ultrasonics, Ferroelectrics, and 
    %   Frequency Control, 50(2), 128?141. https://doi.org/10.1109/TUFFC.2003.1182117
    %
    %   The implementation computes coherence either on transmit, receive.
    %   Use dimension do decide wihich.
    %
    %   implementers: Ole Marius Hoel Rindal <olemarius@olemarius.net>
    %                 Andreas Austeng <AndreasAusteng@ifi.uio.no>
    %
    %   $Last updated: 2017/05/05$
    
    %% constructor
    methods (Access = public)
        function h=generalized_coherence_factor_OMHR()
            h.name='Generalized Coherence Factor MATLAB';
            h.reference={'Li, P. C., & Li, M. L. (2003). Adaptive imaging using the generalized coherence factor. IEEE Transactions on Ultrasonics, Ferroelectrics, and Frequency Control, 50(2), 128?141. https://doi.org/10.1109/TUFFC.2003.1182117'};
            h.implemented_by={'Ole Marius Hoel Rindal <olemarius@olemarius.net>','Andreas Austeng <AndreasAusteng.ifi.uio.no'};
            h.version='v1.0.2';
        end
    end
    
    %% Additional properties
    properties
        M0 = 2;                                       % Low frequency region
        channel_data                                  % Need the probe 
        GCF                                           % BEAMFORMED_DATA class with the computed phase coherent factor
        dimension = dimension.both;                   % dimension class that specifies whether the process will run only on transmit, receive, or both.
    end
    
    methods
        function [output]=go(h)
            % check if we can skip calculation
            if h.check_hash()
                output = h.output; 
                return;
            end         
            
            % check dimensions
            if (h.dimension==dimension.receive) && (h.input.N_channels<2)
                error('Not enough channels to compute factor');
            end
            if (h.dimension==dimension.transmit) && (h.input.N_waves<2)
                error('Not enough waves to compute factor');
            end
            if (h.dimension==dimension.both) 
                if (h.input.N_channels<2)&&(h.input.N_waves>1)
                    warning('Not enough channels to compute factor. Changing dimension to dimension.transmit');
                    h.dimension = dimension.transmit;
                elseif (h.input.N_waves<2)&&(h.input.N_channels>1)
                    warning('Not enough waves to compute factor. Changing dimension to dimension.receive');
                    h.dimension = dimension.receive;
                elseif (h.input.N_waves<2)&&(h.input.N_channels<2)
                    error('Not enough waves and channels to compute factor');
                end
            end
            
            % check if we have information about apodization
            rx_apodization=ones([h.input(1).N_pixels,h.input.N_channels]);
            tx_apodization=ones([h.input(1).N_pixels,h.input.N_waves]);
            if ~isempty(h.transmit_apodization)&~isempty(h.receive_apodization)&~isempty(h.channel_data.probe)
                % receive
                if h.input.N_channels > 1
                    h.receive_apodization.probe=h.channel_data.probe;
                    rx_apodization=h.receive_apodization.data();
                end
                
                % transmit
                if h.input.N_waves > 1
                    h.transmit_apodization.sequence = h.channel_data.sequence;
                    h.transmit_apodization.probe=h.channel_data.probe;
                    tx_apodization=h.transmit_apodization.data();
                end
            else
                warning('Missing probe and apodization data; full aperture is assumed.');
            end

            % declare output structure
            h.output=uff.beamformed_data(h.input); % ToDo: instead we should copy everything but the data
            h.GCF=uff.beamformed_data(h.input); % ToDo: instead we should copy everything but the data

            
            switch h.dimension
                case dimension.both
                    str = ['You are trying to run the Generalized Coherence Factor beamformer on both dimensions simultaneously. ',...
                           'This is to my knowledge not been done in the litterature before, and might not make sense. ',...
                           'I also takes forever...'];
                    warning(str);

                    % auxiliary data
                    aux_data=zeros(h.input.N_pixels,1,1,h.input.N_frames);
                    GCF_weights=zeros(h.input.N_pixels,1,1,h.input.N_frames);
                    for n_frame = 1:h.input.N_frames
                        apod_matrix = zeros(size(tx_apodization,1),h.input.N_waves*h.input.N_channels);
                        for i = 1:h.input.N_waves
                            apod_matrix(:,1+(i-1)*h.input.N_channels:h.input.N_channels*i) = tx_apodization(:,i).*rx_apodization;
                        end
                        apod_matrix = reshape(apod_matrix,h.input(1).scan.N_z_axis,h.input(1).scan.N_x_axis,h.input.N_waves*h.input.N_channels);
%                     
                        % Apodization matrix indicating active elements
                        %apod_matrix = reshape(bsxfun(@times,tx_apodization,rx_apodization(n_channel)),h.input(1).scan.N_z_axis,h.input(1).scan.N_x_axis,h.input.N_waves);
                        data_cube = reshape(h.input.data(:,:,:,n_frame),h.input(1).scan.N_z_axis,h.input(1).scan.N_x_axis,h.input.N_channels*h.input.N_waves);
                        GCF = h.generalized_coherence_factor_implementation(data_cube, apod_matrix,h.M0);
                        image = sum(data_cube,3).*GCF;  
                        GCF_weights(:,1,1,n_frame) = GCF(:);
                        aux_data(:,1,1,n_frame) = image(:);
                    end
                    h.output.data = aux_data;
                case dimension.transmit
                    % auxiliary data
                    aux_data=zeros(h.input.N_pixels,h.input.N_channels,1,h.input.N_frames);
                    GCF_weights=zeros(h.input.N_pixels,h.input.N_channels,1,h.input.N_frames);
                    for n_frame = 1:h.input.N_frames
                        for n_channel = 1:h.input.N_channels
                            % Apodization matrix indicating active elements
                            apod_matrix = reshape(bsxfun(@times,tx_apodization,rx_apodization(n_channel)),h.input(1).scan.N_z_axis,h.input(1).scan.N_x_axis,h.input.N_waves);
                            data_cube = reshape(h.input.data(:,n_channel,:,n_frame),h.input(1).scan.N_z_axis,h.input(1).scan.N_x_axis,h.input.N_waves);
                            GCF = h.generalized_coherence_factor_implementation(data_cube, apod_matrix,h.M0);
                            image = sum(data_cube,3).*GCF;
                            GCF_weights(:,n_channel,:,n_frame) = GCF(:);     
                            aux_data(:,n_channel,:,n_frame) = image(:);
                        end
                    end
                    h.GCF = GCF_weights;
                    h.output.data = aux_data;
                case dimension.receive
                    % auxiliary data
                    aux_data=zeros(h.input.N_pixels,1,h.input.N_waves,h.input.N_frames);
                    GCF_weights=zeros(h.input.N_pixels,1,h.input.N_waves,h.input.N_frames);
                    for n_frame = 1:h.input.N_frames
                        for n_wave = 1:h.input.N_waves
                            % Apodization matrix indicating active elements
                            apod_matrix = reshape(bsxfun(@times,tx_apodization(:,n_wave),rx_apodization),h.input(1).scan.N_z_axis,h.input(1).scan.N_x_axis,h.input.N_channels);
                            data_cube = reshape(h.input.data(:,:,n_wave,n_frame),h.input(1).scan.N_z_axis,h.input(1).scan.N_x_axis,h.input.N_channels);
                            %A hack to set non active elements to zero for the
                            %alpinion scanner FI who only use 64 active
                            %elements
%                            if ~isempty(h.channel_data.N_active_elements) && sum(h.channel_data.N_active_elements ~= h.channel_data.N_elements)
 %                               apod_matrix(abs(data_cube)<eps) = 0;
  %                          end
                            GCF = h.generalized_coherence_factor_implementation(data_cube, apod_matrix,h.M0);
                            image = sum(data_cube,3).*GCF;
                            GCF_weights(:,1,n_wave,n_frame) = GCF(:);
                            aux_data(:,1,n_wave,n_frame) = image(:);
                        end
                    end
                     h.GCF.data = GCF_weights;
                    h.output.data = aux_data;
                otherwise
                    error('Unknown dimension mo de; check HELP dimension');
            end
            
            % pass reference
            output = h.output;
            
            % update hash
            h.save_hash();
        end
        
        function GCFweights = generalized_coherence_factor_implementation(h,data_cube, apod_matrix,M0)
            GCFweights = zeros(size(data_cube,1),size(data_cube,2));
            
            for zs = 1:size(data_cube,1)
                for xs = 1:size(data_cube,2)
                    % Find active channels
                    active_channels = squeeze(data_cube(zs,xs,logical(squeeze(apod_matrix(zs,xs,:)))));
                    if sum(apod_matrix(zs,xs,:)) > M0
                        K = length(active_channels);
                        dataFFT = fft(active_channels);
                        if M0 > 1
                            indToSumFFT = [1:M0+1 K-M0+1:K];
                        else
                            indToSumFFT = 1;
                        end
                        
                        GCFweights(zs,xs) = sum(abs(dataFFT(indToSumFFT)).^2) ./ (sum(abs(dataFFT).^2));
                    else
                        GCFweights(zs,xs) = 0;
                    end
                end
            end
            
        end
    end
end
        
        
        
