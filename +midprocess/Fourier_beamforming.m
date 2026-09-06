classdef Fourier_beamforming < midprocess

    %   Implementation of Fourier-domain beamforming for STAI channel data,
    %   also known as full-matrix capture (FMC). This implementation supports
    %   both the conventional Wavenumber Algorithm (WA) and the
    %   Delay-and-Sum Consistent Wavenumber Algorithm (DCWA).
    %
    %   For further details on DCWA, see:
    %   S. Mulani, M. S. Ziksari, A. Austeng, and S. P. Näsholm,
    %   "Delay-and-Sum Consistent Wavenumber Algorithm," IEEE Transactions on
    %   Ultrasonics, doi: 10.1109/TUSON.2026.3667456.
    %
    %   author:    Sufayan Mulani <sufayanm@uio.no>

    %% Additional properties
    properties
        refocus           = false ; % If true: recover FMC prior to beamforming (for non-FMC data)
        spatial_padding   = 2;      % Zero-padding factor in aperture dimensions
        temporal_padding  = 2;      % Zero-padding factor in time
        temp_origin       = 0;      % Temporal origin shift [m] used to center time axis
        z_lim             = 1.5 ;   % z-limit factor to define kz-grid extent relative to scan depth
        USTB_scan         = true ;  % If true: interpolate reconstructed image onto provided scan grid
        angle_apodization = [] ;    % Angular cutoff (deg)
        DAS_consistent    = true ;  % Flag indicating DCWA mode (currently implemented via mult_factor + z scaling)
    end

    %% Constructor
    methods (Access = public)
        function h=Fourier_beamforming()
            h.name='WA';
            h.reference= ['Mulani, S., Ziksari, M. S., Austeng, A., & Näsholm, ' ...
                'S. P. (2026). Delay-and-Sum Consistent Wavenumber Algorithm. ' ...
                'IEEE Transactions on Ultrasonics.'];
            h.implemented_by={'Sufayan Ikabal Mulani <sufayanm@uio.no>'};
            h.version='1.1.0';
        end
    end

    %% Go method
    methods
        function beamformed_data = go(h)

            % check if we can skip calculation
            if h.check_hash()
                beamformed_data= h.beamformed_data;
                return;
            end
            if h.DAS_consistent
                h.name = 'DCWA' ;
            end
            if h.refocus
                h.name = [h.name, ' + ReFocus'] ;
            end

            %% Define input data and acquisition parameters
            SIG   = single(h.channel_data.data(:, :, :, 1)) ;
            [N_sample, N_elements, N_waves] = size(SIG);

            fs    = h.channel_data.sampling_frequency; % Sampling frequency [Hz]
            pitch = h.channel_data.probe.pitch ;       % Element pitch [m]
            c0    = h.channel_data.sound_speed ;       % Sound speed [m/s]
            w0 = 2*pi*h.channel_data.modulation_frequency ;  % modulation frequency for IQ data

            t0 = zeros(N_waves, 1) ;  % Time offset per transmit wave
            for ii=1:N_waves
                t0(ii) = h.channel_data.sequence(ii).delay + h.channel_data.initial_time ;
            end

            %% Zero-padding sizes
            ntFFT = h.temporal_padding*N_sample + round(max(t0*fs)) ;
            if rem(ntFFT,2)==1 % ntFFT is made even for symmetric FFT grids
                ntFFT = ntFFT+1;
                warning('Zero padding should be an even number. Temporal padding is updated to %2.0f', ntFFT)
            end
            fprintf('Number of samples in data - %4.0f \n', N_sample)
            fprintf('Number of samples in zero-padded data - %4.0f \n', ntFFT)

            % Spatial FFT size. Used for both k_u and k_v grids.
            nxFFT = ceil(h.spatial_padding*N_elements); % used to mitigate lateral edge effects
            if rem(nxFFT,2)==1 % nxFFT is made even for symmetric FFT grids
                nxFFT = nxFFT+1;
                warning('Zero padding should be an even number. Spatial padding is updated to %2.0f', ntFFT)
            end
            if rem(nxFFT-N_elements, 2)==1
                error('Please make (nxFFT-N_elements) an even number (By making N_elements even)')
            end
            nyFFT = nxFFT ;

            %% Define spectral grids (kx, kz, ku, kv, k)
            % The migration maps spectral samples from (k, kv, ku) to (kx, kz).
            % Here, (kv, ku) come from spatial FFTs and k = w/c0 from temporal FFT of the channel data.

            % Oversize factors for kx/kz grids relative to ku and k grids
            grd_size_x = 2 ;
            grd_size_z = 2 ;
            % The stolt mappaing for FMC is defined as kx = ku + kv;  kz = sqrt(k^2 - ku^2) + sqrt(k^2 - kv^2);
            % we get, min(2*ku)<= kx <= max(2*ku) and min(2*k)<= kz <= max(2*k)
            % Hence, grd_size_x=grd_size_z should be equal to 2 to cover the
            % entire frequency range. However, smaller factor can be chosen
            % to reduce the number of computations required.

            % Define kz extent based on scan depth
            z_limit_factor = h.z_lim ;
            if isa(h.scan,'uff.linear_scan')
                z_limit = round(z_limit_factor*h.scan.z_axis(end)/c0*fs) ;
            elseif isa(h.scan,'uff.sector_scan')
                z_limit = round(z_limit_factor*h.scan.depth_axis(end)/c0*fs) ;
            end
            if rem(z_limit, 2)==1
                z_limit = z_limit +1;
            end

            % Grid sizes for image spectrum
            nx_kx = nxFFT ;   % Larger => wider reconstructed image
            nz_kz = z_limit ; % Larger => deeper reconstructed image

            % Define image grid
            kx = single(2*pi*((0:grd_size_x*nx_kx-1) - floor(nx_kx*grd_size_x/2))/pitch/nx_kx) ;
            full_kz = single(2*pi*((0:grd_size_z*nz_kz-1) - floor(grd_size_z*nz_kz/2))'*fs/nz_kz/c0  + w0/c0) ;
            kz = full_kz ;
            kz(kz<0) = [] ;  % keep only kz >= 0 frequencies
            [KXX, ~] = meshgrid(kx, kz) ;

            % Define channel data grid
            kv = 2*pi*((0:nxFFT-1) - floor(nxFFT/2))/pitch/nxFFT;  % receiver wavenumber 
            f_shifted = (((0:ntFFT-1) - floor(ntFFT/2)).')*2*pi*fs/ntFFT + w0;  % temporal wavenumber
            [kv_mat, k_mat] = meshgrid(kv, f_shifted/c0) ;
            ku = single(2*pi*reshape(((0:nyFFT-1) - floor(nyFFT/2)), 1, 1, [])/pitch/nyFFT);  % transmiter wavenumber

            % Compute migrated fequency
            kmig = find_kmig(h, kz, kx, ku) ;
            tools.check_memory(prod([length(kz), length(kx), nyFFT, 8]));

            if h.DAS_consistent
                ku_z_mig =  sqrt(kmig.^2 - ku.^2) ;
                kv_z_mig =  sqrt(kmig.^2 - (KXX - ku).^2) ;

                % DCWA weighting factor
                % This multiplier (plus the later z-scaling in spatial domain)
                % corresponds to the correction derived to obtain DAS-consistent output.
                mult_factor = kmig./(sqrt(ku_z_mig.*kv_z_mig).*(ku_z_mig + kv_z_mig)) ;

                % Remove evanescent waves
                mult_factor(imag(ku_z_mig)~=0 | imag(kv_z_mig)~=0) = 0 ;

                % Clamp extreme values
                limit = 0.0007 ;
                mult_factor(isinf(mult_factor)) = limit*sign(mult_factor(isinf(mult_factor))) ;
                mult_factor(isnan(mult_factor)) = 0 ;
                mult_factor(mult_factor<-limit) = -limit ;
                mult_factor(mult_factor>limit) = limit;
                clear ku_z_mig kv_z_mig
            else
                % The original wavenumber algorithm multiplicative factor
                mult_factor = sqrt((kmig.^2 - ku.^2).*(kmig.^2 - (KXX - ku).^2)) ;
            end

            % Remove non-existent frequencies
            kz_border = sqrt(abs(ku.^2 - (kx - ku).^2)) ;
            mult_factor(kz<kz_border) = 0 ;

            %% Temporal FFT
            tic
            SIG = fft(SIG, ntFFT) ;

            %% Adjusting temporal origin
            t_shift = round(2*h.temp_origin/c0*fs) ;   %% Index shift used to move temporal origin

            if h.refocus
                % Use REFoCUS to refocus the channel data recorded using any 
                % arbitrary transmit scheme into a STAI channel data.

                %   Bottenus, N. (2018). Recovery of the Complete Data Set from Focused Transmit
                %   Beams. IEEE Transactions on Ultrasonics, Ferroelectrics, and Frequency Control,
                %   65(1), 30–38. https://doi.org/10.1109/TUFFC.2017.2773495

                delays = zeros(N_waves, N_elements);
                apod_val =zeros(N_waves, N_elements) ;

                for aa = 1:N_waves
                    delays(aa, :) = h.channel_data.sequence(aa).delay_values - t0(aa) + (t_shift/fs);
                    apod_val(aa, :) = h.channel_data.sequence(aa).apodization_values  ;
                end
                if N_waves==N_elements
                    warning('ReFocus is implemented before the beamformer. Make sure it is necessary')
                end
                % Apply refocusing in frequency domain
                SIG = ReFocus_in_freq_domain(h, SIG, ntFFT, N_elements, fftshift(f_shifted), delays, apod_val) ;
            else
                if N_waves~=N_elements || h.channel_data.sequence(1).source.z~=0
                    error('This is not a full matrix data. You should use ReFocus before the wavenumber algorithm.')
                end

                % Calculate zero time
                for bb=1:N_waves
                    t0(bb) = t0(bb) - h.channel_data.probe.r(bb)/c0  ;
                end
                t0 = reshape(t0, 1,1,N_waves) ;
                dt = zeros(1, N_elements) ;

                % Shift the temporal origin to t_shift
                tmp = fftshift(f_shifted).*(dt+t0 - (t_shift/fs));
                SIG = SIG.*exp(-1i*tmp) ;
            end

            %% Spatial FFT of data
            SIG = cat(2, zeros(ntFFT, (nxFFT-N_elements)/2, N_elements), SIG, zeros(ntFFT, (nxFFT-N_elements)/2, N_elements)) ;  % To reconstruct the region outside aperture
            SIG = fft(fftshift(single(SIG), 2), [], 2) ;
            SIG = cat(3, zeros(ntFFT, nxFFT, (nyFFT-N_elements)/2), SIG, zeros(ntFFT, nxFFT, (nyFFT-N_elements)/2)) ;
            SIG = fft(fftshift(SIG, 3), [], 3) ;
            SIG = fftshift(SIG) ;

            %% Angular Apodization/ Evanscent waves removal
            if ~isempty(h.angle_apodization) && h.angle_apodization < 90
                % Compute the receive and transmit angles.
                % These angles are used to construct an angular apodization mask
                % applied to the channel data. The angles are computed 
                % using the far-field relationships :-
                % transmit angle = sin−1 (𝑘𝑢/𝑘) and receive angle = sin−1 (𝑘𝑣 /𝑘)
                taper_mask = taper_window(h, ku, kv, f_shifted/c0, "tukey", 0.25) ;
                SIG = SIG.*taper_mask ;
                SIG(abs(f_shifted/c0) < abs(ku) | abs(f_shifted/c0) < abs(kv)) = 0;    % Evanscent waves
            else
                % Remove evanescent waves even if no taper is applied
                SIG(abs(f_shifted/c0) < abs(ku) | abs(f_shifted/c0) < abs(kv)) = 0;    % Evanscent waves
            end

            %% Migrating the data to the image coordinates
            % For each transmit-wavenumber frame (ku), interpolate from the
            % sampled (kv,k) grid to the desired (kvmig,kmig) samples:
            % kvmig = k_x - k_u

            migSIG = zeros(length(kz), length(kx), nyFFT) ;  % Defining image matrix
            b='';
            for jj = 1:nyFFT
                s = sprintf('\nInterpolating frame no - %d / %d', jj, nyFFT);
                fprintf(1, [b, s]);
                b = repmat('\b', [1, length(s)]);
                migSIG(:, :, jj) = interp2(kv_mat, k_mat, SIG(:, :, jj), (KXX - ku(jj)), kmig(:, :, jj), 'linear', 0) ;
            end

            % Undo the earlier temporal-origin shift
            if t_shift ~= 0
                migSIG = migSIG.*exp(-1i*c0*kmig*t_shift/fs) ;   % Move temporal origin to its correct place
            end

            % Apply WA/DCWA weighting factor
            migSIG = migSIG.*mult_factor ;

            %% Sum over k_u frames and transform back to spatial domain
            f_migSIG = sum(migSIG, 3) ;
            f_migSIG = [zeros(length(full_kz)-length(kz), length(kx)); f_migSIG] ;
            f_image = fftshift(ifft2(f_migSIG), 2) ;

            %% Print time
            elapsed_time = toc ;
            fprintf('\nElasped time for %s is %.2f seconds. \n', h.name, elapsed_time)

            %% Defining spatial co-ordinates of produced image
            x = (0:length(kx)-1)*pitch/grd_size_x ;
            x = x - (x(end)+x(1))/2 + pitch/grd_size_x/2 ;
            z = (0:length(full_kz)-1)*c0/(grd_size_z*fs) ;
            [X, Z] = meshgrid(x,z) ;

            % DCWA scaling by z coordinate
            if h.DAS_consistent
                f_image = f_image.*Z ;
            end

            %% Package result into USTB beamformed_data object

            h.beamformed_data=uff.beamformed_data();

            if h.USTB_scan
                % Interpolate reconstructed image onto the scan grid provided by USTB
                if isa(h.scan,'uff.linear_scan')
                    [x_axiss, z_axiss] = meshgrid(h.scan.x_axis, h.scan.z_axis);
                    f_image = interp2(double(X), double(Z), f_image, double(x_axiss), double(z_axiss), 'linear', 0);
                elseif isa(h.scan,'uff.sector_scan')
                    [azimuth_axis, depth_axis] = meshgrid(h.scan.azimuth_axis +pi/2, h.scan.depth_axis) ;
                    [x_axiss, z_axiss] = pol2cart(azimuth_axis, depth_axis) ;
                    f_image = interp2(X, Z, f_image, x_axiss, z_axiss, 'linear', 0);
                end
                h.beamformed_data.scan=h.scan;
            else
                % If not interpolating to USTB scan: crop the reconstructed grid to desired limits
                x_scan_limits = [min(h.scan.x_axis(:)) max(h.scan.x_axis(:))] ;
                z_scan_limits = [min(h.scan.z_axis(:)) max(h.scan.z_axis(:))] ;

                if x_scan_limits(1)<min(x) || x_scan_limits(2)>max(x)
                    x_index_limit = [1 length(x)];
                else
                    x_index_limit = get_index(h, x_scan_limits, x(:)) ;
                end
                if z_scan_limits(1)<min(z) || z_scan_limits(2)>max(z)
                    z_index_limit = [1 length(z)];
                else
                    z_index_limit = get_index(h, z_scan_limits, z(:)) ;
                end

                x = x(x_index_limit(1):x_index_limit(2)) ;
                z = z(z_index_limit(1):z_index_limit(2)) ;
                f_image = f_image(z_index_limit(1):z_index_limit(2) , x_index_limit(1):x_index_limit(2)) ;

                wavenumber_scan = uff.linear_scan('x_axis', x(:), 'z_axis', z(:));
                h.beamformed_data.scan = wavenumber_scan;
            end

            h.beamformed_data.data = f_image(:);
            h.beamformed_data.name = h.name ;
            beamformed_data = h.beamformed_data;
            h.save_hash();

        end

        %% Compute migrated fequency
        function kmig = find_kmig(h, kz, kx, ku)
            kv2= (kx-ku).^2 ;
            ku2 = ku.^2 ;
            kz2 = kz.^2 ;
            kmig = kz2/4 + 0.5*(ku2 + kv2 ) + ((ku2- kv2).^2)./(4.*kz2) ;
            kmig(isinf(kmig)|isnan(kmig)) = 0 ;
            kmig = sqrt(kmig) ;
        end

        %% Compute the taper mask for channel data for angular apodization
        function taper_mask = taper_window(h, ku, kv, k, taper_type, taper_length)
            % Build 3-D taper mask in (k,kv,ku) space.
            %
            % Inputs:
            %   ku, kv : aperture spatial frequencies
            %   k      : temporal wavenumber grid
            %   taper_type   : 'linear' or 'tukey'
            %   taper_length : taper parameter (degree for linear, alpha for tukey)

            if nargin<4
                taper_type= '' ;
            end

            if strcmp(taper_type, "linear")
                if nargin<5
                    taper_length = h.angle_apodization/10 ;
                end

                angle_u = rad2deg(asin(ku./k)) ;
                angle_v = rad2deg(asin(kv./k)) ;

                theta_cutoff = h.angle_apodization;
                theta_taper = h.angle_apodization - taper_length;     % Start tapering here

                taper_mask_u = ones(size(angle_u));  % Start with all ones
                taper_mask_u(abs(angle_u) > theta_cutoff) = 0;

                taper_mask_v = ones(size(angle_v));  % Start with all ones
                taper_mask_v(abs(angle_v) > theta_cutoff) = 0;

                taper_zone = (abs(angle_u) > theta_taper) & (abs(angle_u) <= theta_cutoff);
                taper_mask_u(taper_zone) = (theta_cutoff - abs(angle_u(taper_zone))) / ...
                    (taper_length);

                taper_zone = (abs(angle_v) > theta_taper) & (abs(angle_v) <= theta_cutoff);
                taper_mask_v(taper_zone) = (theta_cutoff - abs(angle_v(taper_zone))) / ...
                    (taper_length);

            elseif strcmp(taper_type, "tukey")
                if nargin<5
                    taper_length = 0.25 ;
                end

                tan_u = ku./sqrt(k.^2 - ku.^2) ;
                tan_v = kv./sqrt(k.^2 - kv.^2) ;

                tan_u(isnan(tan_u)) = 0 ;
                tan_v(isnan(tan_v)) = 0 ;

                f_number = cot(deg2rad(h.angle_apodization))/2 ;

                ratio_u = abs(tan_u.*f_number) ;
                ratio_v = abs(tan_v.*f_number) ;

                taper_mask_u = (ratio_u<=(1/2*(1-taper_length))) + (ratio_u>(1/2*(1-taper_length))).*(ratio_u<(1/2)).*0.5.*(1+cos(2*pi/taper_length*(ratio_u-taper_length/2-1/2)));
                taper_mask_v = (ratio_v<=(1/2*(1-taper_length))) + (ratio_v>(1/2*(1-taper_length))).*(ratio_v<(1/2)).*0.5.*(1+cos(2*pi/taper_length*(ratio_v-taper_length/2-1/2)));

            else
                warning("Apodization window is not defined or does not exists. \n")
            end
            taper_mask = taper_mask_u.*taper_mask_v ;
            taper_mask(abs(k)<abs(ku) | abs(k)<abs(kv)) = 0 ;
        end

        %% ReFocus data into STAI channel data
        function refocus_data =  ReFocus_in_freq_domain(h, SIG, ntFFT, N_elements, f0, delays, apod_val)

            refocus_data = zeros(ntFFT, N_elements, N_elements);
            for kk = 1:ntFFT
                H_conj = apod_val.*exp(1i*f0(kk)*delays) ;
                refocus_data(kk, :, :) = squeeze(SIG(kk, :, :))*H_conj ;

                % Tikhonov-Regularized Inversion method

                %  Ali, R., Herickhoff, C. D., Hyun, D., Dahl, J. J., & Bottenus, N. (2020).
                %  Extending Retrospective Encoding for Robust Recovery of the Multistatic
                %  Data Set. IEEE Transactions on Ultrasonics, Ferroelectrics, and Frequency Control,
                %  67(5), 943–956. https://doi.org/10.1109/TUFFC.2019.2961875

                % H = H_conj' ;
                % smax = norm(H,2);
                % N = size(H,2);
                % param = 1e-4 ;
                % reg = param*smax*eye(N);
                % H_inv = (H_conj*H + reg'*reg)\H_conj ;
                % refocus_data(kk, :, :) = squeeze(SIG(kk, :, :))*H_inv ;     % Tikhonov Regularized Inverse of H Matrix
            end

        end

        %% This function finds the index of closest number to 'dist' in 'in_axis'
        function out_index = get_index(h, dist, in_axis, out_range)
            if nargin<3
                out_range = 0;
            end
            if isscalar(dist)
                if dist>max(in_axis)||dist<min(in_axis)
                    if out_range==0
                        error("Querry value is not in the range of sample points")
                    end
                end
                [~, out_index] = min(abs(dist - in_axis(:))) ;
            else
                size_dist = size(dist) ;
                dist = reshape(dist, 1, []) ;
                in_axis = in_axis(:) ;
                if max(dist)>max(in_axis)||min(dist)<min(in_axis)
                    if out_range==0
                        error("Some of the querry values are not in the range of sample points. " + ...
                            "If you want to proceed anyway use 1 as a third argument while calling the function")
                    end
                end
                [~, out_index] = min(abs(dist - in_axis)) ;
                out_index =  out_index(:) ;
                out_index = reshape(out_index, size_dist) ;
            end
        end

    end
end
