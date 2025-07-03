classdef apodization < uff
    %APODIZATION   UFF class to hold apodization data
    %   APODIZATION contains data to define transmit, receive & synthetic
    %   beams. Different parameters are needed depending on the use.
    %
    %   Properties:
    %         probe               % UFF.PROBE class (needed for transmit & receive apodization)
    %         focus               % UFF.SCAN class (needed for transmit, receive & synthetic apodization)
    %         sequence            % collection of UFF.WAVE classes (needed for synthetic apodizaton)
    %
    %         window              % UFF.WINDOW class, default uff.window.noen
    %         f_number            % F-number [Fx Fy] [unitless unitless]
    %         M                   % Number of elements [Mx My] in case f_number=0
    %
    %         origin              % POINT class to overwrite the location of the aperture window as computed on the wave source location
    %         tilt                % tilt angle [azimuth elevation] [rad rad]
    %
    %   Example:
    %         apo = uff.apodization();
    %
    %   See also UFF.CHANNEL_DATA, UFF.BEAMFORMED_DATA, UFF.SCAN
    
    %   authors: Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>
    %            Stefano Fiorentini <stefano.fiorentini@ntnu.no>
    %            Anders Vrålstad <anders.e.vralstad@ntnu.no>
    %   $Last updated: 07/10/2024$
    
    %% public properties
    properties  (Access = public)
        probe                           % UFF.PROBE class (needed for transmit & receive apodization)
        focus                           % UFF.SCAN class (needed for transmit, receive & synthetic apodization)
        sequence                        % collection of UFF.WAVE classes (needed for synthetic apodizaton)
        
        f_number  = [1, 1]              % F-number [Fx Fy] [unitless unitless]
        window    = uff.window.none     % UFF.WINDOW class, default uff.window.none
        MLA       = [1, 1]              % number of multi-line acquisitions, only valid for uff.window.scanline
        MLA_overlap = [0, 0]            % number of multi-line acquisitions, only valid for uff.window.scanline
        
        tilt      = [0, 0]              % tilt angle [azimuth elevation] [rad rad]
        minimum_aperture = [1e-3, 1e-3] % minimum aperture size in the [x y] direction
        maximum_aperture = [10, 10]     % maximum aperture size in the [x y] direction
        grating_lobe_angle = [pi,pi];   % grating lobe angle for masking
    end
    
    %% optional properties
    properties  (Access = public)
        apodization_vector              % apodization vector to override the dynamic calculation of apodization
        origin                          % POINT class to overwrite the location of the aperture window as computed on the wave source location
    end
    
    %% dependent properties
    properties  (Dependent)
        data                        % apodization data
        N_elements                  % number of elements (real or synthetic)
    end
    
    %% private properties
    properties (Access = private)
        data_backup
    end
    
    %% constructor
    methods (Access = public)
        function h=apodization(varargin)
            h = h@uff(varargin{:});
        end
    end
    
    %% set methods
    methods
        function set.origin(h,in_origin)
            validateattributes(in_origin, {'uff.point'}, {'vector'})
            h.origin=in_origin;
        end
        function set.probe(h,in_probe)
            validateattributes(in_probe, {'uff.probe'}, {'scalar'})
            h.probe=in_probe;
        end
        function set.focus(h,in_scan)
            validateattributes(in_scan, {'uff.scan'}, {'scalar'})
            h.focus=in_scan;
        end
        function set.f_number(h,in_f_number)
            validateattributes(in_f_number, {'single', 'double'}, {'2d', 'finite', 'positive'})

            if(isscalar(in_f_number))
                h.f_number=[in_f_number, in_f_number];
            else
                h.f_number=in_f_number(:).';
            end
        end
        function set.tilt(h,in_tilt)
            validateattributes(in_tilt, {'single', 'double'}, {'vector', 'finite'})

            if(isscalar(in_tilt))
                h.tilt=[in_tilt, 0];
            else
                h.tilt=in_tilt(:).';
            end
        end
        function set.window(h,in_window)
            validateattributes(in_window, {'uff.window'}, {'scalar'})
            h.window=in_window;
        end
        
        function set.minimum_aperture(h,in_ap)
            validateattributes(in_ap, {'single', 'double'}, {'vector', 'finite', 'nonnegative'})

            if(isscalar(in_ap))
                h.minimum_aperture=[in_ap, in_ap];
            else
                h.minimum_aperture=in_ap(:).';
            end
        end
        
        function set.maximum_aperture(h,in_ap)
            validateattributes(in_ap, {'single', 'double'}, {'vector', 'finite', 'nonnegative'})

            if(isscalar(in_ap))
                h.maximum_aperture=[in_ap, in_ap];
            else
                h.maximum_aperture=in_ap(:).';
            end
        end

        function set.grating_lobe_angle(h,in_grating_lobe_angle)
            validateattributes(in_grating_lobe_angle, {'single', 'double'}, {'vector', 'finite', 'positive'})

            if(isscalar(in_grating_lobe_angle))
                h.grating_lobe_angle=[in_grating_lobe_angle, in_grating_lobe_angle];
            else
                h.grating_lobe_angle=in_grating_lobe_angle(:).';
            end
        end
    end
        
    %% get methods
    methods
        %% get data
        function value=get.data(h)
            h.compute();
            value = h.data_backup;
        end
              
        %% get N_elements
        function value=get.N_elements(h)
            if isempty(h.sequence)
                assert(numel(h.probe)>0,'The PROBE parameter is not set.');
                value=h.probe.N_elements;
            else
                value=length(h.sequence);
            end
            
        end
    end
    
    %% windows
    methods
        function value=rectangular(~,ratio)
            value=double(ratio<=0.5);
        end
        function value=hanning(~,ratio)
            value=double(ratio<=0.5).*(0.5 + 0.5*cos(2*pi*ratio));
        end
        function value=hamming(~,ratio)
            value=double(ratio<=0.5).*(0.53836 + 0.46164*cos(2*pi*ratio));
        end
        function value=tukey(~,ratio, roll)
            value=(ratio<=(1/2*(1-roll))) + (ratio>(1/2*(1-roll))).*(ratio<(1/2)).*0.5.*(1+cos(2*pi/roll*(ratio-roll/2-1/2)));
        end
        function value=triangle(~,ratio)
            value=double(ratio<=0.5).*(1-2*ratio);
        end
        
        %% apply window
        function data = apply_window(h, ratio_theta, ratio_phi)
            % SWITCH
            switch(h.window)
                % BOXCAR/FLAT/RECTANGULAR
                case uff.window.boxcar
                    data=h.rectangular(ratio_theta).*h.rectangular(ratio_phi);
                    % HANNING
                case uff.window.hanning
                    data=h.hanning(ratio_theta).*h.hanning(ratio_phi);
                    % HAMMING
                case uff.window.hamming
                    data=h.hamming(ratio_theta).*h.hamming(ratio_phi);
                    % TUKEY25
                case uff.window.tukey25
                    roll=0.25;
                    data=h.tukey(ratio_theta,roll).*h.tukey(ratio_phi,roll);
                    % TUKEY50
                case uff.window.tukey50
                    roll=0.50;
                    data=h.tukey(ratio_theta,roll).*h.tukey(ratio_phi,roll);
                    % TUKEY75
                case uff.window.tukey75
                    roll=0.75;
                    data=h.tukey(ratio_theta,roll).*h.tukey(ratio_phi,roll);
                    % TUKEY80
                case uff.window.tukey80
                    roll=0.80;
                    data=h.tukey(ratio_theta,roll).*h.tukey(ratio_phi,roll);
                    % TRIANGLE
                case uff.window.triangle
                    data=h.triangle(ratio_theta).*h.triangle(ratio_phi);
                otherwise
                    error('Unknown apodization type!');
            end
        end
    end
    
    %% computation methods
    methods
        
        %% compute
        function compute(h)
            
            % if no pixel matrix -> we set it at (0,0,0)
            if isempty(h.focus)
                h.focus=uff.scan('xyz',[0 0 0]);
            end
            
            % Aperture apodization
            if ~isempty(h.probe)
                h.compute_aperture_apodization();
                
            % Wave apodization
            elseif ~isempty(h.sequence)
                h.compute_wave_apodization();
            end
            
        end
        
        %% Wave apodization
        function compute_wave_apodization(h)
            assert(numel(h.sequence)>0,'uff.apodization:Scanline','The SEQUENCE parameter must be set to use uff.window.scanline apodization.');
            N_waves=numel(h.sequence);
            
            % check if overridden
            if ~isempty(h.apodization_vector)
                assert(numel(h.apodization_vector)==N_waves,'uff.apodization:dimensions','If an apodization_vector is given its size must match the number of events in the sequence.');
                
                h.data_backup = ones(h.focus.N_pixels,1)*h.apodization_vector.';
                return;
            end
            
            % NONE APODIZATION
            if(h.window==uff.window.none)
                h.data_backup=ones([h.focus.N_pixels,N_waves]);
                
            % SCALINE APODIZATION (MLA scanlines per wave)
            elseif (h.window==uff.window.scanline)
                
                % linear scan
                if isa(h.focus,'uff.linear_scan')
                    assert(N_waves==h.focus.N_x_axis*h.focus.N_y_axis/prod(h.MLA), 'The number of waves in the sequence does not match with the number of scanlines and set MLA.');
                    
                    B = zeros([N_waves, h.focus.N_x_axis, h.focus.N_y_axis]);
                    A = cat(2, cat(1, ones([h.MLA, 1]), zeros([h.focus.N_x_axis-h.MLA(1), h.MLA(2)])), ...
                        zeros([h.focus.N_x_axis, h.focus.N_y_axis-h.MLA(2)]));

                    for i = 1:h.focus.N_x_axis/h.MLA(1)
                        for j = 1:h.focus.N_y_axis/h.MLA(2)
                            B(i+(j-1)*h.focus.N_x_axis/h.MLA(1), :, :) = filter2(ones(h.MLA_overlap+1)/prod(h.MLA_overlap+1), ...
                                circshift(A, [(i-1)*h.MLA(1), (j-1)*h.MLA(2)]), 'same');
                        end
                    end

                    h.data_backup=reshape(permute(B.*ones([1, 1, 1, h.focus.N_z_axis]), [4,2,3,1]), [h.focus.N_pixels, N_waves]);
                    
                % sector scan
                elseif isa(h.focus,'uff.sector_scan')
                     assert(N_waves==h.focus.N_azimuth_axis*h.focus.N_elevation_axis/prod(h.MLA), 'The number of waves in the sequence does not match with the number of scanlines and set MLA.');
                    
                    B = zeros([N_waves, h.focus.N_azimuth_axis, h.focus.N_elevation_axis]);
                    A = cat(2, cat(1, ones([h.MLA, 1]), zeros([h.focus.N_azimuth_axis-h.MLA(1), h.MLA(2)])), ...
                        zeros([h.focus.N_azimuth_axis, h.focus.N_elevation_axis-h.MLA(2)]));

                    for i = 1:h.focus.N_azimuth_axis/h.MLA(1)
                        for j = 1:h.focus.N_elevation_axis/h.MLA(2)
                            B(i+(j-1)*h.focus.N_azimuth_axis/h.MLA(1), :, :) = filter2(ones(h.MLA_overlap+1)/prod(h.MLA_overlap+1), ...
                                circshift(A, [(i-1)*h.MLA(1), (j-1)*h.MLA(2)]), 'same');
                        end
                    end

                    h.data_backup=reshape(permute(B.*ones([1, 1, 1, h.focus.N_depth_axis]), [4,2,3,1]), [h.focus.N_pixels, N_waves]);

                else
                    error('uff.apodization:Scanline','The scan class does not support scanline based beamforming. This must be done manually, defining several scan and setting the apodization to uff.window.none.');
                end
            else
                % incidence angles
                [tan_theta, tan_phi] = incidence_wave(h);
                
                % ratios
                ratio_theta = abs(h.f_number(1).*tan_theta);
                ratio_phi = abs(h.f_number(2).*tan_phi);
                                               
                % apodization window
                h.data_backup = apply_window(h, ratio_theta, ratio_phi);
                
            end
            
            % normalize
            %h.data_backup=h.data_backup./sum(sum(h.data_backup,3),2);
        end
        
        %% Aperture apodization
        function compute_aperture_apodization(h)
            assert(numel(h.probe)>0,'The PROBE parameter must be set to compute aperture apodization.');
            
            % check if overridden by apodization_vector
            if ~isempty(h.apodization_vector)
                assert(numel(h.apodization_vector)==h.probe.N_elements || all(size(h.apodization_vector)==[h.focus.N_pixels, h.probe.N_elements]),...
                    'uff.apodization:dimensions','If an apodization_vector is given its size must match the number of elements in the probe.');

                if numel(h.apodization_vector)==h.probe.N_elements
                
                    h.data_backup = ones(h.focus.N_pixels,1)*h.apodization_vector.';
                else
                    h.data_backup = h.apodization_vector;
                end
                return;
            end
            
            % NONE APODIZATION
            if(h.window==uff.window.none)
                h.data_backup=ones(h.focus.N_pixels,h.probe.N_elements);
                
            % STA APODIZATION (just use the element closest to user setted origin)
            elseif (h.window==uff.window.sta)
                assert(~isempty(h.origin), 'origin must be set to use STA apodization')
                
                dist=sqrt((h.probe.x-h.origin.x).^2+(h.probe.y-h.origin.y).^2+(h.probe.z-h.origin.z).^2);
                h.data_backup=ones(h.focus.N_pixels,1)*double(dist==min(dist(:)));
                
            else
                % incidence 
                [tan_theta, tan_phi] = incidence_aperture(h);
                
                % ratios F*tan(angle)
                ratio_theta = abs(h.f_number(1).*tan_theta);
                ratio_phi = abs(h.f_number(2).*tan_phi);
                
                % apodization window
                h.data_backup = apply_window(h, ratio_theta, ratio_phi);
                
            end
            
            % normalize
            %h.data_backup=h.data_backup./sum(sum(h.data_backup,3),2);
            
        end
        
        %% Incidence aperture
        function [tan_theta, tan_phi, distance] = incidence_aperture(h)

            % Location of the elements
            x = ones([h.focus.N_pixels,1]) .* h.probe.x.';
            y = ones([h.focus.N_pixels,1]) .* h.probe.y.';
            z = ones([h.focus.N_pixels,1]) .* h.probe.z.';
            
            % If the apodization center has not been set by the user
            if isempty(h.origin)
                if isa(h.probe,'uff.curvilinear_array')
                    h.origin = uff.point('xyz', [0, 0, -h.probe.radius]);
                elseif isa(h.probe,'uff.curvilinear_matrix_array')
                    h.origin = uff.point('xyz', [0, 0, -h.probe.radius_x]);
                elseif isa(h.focus, 'uff.sector_scan')
                    h.origin = h.focus.origin;
                end
            end

            % If we have a curvilinear array
            if isa(h.probe,'uff.curvilinear_array') || isa(h.probe,'uff.curvilinear_matrix_array')

                % SF the probe class already includes the quantities theta and
                % phi that define the element orientation
                element_azimuth = atan2(x-h.origin.x, z-h.origin.z);
                
                pixel_azimuth = atan2(h.focus.x-h.origin.x, h.focus.z-h.origin.z);
                pixel_distance = sqrt((h.focus.x-h.origin.x).^2+(h.focus.z-h.origin.z).^2);
                
                x_dist = h.origin.z .* (pixel_azimuth-element_azimuth);
                y_dist = h.origin.y - y;
                z_dist = pixel_distance .* ones([1,h.probe.N_elements])-h.origin.z;

            % If we have a sector scan, the apodization is centered at the
            % origin of the field of view
            elseif isa(h.focus,'uff.sector_scan')
                if(isscalar(h.origin))
                    x0 = h.origin.x;
                    y0 = h.origin.y;
                    z0 = h.origin.z;
                else
                    x0 = ones([h.focus.N_depth_axis,1]) .* [h.origin.x];
                    y0 = ones([h.focus.N_depth_axis,1]) .* [h.origin.y];
                    z0 = ones([h.focus.N_depth_axis,1]) .* [h.origin.z];
                end

                pixel_distance = sqrt((h.focus.x-x0(:)).^2+(h.focus.y-y0(:)).^2+(h.focus.z-z0(:)).^2);
                
                x_dist = x - x0(:);
                y_dist = y - y0(:);
                z_dist = pixel_distance .* ones([1, h.probe.N_elements]);
                    
            % If not, then we have a flat probe and a linear scan. In this
            % case the aperture is centered at each beam's [x, y] coordinate
            else
                if isempty(h.origin)
                    x_dist = h.focus.x - x;
                    y_dist = h.focus.y - y;
                    z_dist = h.focus.z - z;
                else
                    if(isscalar(h.origin))
                        x0 = h.origin.x;
                        y0 = h.origin.y;
                        z0 = h.origin.z;
                    else
                        x0 = ones([h.focus.N_depth_axis,1]) .* [h.origin.x];
                        y0 = ones([h.focus.N_depth_axis,1]) .* [h.origin.y];
                        z0 = ones([h.focus.N_depth_axis,1]) .* [h.origin.z];
                    end

                    pixel_distance = sqrt((h.focus.x-x0(:)).^2+(h.focus.y-y0(:)).^2+(h.focus.z-z0(:)).^2);

                    x_dist = x - x0(:);
                    y_dist = y - y0(:);
                    z_dist = pixel_distance .* ones([1, h.probe.N_elements]);
                end
            end

            % Apply tilt
            [x_dist, y_dist, z_dist] = tools.rotate_points(x_dist, y_dist, z_dist, h.tilt(1), h.tilt(2));
            zx_dist = z_dist;
            zy_dist = z_dist;

            % Apply minimum aperture
            zx_dist(abs(z_dist)<=h.minimum_aperture(1)*h.f_number(1)) = ...
                sign(zx_dist(abs(z_dist)<=h.minimum_aperture(1)*h.f_number(1)))*h.minimum_aperture(1)*h.f_number(1);
            zy_dist(abs(z_dist)<=h.minimum_aperture(2)*h.f_number(2)) = ...
                sign(zy_dist(abs(z_dist)<=h.minimum_aperture(2)*h.f_number(2)))*h.minimum_aperture(2)*h.f_number(2);

            % Apply maximum aperture
            zx_dist(abs(z_dist)>=h.maximum_aperture(1)*h.f_number(1)) = ...
                sign(zx_dist(abs(z_dist)>=h.maximum_aperture(1)*h.f_number(1)))*h.maximum_aperture(1)*h.f_number(1);
            zy_dist(abs(z_dist)>=h.maximum_aperture(2)*h.f_number(2)) = ...
                sign(zy_dist(abs(z_dist)>=h.maximum_aperture(2)*h.f_number(2)))*h.maximum_aperture(2)*h.f_number(2);

            % Calculate tangents & distance
            tan_theta = x_dist./zx_dist;
            tan_phi = y_dist./zy_dist;
            distance = z_dist;
        end

      
        %% Incidence wave
        function [tan_theta, tan_phi, distance] = incidence_wave(h)

            assert(numel(h.sequence)>0,'The SEQUENCE is not set.');
            tan_theta=zeros([h.focus.N_pixels,length(h.sequence)]);
            tan_phi=zeros([h.focus.N_pixels,length(h.sequence)]);
            distance=zeros([h.focus.N_pixels,length(h.sequence)]);

            for n=1:length(h.sequence)
                % Plane Wave case
                if (h.sequence(n).wavefront==uff.wavefront.plane||isinf(h.sequence(n).source.distance))

                    % Probably needs to be adapted in case plane waves are used in combination with a non-zero origin.
                    tan_theta(:,n)=ones(h.focus.N_pixels,1)*tan(h.sequence(n).source.azimuth - h.tilt(1));
                    tan_phi(:,n)=ones(h.focus.N_pixels,1)*tan(h.sequence(n).source.elevation - h.tilt(2));
                    distance(:,n) = h.focus.z;

                % Diverging Wave or Converging Wave case
                else
                    % source -> pixel vectors
                    SP = [ h.focus.x-h.sequence(n).source.x, ...
                           h.focus.y-h.sequence(n).source.y, ...
                           h.focus.z-h.sequence(n).source.z];

                    % origin -> pixel vectors
                    OP = [ h.focus.x-h.sequence(n).origin.x, ...
                           h.focus.y-h.sequence(n).origin.y, ...
                           h.focus.z-h.sequence(n).origin.z];

                    % origin -> source vector
                    OS = [ h.sequence(n).source.x-h.sequence(n).origin.x, ...
                           h.sequence(n).source.y-h.sequence(n).origin.y, ...
                           h.sequence(n).source.z-h.sequence(n).origin.z];
                    
                    % STA case
                    if norm(h.sequence(n).source.xyz-h.sequence(n).origin.xyz,2)<=eps
                        if isa(h.probe,'uff.curvilinear_array')
                            OS = [ h.sequence(n).source.x, ...
                                   h.sequence(n).source.y, ...
                                   h.sequence(n).source.z+h.probe.radius];
                        elseif isa(h.probe,'uff.curvilinear_matrix_array')
                            OS = [ h.sequence(n).source.x, ...
                                   h.sequence(n).source.y, ...
                                   h.sequence(n).source.z+h.probe.radius_x];
                        else
                            OS = [0,0,1];
                        end
                    end


                    % find unit vectors
                    zu = OS / sqrt(sum(OS.^ 2, 2));
                    yu = cross(zu, [1, 0, 0]);
                    xu = cross(zu, yu);

                    z_dist = SP * zu.';
                    x_dist = SP * xu.';
                    y_dist = SP * yu.';

                    zx_dist = z_dist;
                    zy_dist = z_dist;

                    % Apply minimum aperture
                    zx_dist(abs(z_dist)<=h.minimum_aperture(1)*h.f_number(1)) = ...
                        sign(zx_dist(abs(z_dist)<=h.minimum_aperture(1)*h.f_number(1)))*h.minimum_aperture(1)*h.f_number(1);
                    zy_dist(abs(z_dist)<=h.minimum_aperture(2)*h.f_number(2)) = ...
                        sign(zy_dist(abs(z_dist)<=h.minimum_aperture(2)*h.f_number(2)))*h.minimum_aperture(2)*h.f_number(2);

                    % Apply maximum aperture
                    zx_dist(abs(z_dist)>=h.maximum_aperture(1)*h.f_number(1)) = ...
                        sign(zx_dist(abs(z_dist)>=h.maximum_aperture(1)*h.f_number(1)))*h.maximum_aperture(1)*h.f_number(1);
                    zy_dist(abs(z_dist)>=h.maximum_aperture(2)*h.f_number(2)) = ...
                        sign(zy_dist(abs(z_dist)>=h.maximum_aperture(2)*h.f_number(2)))*h.maximum_aperture(2)*h.f_number(2);

                    % Apply grating lobe masking
                    zx_dist(abs(atan2(OP(:,1),OP(:,3))-atan2(OS(1),OS(3)))>0.5*h.grating_lobe_angle(1)) = eps;
                    zy_dist(abs(atan2(OP(:,2),OP(:,3))-atan2(OS(2),OS(3)))>0.5*h.grating_lobe_angle(2)) = eps;

                    % Calculate tangents & distance
                    tan_theta(:,n) = x_dist./zx_dist;
                    tan_phi(:,n) = y_dist./zy_dist;
                    distance(:,n) = z_dist;
                end
            end
        end
    end
    
    %% display methods
    methods
        
        function figure_handle = plot(h, figure_handle_in, n_element)
            % PLOT Plot apodization
            if nargin>1 && ~(isempty(figure_handle_in))
                figure_handle = figure(figure_handle_in);
            else
                figure_handle = figure();
            end
            
            if nargin <3
                n_element = ceil(size(h.data,2)/2);
            end
                        
            isreceive = isempty(h.sequence);
            
            switch class(h.focus)
                case 'uff.linear_scan'
                    dim = [h.focus.N_z_axis, h.focus.N_x_axis, h.focus.N_y_axis];
                case 'uff.sector_scan'
                    dim = [h.focus.N_depth_axis, h.focus.N_azimuth_axis, h.focus.N_elevation_axis];
                otherwise
                    error('Plotting apodization is only supported for linear and sector scans')
            end

            X = reshape(h.focus.x, dim);
            Y = reshape(h.focus.y, dim);
            Z = reshape(h.focus.z, dim);

            x0 = ceil(dim/2);

            figure_handle.UserData.CData = reshape(h.data, [dim, size(h.data, 2)]);
            figure_handle.UserData.dim = dim;
            figure_handle.UserData.n_element = n_element;
            figure_handle.UserData.xyz.x = X;
            figure_handle.UserData.xyz.y = Y;
            figure_handle.UserData.xyz.z = Z;

            iptPointerManager(figure_handle);

            pointerBehaviour.exitFcn = @(fig,currentPoint) set(fig, 'Pointer','arrow');
            pointerBehaviour.enterFcn = @(fig,currentPoint) set(fig, 'Pointer','crosshair');
            pointerBehaviour.traverseFcn = [];

            tiledlayout(1,2,'TileSpacing','compact','Padding','compact')

            % Tile 1 - 3-D rendering of the apodization matrix for a
            % specific element
            ax(1) = nexttile();

            % Add navigation buttons
            tb = axtoolbar('default');
            axtoolbarbtn(tb, 'push', 'Icon', ...
                fullfile(matlabroot, 'toolbox/shared/controllib/general/resources/toolstrip_icons/Forward_16.png'), ...
                'Tooltip', 'Next','ButtonPushedFcn', @nextElementFcn);
            axtoolbarbtn(tb, 'push', 'Icon', ...
                fullfile(matlabroot, 'toolbox/shared/controllib/general/resources/toolstrip_icons/Back_16.png'), ...
                'Tooltip', 'Previous','ButtonPushedFcn', @previousElementFcn);

            if dim(2) > 1 && dim(3) == 1
                surface(squeeze(X(:,:,x0(3)))*1e3,squeeze(Y(:,:,x0(3)))*1e3,squeeze(Z(:,:,x0(3)))*1e3, ...
                    squeeze(figure_handle.UserData.CData(:,:,x0(3),figure_handle.UserData.n_element)), ...
                    'LineStyle', 'none', 'Tag', 'apod.zx', 'ButtonDownFcn', @updateFcn, ...
                    'ApplicationData', struct('iptPointerBehavior', pointerBehaviour), 'UserData', struct('dim', 'zx', 'y', x0(3)))
            end

            if dim(2) == 1 && dim(3) > 1
                surface(squeeze(X(:,x0(2),:))*1e3,squeeze(Y(:,x0(2),:))*1e3,squeeze(Z(:,x0(2),:))*1e3, ...
                    squeeze(figure_handle.UserData.CData(:,x0(2),:,figure_handle.UserData.n_element)), ...
                    'LineStyle', 'none', 'Tag', 'apod.zy', 'ButtonDownFcn', @updateFcn, ...
                    'ApplicationData', struct('iptPointerBehavior', pointerBehaviour), 'UserData', struct('dim', 'zy', 'x', x0(2)))
            end

            if dim(2) > 1 && dim(3) > 1
                  surface(squeeze(X(x0(1),:,:))*1e3,squeeze(Y(x0(1),:,:))*1e3,squeeze(Z(x0(1),:,:))*1e3, ...
                    squeeze(figure_handle.UserData.CData(x0(1),:,:,figure_handle.UserData.n_element)), ...
                    'LineStyle', 'none', 'Tag', 'apod.xy', 'ButtonDownFcn', @updateFcn, ...
                    'ApplicationData', struct('iptPointerBehavior', pointerBehaviour), 'UserData', struct('dim', 'xy', 'z', x0(1)))
            end

            xlabel('x [mm]')
            ylabel('y [mm]')
            zlabel('z [mm]')
            grid on
            box on
            axis equal tight
            ylabel(colorbar(), 'Apodization')
            set(gca, 'ZDir', 'reverse')
            caxis([0, 1])
            view(3)
            if isreceive
                ax(1).UserData.title = 'Receive apodization rendering for element %d';
            else
                ax(1).UserData.title = 'Transmit apodization rendering for wave %d';
            end
            title(ax(1), sprintf(ax(1).UserData.title, n_element))


            % Tile 2 - Plot for all apodization values at a specific pixel
            ax(2) = nexttile();
            plot(squeeze(figure_handle.UserData.CData(1,1,1,:)), 'Tag', 'apod.e');
            grid on
            axis tight
            ylim([0, 1])
            if isreceive
                ax(2).UserData.title = 'Receive apodization at pixel [%0.2f, %0.2f, %0.2f] mm';
                xlabel('Element')
            else
                ax(2).UserData.title = 'Transmit apodization at pixel [%0.2f, %0.2f, %0.2f] mm';
                xlabel('wave')
            end
            ylabel('Apodization weight')

            title(ax(2), sprintf(ax(2).UserData.title,X(1),Y(1),Z(1)))


        end
    end
