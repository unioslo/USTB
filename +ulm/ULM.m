classdef ULM < handle
    %ULM Summary of this class goes here
    %   Detailed explanation goes here
    %
    %  Implemented by Simon Andreas Bjørn <simonabj@ifi.uio.no>
    
    properties
        input
        scan
        lambda

        numberOfFrames = []      % Only needed if input is [].
        framerate = 60
        scale = [1 1]            % Scaling factor for ULM. Default [1 1]
        resolution = 10          % Resolution factor. Default 10 for images at lambda/10
        interp_factor = 1/10     % Interpolation factor. Default 1/resolution, given resolution = 10.
        max_linking_distance = 2 % Maximum linking distance between two frames to reject pairing, in pixels. (2-4 pixel).
        numberOfParticles = 70   % Expected number of particles per frame
        min_length = 15          % Minimum length of the tracks
        fwhm = [3 3]             % Size of the mask for localization. (3x3 for pixel at lambda, 5x5 at lambda/2). [fwhmz fwhmx]
        max_gap_closing = 0      % Allowed gap in microbubbles pairing. (0)
        NLocalMax = 3            % Safeguard on the number of maxLocal in the fwhm*fwhm grid (3 for fwhm=3, 7 for fwhm=5)
        threshold_pairing        % max distance between reel and detected point to consider a pair assignee. (\lambda/2)
        threshold_tp             % max distance between reel and detected point to consider a true positive localization. (\lambda/4)
        
        algorithm  = ulm.algorithm.no_shift              % Localization algorithm
        tracking   = ulm.tracking.velocity_interpolation % Tracking scheme

        verbose  = true          % Prints more info.
        workbars = true          % Allow ULM to create workbars
    end

    properties(Dependent)
        numberOfFramesProcessed
        N_frames
        process
    end

    % Dependent properties
    methods
        function a = get.numberOfFramesProcessed(h)
            a = h.N_frames;
        end

        function a = get.N_frames(h)
            if isempty(h.input) && ~isempty(h.numberOfFrames)
                a = h.numberOfFrames;
            elseif ~isempty(h.input)
                a = h.input.N_frames;
            else
                error("You must explicitly specify numberOfFrames if input is empty.");
            end
        end
    end

    methods (Access = protected)
        function log(obj,msg)
            if obj.verbose
                disp(msg)
            end
        end

        function workbar(obj, x, msg, title)
            arguments
                obj (1,1) ulm.ULM
                x  (1,1) double
                msg   (1,1) = "Running ULM process..."
                title (1,1) = "ULM Process"
            end

            if obj.workbars
                tools.workbar(x, msg, title);
            end
        end
    end

    % Setters & Getters
    methods
        function set.input(h, in_beamformed_data)
            assert(isa(in_beamformed_data,'uff.beamformed_data'), 'The input is not a UFF.BEAMFORMED_DATA class. Check HELP UFF.BEAMFORMED_DATA.');
            h.input = in_beamformed_data;
        end
        function set.scan(h, in_scan)
            assert(isa(in_scan, 'uff.scan'), 'The input is not a UFF.SCAN class. Check HELP UFF.SCAN.');
            h.scan = in_scan;
        end
        function process = get.process(h)
            process = struct( ...
                'numberOfParticles', h.numberOfParticles, ...
                'res', h.resolution, ...
                'max_linking_distance', h.max_linking_distance, ...
                'min_length', h.min_length, ...
                'fwhm', h.fwhm, ...
                'max_gap_closing', h.max_gap_closing, ...
                'size', [h.scan.N_z_axis, h.scan.N_x_axis, h.numberOfFramesProcessed], ...
                'scale', [h.scale 1/h.framerate],... % 'scale', [delta_z/h.lambda delta_x/h.lambda 1/h.framerate], ...
                'numberOfFramesProcessed', h.numberOfFramesProcessed(), ...
                'interp_factor', h.interp_factor, ...
                'verbose', h.verbose, ...
                'workbars', h.workbars...
            );
            
            process.parameters = struct();
            process.parameters.NLocalMax = h.NLocalMax;

            process.SRscale = process.scale(1)/h.resolution;
            process.SRsize = round(process.size(1:2).*process.scale(1:2)/process.SRscale);

            [process.LocMethod, process.parameters.InterpMethod] = char(h.algorithm);
        end
    end

    methods
        function h = ULM()
            % Checking licenses and features
            ToolBoxRequires = {'Communications','Bioinformatics','Image Processing','Curve Fitting','Signal Processing','Statistics and Machine Learning','Parallel Computing','Computer Vision Toolbox'};
            err = 0;
            for featureName=ToolBoxRequires
               IsInstalledToolbox = contains(struct2array(ver), featureName{1});
               if ~IsInstalledToolbox, warning([featureName{1} ' is missing']),err=1;end
            end
            if err,error('Toolbox are missing.');end;clear ToolBoxRequires featureName IsInstalledToolbox err
        end
        function update(h)
            if isempty(h.threshold_pairing)
                h.threshold_pairing = h.lambda/2;
            end

            if isempty(h.threshold_tp)
                h.threshold_tp = h.lambda/4;
            end

        end

        function [Track, varargout] = go(h)
            h.update()

            data_raw = abs(h.input.data);
            data_in = reshape(abs(data_raw), [h.scan.N_z_axis, h.scan.N_x_axis, h.input.N_frames]);
            
            t0 = tic;
            fprintf("Running localization...");

            [MatTracking] = ulm.localization2D(data_in, h.process);

            fprintf("Done\n");

            % Convert MatTracking from pixel to world space
            xs = h.scan.x_axis;
            zs = h.scan.z_axis;
            MatTracking(:,2) = interp1(0:length(zs)-1, zs, MatTracking(:,2)-1);
            MatTracking(:,3) = interp1(0:length(xs)-1, xs, MatTracking(:,3)-1);

            % Since tracking happens in lambda space, convert from mm to lambda
            MatTrackLambda = MatTracking(:,:);
            MatTrackLambda(:,2:3) = MatTracking(:, 2:3) / h.lambda;

            fprintf("Running tracking...");
            if h.tracking == ulm.tracking.pala
                [Track, Track_interp] = ulm.tracking2D(MatTrackLambda, h.process, char(h.tracking));
            elseif h.tracking == ulm.tracking.none
                Track = single(MatTracking);
                Track_interp = [];
            else
                Track = ulm.tracking2D(MatTrackLambda, h.process, char(h.tracking));
                Track_interp = [];
            end
            

            % When done tracking, convert back to mm, based on tracking
            % mode used.
            if h.tracking == ulm.tracking.pala                
                Track_interp = cellfun( ...
                    @(x) [ ...
                        x(:, 1) * h.lambda,... % Position: lambda -> m
                        x(:, 2) * h.lambda,...
                        x(:, 3:end)...
                    ], Track_interp, 'UniformOutput', false);
            end

            if h.tracking == ulm.tracking.none
                % Do nothing
            elseif h.tracking == ulm.tracking.velocity_interpolation
                Track = cellfun( ...
                    @(x) [ ...
                        x(:, 1) * h.lambda,... % Position: lambda -> m
                        x(:, 2) * h.lambda,...
                        x(:, 3) * h.lambda,... % Velocity: lambda/s -> m/s
                        x(:, 4) * h.lambda,...
                        x(:, 5)...
                    ], Track, 'UniformOutput', false);
            else
                Track = cellfun( ...
                    @(x) [ ...
                        x(:, 1) * h.lambda,... % Position: lambda -> m
                        x(:, 2) * h.lambda,...
                        x(:, 3:end)...
                    ], Track, 'UniformOutput', false);
            end

            if nargout>1
                varargout{1} = Track_interp;
            end

            fprintf("Done\n");
            process_time = toc(t0);
            fprintf("Processing finished in %.2f seconds\n\n", process_time);
        end

        function [ImgOut, varargout] = create_image(h, tracks, mode)
            arguments
                h 
                tracks 
                mode (1,1) ulm.image_mode = ulm.image_mode.tracks
            end
            h.update();

            % The image operations happen in pixel space, so we must
            % convert the image from m to pixels
            tracks = cellfun( ...% Position: m -> px
                @(x) [ ...
                    interp1(h.scan.z_axis,0:h.scan.N_z_axis-1, x(:,1)) ...
                    interp1(h.scan.x_axis,0:h.scan.N_x_axis-1, x(:,2)) ...
                    x(:,3:end) ...
                ], ...
                tracks,'UniformOutput', false);

            if h.tracking ~= ulm.tracking.velocity_interpolation || size(tracks{1},2) == 3
                % Convert tracks into SRpixel domain
                Track_matout = cellfun( ...
                    @(x) (x(:,[1 2 3])+[1 1 0]*1)./[h.process.SRscale h.process.SRscale 1], ...% Original: [1 2 3])+[1 1 0]
                    tracks, ...
                    'UniformOutput', ...
                    0);
    
                fprintf('--- CREATING IMAGE --- \n');

                if nargout > 1
                    [ImgOut, varargout{1}] = ulm.Track2MatOut(Track_matout,h.process.SRsize, 'mode', char(mode));
                else
                    ImgOut = ulm.Track2MatOut(Track_matout,h.process.SRsize, 'mode', char(mode));
                end
            else % Velocity information is present
                % Convert tracks into SRpixel domain
                Track_matout = cellfun( ...
                    @(x) (x(:,[1 2 3 4])+[1 1 0 0]*1)./[h.process.SRscale h.process.SRscale 1 1], ...
                    tracks, ...
                    'UniformOutput', ...
                    0);
    
                fprintf('--- CREATING IMAGES --- \n');
                if nargout > 1
                    [ImgOut, varargout{1}] = ulm.Track2MatOut(Track_matout,h.process.SRsize, 'mode', char(mode));
                else
                    ImgOut = ulm.Track2MatOut(Track_matout,h.process.SRsize, 'mode', char(mode));
                end
            end
        end

        function [Stat_classification,ErrList,FinalPairs,MissingPoint,WrongLoc] = pairing(h,track_in, position_reference)
            if (isempty(h.threshold_pairing) || isempty(h.threshold_tp)) && isempty(h.lambda)
                error("Both threshold_pairing and threshold_tp must be set explicitally if no lambda is available!");
            elseif ~isempty(h.lambda)
                h.threshold_pairing = h.lambda/2;
                h.threshold_tp = h.lambda/4;
            else
                error("Make sure both threshold_pairing and threshold_tp is defined");
            end

            ErrList = [];
            % Iterate over each frame
            
            for frame_i = 1:h.N_frames
                h.workbar(frame_i/h.N_frames, "Pairing tracks to reference...", "ULM Pairing");

                pos_ref = position_reference(:,:,frame_i);
                pos_ref = pos_ref(isfinite(pos_ref(:,1)),:); % Remove NaN points

                % Filter out positions outside image
                outliers = true(size(pos_ref,1),1);
                outliers(pos_ref(:,1) < h.scan.x_axis(1)) = 0;
                outliers(pos_ref(:,1) > h.scan.x_axis(end)) = 0;
                outliers(pos_ref(:,3) < h.scan.z_axis(1)) = 0;
                outliers(pos_ref(:,3) > h.scan.z_axis(end)) = 0;
                pos_ref = pos_ref(outliers, :);

                % Reorder columns to [z x reflectivity]
                pos_ref = pos_ref(:, [3 1 4]);

                Points_ref{frame_i} = pos_ref;
                Nb_ref = size(pos_ref,1); %number of target points

                % Fetch the localized points in [z x intensity]
                idframe = track_in(:,3) == frame_i;
                % pos_loc = h.input_track(idframe, [2 3 1]);
                pos_loc = track_in(idframe, :);
                Points_loc{frame_i} = pos_loc;
                Nb_loc = size(pos_loc, 1);

                %% Compute inter-distance matrix
                InterDistMat = zeros(Nb_ref, Nb_loc);
                for i_0 = 1:Nb_ref
                    InterDistMat(i_0, :) = vecnorm(pos_ref(i_0,[1 2]) - pos_loc(:,[1 2]), 2, 2);
                end

                % Sort and pair
                InterDistMat_0 = InterDistMat;
                [minErr_loc,~] = min(InterDistMat_0,[],1);
                [~,indin_loc] = sort(minErr_loc(:));
                InterDistMat_0 = InterDistMat_0(:,indin_loc);
            
                [minErr_ref,~] = min(InterDistMat_0,[],2);
                [~,indin_ref] = sort(minErr_ref(:));
                InterDistMat_0 = InterDistMat_0(indin_ref,:);
            
                DD_mat_00 = InterDistMat_0;
                imin_last = 0;
                
                MatPairings = zeros(0,3); % pairing matrix [indice_ref,indice_loc,distance]
                for ii=1:size(InterDistMat_0,2)
                    if isempty(DD_mat_00)
                       break
                    end
                    [err,imin] = min(DD_mat_00(:,1));
                    MatPairings = cat(1,MatPairings,[indin_ref(imin_last+imin),indin_loc(ii),err]);
                    DD_mat_00 = DD_mat_00((imin+1):end,2:end);
                    imin_last = imin_last+imin;
                end
            
                %% Store data in outputs
                GoodPairings        = MatPairings(MatPairings(:,3)<h.threshold_pairing,:);
                FinalPairs{frame_i}     = GoodPairings;     % [index ref, index loc, RMSE]
                MissingPoint{frame_i}   = setdiff(1:Nb_ref,GoodPairings(:,1)); % [index ref]
                WrongLoc{frame_i}       = setdiff(1:Nb_loc,GoodPairings(:,2)); % [index loc]
                ErrList                 = cat(1,ErrList,[GoodPairings(:,3) pos_ref(GoodPairings(:,1),[1 2]) - pos_loc(GoodPairings(:,2),[1 2])]);
            
                TruePos_detections      = MatPairings(:,3)<h.threshold_tp;
                T_pos(frame_i)          = nnz(TruePos_detections);  % 

                F_neg(frame_i)          = Nb_ref-T_pos(frame_i);        % False negative: missing points
                F_pos(frame_i)          = Nb_loc - T_pos(frame_i);
            
                Npos_in(frame_i)        = Nb_ref;
                Npos_loc(frame_i)       = Nb_loc;
            end
            FinalPairs = FinalPairs';
            MissingPoint = MissingPoint';
            WrongLoc = WrongLoc';
            Stat_classification = cat(2,Npos_in',Npos_loc',T_pos',F_neg',F_pos');
        end
    end
end

