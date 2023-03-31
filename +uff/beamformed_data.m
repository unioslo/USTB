classdef beamformed_data < uff
    %BEAMFORMED_DATA   UFF class to hold beamformed data
    %   BEAMFORMED_DATA contains beamformed ultrasound data, i.e. a spacial
    %   map. Data is stored in the property _data_ with
    %   dimensions:
    %
    %   [pixel dimension x channel dimension x wave dimension x frame dimension]
    %
    %   Compulsory properties:
    %       scan                       % SCAN object or array of SCAN objects
    %       data                       % data [pixel x channel x wave x frame]
    %
    %   Optional properties:
    %       phantom                    % PHANTOM object
    %       sequence                   % array of WAVE objects
    %       probe                      % PROBE object
    %       pulse                      % PULSE object
    %       sampling_frequency         % Sampling frequency in the depth direction in [Hz]
    %       modulation_frequency       % Modulation frequency in [Hz]
    %
    %   Example:
    %         beam_dta = uff.beamformed_data();
    %
    %   See also UFF.CHANNEL_DATA, UFF.BEAMFORMED_DATA, UFF.SCAN
    
    %   authors: Alfonso Rodriguez-Molares (alfonso.r.molares@ntnu.no)
    %            Ole Marius Hoel Rindal (olemarius@olemarius.net)
    %
    %   $Last updated: 2017/06/07$
    
    %% compulsory properties
    properties  (Access = public)
        scan                       % SCAN object or array of SCAN objects
        data                       % data [pixel x channel x wave x frame]
    end
    
    %% optional properties
    properties  (Access = public)
        phantom                    % PHANTOM object
        sequence                   % array of WAVE objects
        probe                      % PROBE object
        pulse                      % PULSE object
        sampling_frequency         % Sampling frequency in the depth direction in [Hz]
        modulation_frequency       % Modulation frequency in [Hz]
        frame_rate = 1             % Framerate for Video or GIF file to be saved [fps]
    end
    
    %% dependent properties
    properties  (Dependent)
        N_pixels                    % number of pixels
        N_channels                  % number of channels
        N_waves                     % number of waves (transmit events)
        N_frames                    % number of frames
    end
    
    %% private properties
    properties (Access = private)
       current_frame             % If multi frame, this is the current frame shown 
       all_images
       image_handle
       in_title
       play_loop
       figure_handle
    end
    
    %% constructor -> uff constructor
    methods (Access = public)
        function h=beamformed_data(varargin)
            h = h@uff(varargin{:});
        end
    end
    
    %% display methods
    methods (Access = public)
        function figure_handle=plot(h,parent_handle_in,in_title,dynamic_range,compression,indeces,frame_idex,spatial_units,mode)
            %PLOT Plots beamformed data
            %
            % Usage: figure_handle=plot(figure_handle,title,dynamic_range)
            %
            %   figure_handle   Handle to the figure to plot to (default: none)
            %   title           Figure title (default: none)
            %   dynamic_range   Displayed dynamic range (default: 60 dB)
            %   compression     String specifying compression type: 'log','none','sqrt' (default: 'log')
            %   indeces         Pair of integers [nrx ntx] indicating receive and transmit events (default: [])
            %   indeces         Tripler of integers [nrx ntx frame] indicating which receive and transmit and frame must be plotted (default: [])
            
            if (nargin>1 && ~isempty(parent_handle_in) && isa(parent_handle_in,'matlab.ui.Figure')) || ...
                    (nargin>1 && ~isempty(parent_handle_in) && isa(parent_handle_in,'double'))
                h.figure_handle=figure(parent_handle_in);
                axis_handle = gca(h.figure_handle);
                hold on;
            elseif nargin>1 && ~isempty(parent_handle_in) && isa(parent_handle_in,'matlab.graphics.axis.Axes')
                axis_handle = parent_handle_in;
                h.figure_handle = parent_handle_in.Parent;
            else
                h.figure_handle=figure();
                parent_handle_in = h.figure_handle;
                axis_handle = gca(h.figure_handle);
            end
            
            if nargin<3
                h.in_title='Beamformed data';
            else
                h.in_title = in_title;
            end
            if nargin<4||isempty(dynamic_range)
                dynamic_range=60;
            end
            if nargin<5||isempty(compression)
                compression='log';
            end
            if nargin<6||isempty(indeces)
                data=h.data; %#ok<*PROPLC> 
            else
                data=h.data(:,indeces(1),indeces(2),indeces(3));
            end
            if nargin<7||isempty(frame_idex)
                data=data;
            else
                data=data(:,:,:,frame_idex);
            end
            if nargin<8||isempty(spatial_units)
                spatial_units='mm';
            end
            if nargin<9||isempty(mode)
                mode='normal';
                font_color = [0 0 0];
                background_color = [1 1 1];
            end
            
            if strcmp(mode,'dark')
                font_color = [1 1 1];
                background_color = [0 0 0];
            end
            
            %Draw the image
            h.draw_image(axis_handle,h.in_title,dynamic_range,compression,data,spatial_units,font_color,background_color);
            
            % If more than one frame, add the GUI buttons
            if prod(size(h.data, [2, 3, 4])) > 1 && (isa(parent_handle_in, 'matlab.ui.Figure') || isempty(parent_handle_in)) 
                h.current_frame = 1;
                h.add_buttons(h.figure_handle);      
                h.play_loop = false;
                title([h.in_title,', Frame = ',num2str(h.current_frame),'/',num2str(size(h.all_images,3))],'Color',font_color);
            end
            
            set(h.figure_handle,'Color',background_color);
            if isa(h.figure_handle,'matlab.ui.Figure')
                h.figure_handle.InvertHardcopy = 'off'; %To be able to save background color
            end
            figure_handle = h.figure_handle;
        end
        
        function draw_image(h,axis_handle,in_title,dynamic_range,compression,data,spatial_units,font_color,background_color)
            
            [~, Nrx, Ntx, Nframes] = size(data);
            
            % compress values
            switch compression
                case 'log'
                    envelope=abs(data);
                    envelope=20*log10(envelope./max(envelope(:)));
                    max_value=0;
                    min_value=-dynamic_range;
                case 'sqrt'
                    envelope=sqrt(abs(data));
                    max_value=prctile(envelope(:),99.9);
                    min_value=prctile(envelope(:),1);
                case 'none'
                    envelope=data;
                    max_value=max(envelope(:));
                    min_value=min(envelope(:));
                case 'abs'
                    envelope=abs(data);
                    max_value=max(envelope(:));
                    min_value=min(envelope(:));
            end
            
            switch(spatial_units)
                case 'm'
                    scale_factor=1;
                case 'mm'
                    scale_factor=1e3;
                case 'cm'
                    scale_factor=1e2;
                case 'km'
                    scale_factor=1e-3;                    
            end
            
            switch class(h.scan)
                case 'uff.linear_scan'
                    x_matrix=reshape(h.scan.x,[h.scan(1).N_z_axis h.scan(1).N_x_axis]);
                    z_matrix=reshape(h.scan.z,[h.scan(1).N_z_axis h.scan(1).N_x_axis ]);
                    h.all_images = reshape(envelope,[h.scan.N_z_axis h.scan.N_x_axis Nrx*Ntx*Nframes]);
                    h.image_handle = pcolor(axis_handle,x_matrix*scale_factor,z_matrix*scale_factor,h.all_images(:,:,1));
                    shading(axis_handle,'flat');
                    set(axis_handle,'color',font_color);
                    set(axis_handle,'YDir','reverse');
                    axis(axis_handle,'tight','equal');
                    cbar = colorbar(axis_handle);
                    set(cbar,'color',font_color);
                    colormap(axis_handle,'gray');
                    xlabel(axis_handle,['x[' spatial_units ']'],'color',font_color); ylabel(axis_handle,['z[' spatial_units ']'],'color',font_color);
                    caxis(axis_handle,[min_value max_value]);
                    title(axis_handle,in_title,'Color',font_color);
                    set(gca,'YColor',font_color); 
                    set(gca,'XColor',font_color); 
                    box off
                    drawnow;
                case 'uff.linear_3D_scan'
                    [radial_matrix axial_matrix] = meshgrid(h.scan(1).radial_axis,h.scan(1).axial_axis);
                    h.all_images = reshape(envelope,[h.scan.N_axial_axis h.scan.N_radial_axis Nrx*Nrx*Nframes]);
                    [az,el] = view();
                    if (el==90)
                        % plot in 2D
                        h.image_handle = pcolor(axis_handle,radial_matrix*scale_factor,axial_matrix*scale_factor,h.all_images(:,:,1));
                        shading(axis_handle,'flat');
                        set(axis_handle,'YDir','reverse');
                        axis(axis_handle,'tight','equal');
                        colorbar(axis_handle);
                        colormap(axis_handle,'gray');
                        xlabel(axis_handle,['radial[' spatial_units ']']); ylabel(axis_handle,['axial[' spatial_units ']']);
                        caxis(axis_handle,[min_value max_value]);
                        title(axis_handle,in_title);
                    else
                        % plot in 3D
                        x_matrix=reshape(h.scan.x,[h.scan(1).N_axial_axis h.scan(1).N_radial_axis]);
                        y_matrix=reshape(h.scan.y,[h.scan(1).N_axial_axis h.scan(1).N_radial_axis]);
                        z_matrix=reshape(h.scan.z,[h.scan(1).N_axial_axis h.scan(1).N_radial_axis]);
                        surface(axis_handle);
                        surface(x_matrix*scale_factor,y_matrix*scale_factor,z_matrix*scale_factor,h.all_images(:,:,1));
                        shading(axis_handle,'flat');
                        %set(axis_handle,'YDir','reverse');
                        axis(axis_handle,'tight','equal');
                        colorbar(axis_handle);
                        colormap(axis_handle,'gray');
                        xlabel(axis_handle,['x[' spatial_units ']']);
                        ylabel(axis_handle,['y[' spatial_units ']']);
                        zlabel(axis_handle,['z[' spatial_units ']']);
                        caxis(axis_handle,[min_value max_value]);
                        title(axis_handle,in_title);
                    end
                    drawnow;
                case 'uff.sector_scan'
                    x_matrix=reshape(h.scan.x,[h.scan(1).N_depth_axis h.scan(1).N_azimuth_axis]);
                    z_matrix=reshape(h.scan.z,[h.scan(1).N_depth_axis h.scan(1).N_azimuth_axis ]);
                    h.all_images = reshape(envelope,[h.scan.N_depth_axis h.scan.N_azimuth_axis Nrx*Ntx*Nframes]);
                    h.image_handle = pcolor(axis_handle,x_matrix*scale_factor,z_matrix*scale_factor,h.all_images(:,:,1));
                    shading(axis_handle,'flat');
                    set(axis_handle,'YDir','reverse');
                    axis(axis_handle,'tight','equal');
                    cbar = colorbar(axis_handle);
                    if strcmp(compression, 'log')
                        ylabel(cbar, 'dB');
                    end
                    set(cbar,'color',font_color);
                    colormap(axis_handle,'gray');
                    xlabel(axis_handle,['x[' spatial_units ']']); 
                    ylabel(axis_handle,['z[' spatial_units ']']);
                    caxis(axis_handle,[min_value max_value]);
                    title(axis_handle,in_title,'color',font_color);
                    set(gca,'YColor',font_color); 
                    set(gca,'XColor',font_color); 
                    set(gca,'Color',background_color);
                    set(gca,'GridColor',font_color);
                    set(gca,'layer', 'top');
                    box off
                    drawnow;
                case 'uff.scan'
                    error('The uff.scan cannot be plotted automatically as it can contain arbitrarily placed voxel. The data must be reshaped and plotted manually. To avoid this, you may use the structures uff.linear_scan and uff.sector_scan instead.');
                otherwise
                    error(sprintf('Dont know how to plot a %s yet. Sorry!',class(h.scan)));
            end
        end
        
        function img = get_image(h,compression)
            if nargin < 2
                compression = 'log';
            end
            switch compression
                case 'log'
                    envelope=abs(h.data);
                    envelope=20*log10(envelope./max(envelope(:)));
                case 'sqrt'
                    envelope=sqrt(abs(h.data));
                case 'abs'
                    envelope=abs(h.data);
                case 'none-complex' %If we want the complex data before envelope detection
                    envelope=h.data;
                case 'none'
                    envelope=h.data;
            end
            switch class(h.scan)
                case 'uff.linear_scan'
                    img = reshape(envelope,[h.scan.N_z_axis h.scan.N_x_axis size(h.data,3) size(h.data,4)]);
                case 'uff.sector_scan'
                    img = reshape(envelope,[h.scan.N_depth_axis h.scan.N_azimuth_axis size(h.data,3) size(h.data,4)]);
                otherwise
                    error(sprintf('Dont know how to plot on a %s yet. Sorry!',class(b_data.scan)));
            end
        end
        
        function h = calculate_sampling_frequency(h,c)
            assert(exist('c')==1,'Please give speed of sound as input');
            % calculate sampling frequency
            if isa(h.scan,'uff.linear_scan')
                dz = h.scan.z_step;
            elseif isa(h.scan,'uff.sector_scan')
                dz = h.scan.depth_step;
            end
            h.sampling_frequency = (c/dz/2); % effective sampling frequency (Hz)
        end
    end
    
    %% set methods
    methods
        function h=set.phantom(h,in_phantom)
            if ~isempty(in_phantom)
                assert(isa(in_phantom,'uff.phantom'), 'The input is not a PHANTOM class. Check HELP PHANTOM.');
            end
            h.phantom=in_phantom;
        end
        function h=set.pulse(h,in_pulse)
            if ~isempty(in_pulse)
                assert(isa(in_pulse,'uff.pulse'), 'The input is not a PULSE class. Check HELP PULSE.');
            end
            h.pulse=in_pulse;
        end
        function h=set.probe(h,in_probe)
            if ~isempty(in_probe)
                assert(isa(in_probe,'uff.probe'), 'The input is not a PROBE class. Check HELP PROBE.');
            end
            h.probe=in_probe;
        end
        function h=set.sequence(h,in_wave)
            if ~isempty(in_wave)
                assert(isa(in_wave,'uff.wave'), 'The input is not a WAVE class. Check HELP WAVE.');
            end
            h.sequence=in_wave;
        end
        function h=set.scan(h,in_scan)
            if ~isempty(in_scan)
                assert(isa(in_scan,'uff.scan'), 'The input is not a SCAN class. Check HELP SCAN.');
            end
            h.scan=in_scan;
        end
        function h=set.data(h,in_data)
            % some checking is due here
            h.data=in_data;
        end
    end
    
    %% get methods of dependent variables
    methods
        function value=get.N_pixels(h)
            value=size(h.data,1);
        end
        function value=get.N_channels(h)
            value=size(h.data,2);
        end
        function value=get.N_waves(h)
            value=size(h.data,3);
        end
        function value=get.N_frames(h)
            value=size(h.data,4);
        end
    end
    
    %% GUI functions
    methods (Access = private)
        function add_buttons(h,parent_handle)            
            uicontrol('Parent',parent_handle,'Style','pushbutton','String','Previous frame','Units','normalized','Position',[0.12 0.95 0.2 0.05],'Visible','on','Callback',{@h.plot_previous_frame,h});
            uicontrol('Parent',parent_handle,'Style','pushbutton','String','Play movie loop','Units','normalized','Position',[0.32 0.95 0.2 0.05],'Visible','on','Callback',{@h.play_movie_loop,h});
            uicontrol('Parent',parent_handle,'Style','pushbutton','String','Next frame','Units','normalized','Position',[0.52 0.95 0.2 0.05],'Visible','on','Callback',{@h.plot_next_frame,h});
            uicontrol('Parent',parent_handle,'Style','pushbutton','String','Save','Units','normalized','Position',[0.72 0.95 0.2 0.05],'Visible','on','Callback',{@h.save_movie_loop,h});
        end
        
        function plot_previous_frame(h,var1,var2,var3)
            if h.current_frame-1 > 0
                h.current_frame = h.current_frame - 1;
                set(h.image_handle,'CData',h.all_images(:,:,h.current_frame));
                title([h.in_title,', Frame = ',num2str(h.current_frame),'/',num2str(size(h.all_images,3))]);
            end
        end
        
        function plot_next_frame(h,var1,var2,var3)
            if h.current_frame+1 <= size(h.all_images,3)
                h.current_frame = h.current_frame + 1;
                set(h.image_handle,'CData',h.all_images(:,:,h.current_frame));
                title([h.in_title,', Frame = ',num2str(h.current_frame),'/',num2str(size(h.all_images,3))]);
            end
        end
        
        function play_movie_loop(h,var1,var2,var3)
            h.play_loop = ~h.play_loop;
            while(h.play_loop)
                try
                        h.current_frame = h.current_frame+1;
                        if h.current_frame > size(h.all_images,3)
                        h.current_frame = 1;
                        end
                        
                        set(h.image_handle,'CData',h.all_images(:,:,h.current_frame));
                        title([h.in_title,', Frame = ',num2str(h.current_frame),'/',num2str(size(h.all_images,3))]);
                        drawnow();
                        pause(1/h.frame_rate);
                catch ME
                    if strcmp(ME.identifier,'MATLAB:class:InvalidHandle')
                        %The Figure was closed while the video was running
                        break
                    else
                        rethrow(ME)
                    end
                end
            end
        end
        
         function save_movie_loop(h,~,~,~)
             [filename,path,filterindex] = uiputfile({'*.mp4','MPEG-4 (*.mp4)';'*.avi','Motion JPEG AVI (*.avi)'}, 'Save movie as');
             switch filterindex
                 case 0
                     return;
                 case 1
                     vidObj = VideoWriter([path,filesep,filename],'MPEG-4');
                 case 2
                     vidObj = VideoWriter([path,filesep,filename],'Motion JPEG AVI');
             end
             vidObj.Quality = 100;
             vidObj.FrameRate = h.frame_rate;
             open(vidObj);
             for i = 1:size(h.all_images,3)
                 
                 h.image_handle.CData=h.all_images(:,:,i);
                 title([h.in_title,', Frame = ',num2str(i),'/',num2str(size(h.all_images,3))]);
                 writeVideo(vidObj, getframe(h.figure_handle));
                 
             end
             close(vidObj)
        end
    end
    
    methods (Access = public )
         function save_as_gif(h,filename)
             if nargin < 2
                FileName = uiputfile('movie.gif','Save gif loop as');
             else
                FileName = filename;
             end
             
             delay_time = 1/h.frame_rate;

             for i = 1:size(h.all_images,3)
                 
                 set(h.image_handle,'CData',h.all_images(:,:,i));
                 title([h.in_title,', Frame = ',num2str(i),'/',num2str(size(h.all_images,3))]);
                 drawnow();
                 frame = getframe(gcf);
                 im = frame2im(frame);
                 [imind,cm] = rgb2ind(im,256);
                 
                 if i == 1
                     imwrite(imind,cm,FileName,'gif', 'Loopcount',inf, 'DelayTime',delay_time);
                 else
                     imwrite(imind,cm,FileName,'gif','WriteMode','append', 'DelayTime',delay_time);
                 end
                 
             end
         end
    end
end