end

function updateFcn(obj, eventObj)
fig = ancestor(obj, 'figure');
xyz = eventObj.IntersectionPoint;

gHandle = findobj(fig, 'Tag', 'apod.e');

[~, I] = min(sqrt(sum((xyz-[obj.XData(:), obj.YData(:), obj.ZData(:)]).^2, 2)), [], 1);
[i, j, k] = ind2sub(fig.UserData.dim,I);

gHandle.YData = squeeze(fig.UserData.CData(i,j,k,:));
title(gHandle.Parent, sprintf(gHandle.Parent.UserData.title, xyz(1), xyz(2), xyz(3)))
end

function previousElementFcn(obj, ~)
fig = ancestor(obj, 'figure');

if fig.UserData.n_element == 1
    return
else
    fig.UserData.n_element = fig.UserData.n_element - 1;
    gHandle = findobj(fig, '-regexp', 'Tag', 'apod.[xyz]');

    for n = 1:length(gHandle)
        switch gHandle(n).UserData.dim
            case 'zx'
                gHandle(n).CData = squeeze(fig.UserData.CData(:,:,gHandle(n).UserData.y,fig.UserData.n_element));
            case 'zy'
                gHandle(n).CData = squeeze(fig.UserData.CData(:,gHandle(n).UserData.x,:,fig.UserData.n_element));
            case 'xy'
                gHandle(n).CData = squeeze(fig.UserData.CData(gHandle(n).UserData.z,:,:,fig.UserData.n_element));
        end
    end
    title(gHandle(1).Parent, sprintf(gHandle(1).Parent.UserData.title, fig.UserData.n_element))
end
end

function nextElementFcn(obj, ~)
fig = ancestor(obj, 'figure');

if fig.UserData.n_element == size(fig.UserData.CData, 4)
    return
else
    fig.UserData.n_element = fig.UserData.n_element + 1;
    gHandle = findobj(fig, '-regexp', 'Tag', 'apod.[xyz]');

    for n = 1:length(gHandle)
        switch gHandle(n).UserData.dim
            case 'zx'
                gHandle(n).CData = squeeze(fig.UserData.CData(:,:,gHandle(n).UserData.y,fig.UserData.n_element));
            case 'zy'
                gHandle(n).CData = squeeze(fig.UserData.CData(:,gHandle(n).UserData.x,:,fig.UserData.n_element));
            case 'xy'
                gHandle(n).CData = squeeze(fig.UserData.CData(gHandle(n).UserData.z,:,:,fig.UserData.n_element));
        end
    end
    title(gHandle(1).Parent, sprintf(gHandle(1).Parent.UserData.title, fig.UserData.n_element))
end
end
