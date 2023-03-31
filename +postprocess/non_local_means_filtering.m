classdef non_local_means_filtering < postprocess
    %NON LOCAL MEANS FILTERING Matlab implementation of the nonlocal means
    %   denoising filter
    %
    %   A fast implementation of the non-local means based on distances in
    %   the features space. The full algorithm is discussed in detail in the
    %   following paper:
    %
    %      A. Tristān-Vega, V. Garcėa-Pčrez, S. Aja-Fernāndez, C.-F. Westin
    %      "Efficient and robust nonlocal means denoising of MR data based on
    %      salient features matching"
    %      Computer Methods and Programs in Biomedicine, vol. 105, pp. 131-144
    %      (2012)
    %
    %   implementers:   Antonio Tristān-Vega <atriveg@lpi.tel.uva.es>
    %                   Ole Marius Hoel Rindal <olemarius@olemarius.net>
    %
    %   $Last updated: 2020/01/04$
    
    %% constructor
    methods (Access = public)
        function h = non_local_means_filtering()
            h.name = 'Non Local Means Filtering';
            h.reference = ['A. Tristān-Vega, V. Garcėa-Pčrez, S. Aja-Fernāndez, ' ...
                'C.F. Westin', '"Efficient and robust nonlocal means denoising ' ...
                'of MR data based on salient features matching"', 'Computer ' ...
                'Methods and Programs in Biomedicine, vol. 105, pp. 131-144, ' ...
                '(2012)'];
            h.implemented_by = {'Ole Marius Hoel Rindal <olemarius@olemarius.net>'};
            h.version = 'v1.0.0';
        end
    end
    
    %% Additional properties
    properties
        dimension = dimension.both; % Dimension class that specifies whether the 
                                    % process will run only on transmit, receive, or both.
                                    
        run_on_logcompressed = 1;
        
        sigma = 60;                 % The noise power in the input image. In the Gaussian case, this
                                    % is the standard deviation of the Gaussian noise at each pixel.
                                    % In the Rician case, it is the standard deviation of noise in
                                    % the original, Gaussian distributed, real and imaginary parts of
                                    % the signal (whose modulus is computed to get the Rician
                                    % variable).
                                    
        beta = 1.0;                 % Filtering parameter. The larger its value, the more
                                    % aggressive the filtering. The smaller its value, the better
                                    % details are preserved. It should be in the range of 0.8 to 1.2
                                    
        rs   = [30,30,1];           % A 3x1 vector with the search radii
        
        rc   = [30,30,1];           % A 3x1 vector with the comparison radii
        
        ps   = 4;                   % The preselection threshold. All those pixels in the search
                                    % window whose normalized distance to the center pixel is larger
                                    % than this value are automatically removed from the weighted
                                    % average.
                                    
        flag = 'gaussian';          % Must be either 'gaussian' (the default) or 'rician'. In the
                                    % latter case, the weighted average is performed over the squared
                                    % pixels, and the filtered value is computed as
                                    % sqrt(\mu-2\sigma^2) so that the estimate becomes unbiased.
                                    
        block= 1;                   % This second flag tells the algorithm if the computation of the
                                    % weights within the search window must be done with a loop (0,
                                    % the default since it seems to be faster for the default search
                                    % window) or it must be done with vector operations (1). Choose 0
                                    % with small search radii or 1 with larger search radii.
    end
    
    methods
        function output = go(h)
            % check if we can skip calculation
            if h.check_hash()
                output= h.output;
                return;
            end
            
            
            %% Non local means
            if h.run_on_logcompressed ~= 1
                D_all = h.input.get_image('none');
            else
                D_all = h.input.get_image();
            end
            V_all = zeros(size(D_all));
            
            for i = 1:size(D_all,4)
                disp([num2str(i),'/20'])
                D = D_all(:,:,i);
                [Ns, Nl] = size(D);
                                
                D = padarray(D, h.rc(1:2), 'symmetric', 'both'); % Pad to avoid edge artifacts
                
                tic
                V = h.FastNonLocalMeans3D(D, h.sigma, h.beta, h.rs, h.rc, ...
                    h.ps, h.flag, h.block);
                toc
                
                V = V(h.rc(2)+(1:Nl), h.rc(1)+(1:Ns));
                D = D(h.rc(2)+(1:Nl), h.rc(1)+(1:Ns));
                N = V-D;
                
                doNoiseAddBack = 1;
                nabf = 0.07;
                if doNoiseAddBack
                    V = V+nabf*N;
                end
                
                V_all(:,:,i) = V;
                V_all(:,:,i) = V_all(:,:,i)-max(max(V_all(:,:,i)));
                
                if h.run_on_logcompressed
                    V_all(:,:,i) = 10.^(V_all(:,:,i)/20);
                end                 
                
            end
            
            h.output=uff.beamformed_data(h.input); % ToDo: instead we should copy everything but the data
            
            h.output.data = reshape(V_all,h.input.scan.N_x_axis*h.input.scan.N_z_axis,1,1,size(D_all,4));
            
            % pass reference
            output = h.output;
            
            % update hash
            h.save_hash();
        end
        
        function out = FastNonLocalMeans3D(h, V, sigma, beta, rs, rc, ps, flag, block )
                % A fast implementation of the non-local means based on distances in
                %   the features space. 
                %
                %   NOTE: Some of the computational features described in the paper above
                %   cannot be exploited in the matlab implementation. If performance is an
                %   issue for you, we strongly encourage you use the C++/ITK implementation
                %   available at: http://www.nitrc.org/projects/unlmeans, for which both
                %   source code and pre-compiled executables can be downloaded.
                %
                %    V:     The input volume to be filtered (3D). - MANDATORY
                %    sigma: The noise power in the input image. In the Gaussian case, this
                %           is the standard deviation of the Gaussian noise at each pixel.
                %           In the Rician case, it is the standard deviation of noise in
                %           the original, Gaussian distributed, real and imaginary parts of
                %           the signal (whose modulus is computed to get the Rician
                %           variable). - MANDATORY
                %    beta:  The filtering parameter. The larger its value, the more
                %           aggressive the filtering. The smaller its value, the better
                %           details are preserved. It should be in the range of 0.8 to 1.2
                %           for best performance (Default: 1.0).
                %    rs:    A 3x1 vector with the search radii (Default: 2,2,2).
                %    rc:    A 3x1 vector with the comparison radii (Default: 1,1,1).
                %    ps:    The preselection threshold. All those pixels in the search
                %           window whose normalized distance to the center pixel is larger
                %           than this value are automatically removed from the weighted
                %           average (Default: 2.0).
                %    flag:  Must be either 'gaussian' (the default) or 'rician'. In the
                %           latter case, the weighted average is performed over the squared
                %           pixels, and the filtered value is computed as
                %           sqrt(mu-2�sigma^2) so that the estimate becomes unbiased.
                %    block: This second flag tells the algorithm if the computation of the
                %           weights within the search window must be done with a loop (0,
                %           the default since it seems to be faster for the default search
                %           window) or it must be done with vector operations (1). Choose 0
                %           with small search radii or 1 with larger search radii.
                %
                %    out:   The filtered volume.
                
                if( nargin<2 )
                    error('At least the input volume and the noise power must be provided');
                end
                
                if( nargin<3 )
                    beta = 1.0;
                end
                p = beta*sigma;
                
                if( nargin<4 )
                    rs = [2;2;2];
                else
                    if( length(rs)~=3 )
                        rs = rs(1).*ones(3,1);
                    end
                end
                
                if( nargin<5 )
                    rc = [1;1;1];
                else
                    if( length(rc)~=3 )
                        rc = rc(1).*ones(3,1);
                    end
                end
                
                if( nargin<6 )
                    ps = 2.0;
                end
                
                if( nargin<7 )
                    FLAG = 0;
                else
                    if( strcmpi('gaussian',flag) )
                        FLAG = 0;
                    elseif( strcmpi('rician',flag) )
                        FLAG = 1;
                    else
                        error(['Unknown filtering type: ',flag]);
                    end
                end
                
                if( nargin<8 )
                    block = 0;
                end
                
                % Compute the size of the image:
                [Y,X,Z] = size(V);
                
                % Compute the features map:
                [mu,Gx,Gy,Gz,factors,hcorr] = h.ComputeLocalFeatures3D( V, rc );
                
                % Compute the effective value of h as described in the paper:
                p = hcorr*p;
                
                % Initiallize the output:
                out = zeros(Y,X,Z);
                
                % Loop along the pixels:
                h_wb = waitbar(0, 'NLM processing');
                for x=1:X
                    for y=1:Y
                        for z=1:Z
                            % We are filtering the pixel (x,y,z). First, create a
                            % neighborhood around this pixel checking for out-of-bound
                            % indices:
                            mx = max( x-rs(1), 1 );
                            MX = min( x+rs(1), X );
                            my = max( y-rs(2), 1 );
                            MY = min( y+rs(2), Y );
                            mz = max( z-rs(3), 1 );
                            MZ = min( z+rs(3), Z );
                            % Keep the center values:
                            mu0 = mu(y,x,z);
                            gx0 = Gx(y,x,z);
                            gy0 = Gy(y,x,z);
                            gz0 = Gz(y,x,z);
                            if( block==1 )
                                % VECTOR IMPLEMENTATION (SEEMS TO BE SLOWER):
                                % Get the valeus of the pixels in the whole search neihborhood:
                                vals  = V(my:MY,mx:MX,mz:MZ);
                                % Get the mean values and gradients of the pixels in the whole
                                % search neighborhood:
                                mui   = mu(my:MY,mx:MX,mz:MZ);
                                gxi   = Gx(my:MY,mx:MX,mz:MZ);
                                gyi   = Gy(my:MY,mx:MX,mz:MZ);
                                gzi   = Gz(my:MY,mx:MX,mz:MZ);
                                % Compute the distances:
                                dists = (mui-mu0).*(mui-mu0) + ...
                                    (gxi-gx0).*(gxi-gx0)*factors(1) + ...
                                    (gyi-gy0).*(gyi-gy0)*factors(2) + ...
                                    (gzi-gz0).*(gzi-gz0)*factors(3);
                                % Normalize the distances:
                                dists = dists./(p*p);
                                % Compute the weights:
                                wis   = exp(-dists);
                                % Set to 0 the normalized distances above the threshold to
                                % execute pre-selection:
                                wis(dists>ps) = 0;
                                % Avoid over-weighting of the central pixel:
                                wis(wis>0.367879441171442) = 0.367879441171442;
                                % Compute the normalization factor:
                                NORM  = sum(wis(:));
                                % Filter the pixel; average the pixels or their squared values
                                % depending on the filtering type:
                                if( FLAG==0 ) % Gaussian
                                    pixel = sum(wis(:).*vals(:));
                                else % Rician
                                    pixel = sum(wis(:).*vals(:).*vals(:));
                                end
                            else
                                % LOOP IMPLEMENTATION (SEEMS TO BE FASTER):
                                pixel = 0.0;
                                NORM  = 0.0;
                                for s=mx:MX
                                    for t=my:MY
                                        for u=mz:MZ
                                            % Get the current features:
                                            mui  = mu(t,s,u);
                                            gxi  = Gx(t,s,u);
                                            gyi  = Gy(t,s,u);
                                            gzi  = Gz(t,s,u);
                                            % Compute the distance and normalize:
                                            dist = (mu0-mui)*(mu0-mui) + ...
                                                (gx0-gxi)*(gx0-gxi)*factors(1) + ...
                                                (gy0-gyi)*(gy0-gyi)*factors(2) + ...
                                                (gz0-gzi)*(gz0-gzi)*factors(3);
                                            dist = dist/(p*p);
                                            % Compute the weight in case the distance is below
                                            % the pre-selection threshold, otherwise set to 0:
                                            if( dist<ps )
                                                dist = exp(-dist);
                                            else
                                                dist = 0;
                                            end
                                            % Avoid over-weighting of the central pixel:
                                            if(dist>0.367879441171442)
                                                dist = 0.367879441171442;
                                            end
                                            % Add to the current value. Average the pixels or
                                            % their squared values depending on the filtering
                                            % type:
                                            if( FLAG==0 ) % Gaussian
                                                pixel = pixel + dist * V(t,s,u);
                                            else %Rician
                                                pixel = pixel + dist * V(t,s,u) * V(t,s,u);
                                            end
                                            % Store the normalization:
                                            NORM  = NORM + dist;
                                        end
                                    end
                                end
                            end
                            % Normalize the pixel. If we are in the Rician case, we need
                            % also to remove the bias:
                            if( FLAG==0 ) % Gaussian
                                pixel = pixel/NORM;
                            else % Rician
                                pixel = sqrt(max(pixel/NORM-2*sigma*sigma,0));
                            end
                            % Set the output pixel:
                            out(y,x,z) = pixel;
                        end
                    end
                    waitbar(x/X, h_wb);
                end
                close(h_wb);
                return;
        end
            
        function [mu,Gx,Gy,Gz,factors,hcorr] = ComputeLocalFeatures3D(h, I, radii )
                % Computes the local mean value and the local gradients of a 3D image.
                %
                %    I:       the input image
                %    radii:   a 3x1 vector of integers with the size of the neighborhood used
                %             to compute the local values. Gaussian windows are used
                %             generated for each dimension as gausswin(2*radii(d)+1). If not
                %             provided, [x=1;y=1;z=1] will be assumed
                %    mu:      A 3D image, the same size as I, with local mean.
                %    Gx:      A 3D image, the same size as I, with the gradient in the 'x'
                %             direction (dimension 2 in matlab).
                %    Gy:      A 3D image, the same size as I, with the gradient in the 'y'
                %             direction (dimension 1 in matlab).
                %    Gz:      A 3D image, the same size as I, with the gradient in the 'z'
                %             direction (dimension 3 in matlab).
                %    factors: a 3x1 vector with the factors to be applied to each gradient
                %             difference to estimate patch distances.
                %    hcorr:   the effective reduction in the amount of noise in the
                %             distances between patches because of the fitting.
                
                I = double(I);
                
                % Check if the radii where provided:
                if( nargin<2 )
                    radii = [1;1;1];
                else
                    if( length(radii) ~= 3 )
                        radii = ones(3,1)*radii(1);
                    end
                end
                
                % Create the gaussian windows for each direction:
                gx = gausswin( 2*radii(1) + 1 ); gx = gx./sum(gx);
                gy = gausswin( 2*radii(2) + 1 ); gy = gy./sum(gy);
                gz = gausswin( 2*radii(3) + 1 ); gz = gz./sum(gz);
                
                % Compute the local mean:
                mu = h.My3DConv( I, gx, gy, gz );
                
                % Create the differentiation kernels:
                gdx = (-radii(1):radii(1))';
                gdx = (gdx.*gx)./sum(gdx.*gdx.*gx);
                gdy = (-radii(2):radii(2))';
                gdy = (gdy.*gy)./sum(gdy.*gdy.*gy);
                gdz = (-radii(3):radii(3))';
                gdz = (gdz.*gz)./sum(gdz.*gdz.*gz);
                
                % Create each gradient image (the minus sign is for consistence with the
                % implementation of matlab's 'gradient' function:
                Gx  = -h.My3DConv( I, gdx, gy,  gz  );
                Gy  = -h.My3DConv( I, gx,  gdy, gz  );
                Gz  = -h.My3DConv( I, gx,  gy,  gdz );
                
                % Compute the scaling factors:
                factors(1) = sum( (-radii(1):radii(1)).*(-radii(1):radii(1)).*gx' );
                factors(2) = sum( (-radii(2):radii(2)).*(-radii(2):radii(2)).*gy' );
                factors(3) = sum( (-radii(3):radii(3)).*(-radii(3):radii(3)).*gz' );
                
                % Compute the correction in the h factor. First, compute the 'X' matrix:
                [x,y,z]    = meshgrid( -radii(1):radii(1), ...
                    -radii(2):radii(2), ...
                    -radii(3):radii(3) );
                X          = [ ones(size(x(:))), ...
                    x(:), y(:), z(:), ...
                    x(:).*x(:)/2, y(:).*y(:)/2, z(:).*z(:)/2, ...
                    x(:).*y(:), x(:).*z(:), y(:).*z(:) ];
                [g1,g2,g3] = meshgrid( gx, gy, gz );
                R          = g1(:).*g2(:).*g3(:);
                hcorr    = sqrt(trace(diag(R)*X*(X'*X)^(-1)*X'));
                return;
        end
            
        function out = My3DConv(h, I, gx, gy, gz )
                % Computes a separable 3D convolution
                gx  = gx(:);
                gx  = permute(gx,[2,1,3]);
                gy  = gy(:);
                gz  = gz(:);
                gz  = permute(gz,[3,2,1]);
                I   = convn( I, gx, 'same' );
                I   = convn( I, gy, 'same' );
                out = convn( I, gz, 'same' );
                return;
        end
            
        end
    end