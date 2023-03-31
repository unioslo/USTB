classdef alpinion < handle
    %ALPINION   Class for reading Alpinion research scanner data to USTB
    
    %   authors: Ole Marius Hoel Rindal (olemarius@olemarius.net)
    %   $Date: 2017/04/05$
    
    properties (Access = public)
        data_folder                    %Name on the folder with Alpinion data
    end
    
    %% Constructor
    methods (Access = public)
        function h = alpinion(data_folder)
            %ALPINION Constructor of the Alpinion class
            %
            if exist('data_folder')h.data_folder = data_folder;end
        end
    end
    
    methods (Access = private)
        function [reordered_data] = reorder_chdata(h,sc_idx, elementNum, scNum, channelNum, data)
            data64ch = [data(:,:,1) ; data(:,:,2)];
            
            MuxRatio = elementNum/scNum;
            
            sc_idx1 = floor(sc_idx*MuxRatio);
            
            start_idx = sc_idx1-channelNum/2;
            k = rem(channelNum*3 + start_idx, channelNum) + 1;
            idx1 = [k:1:64];
            idx2 = [1:1:k-1];
            reorder_idx= [idx1 idx2];
            
            reordered_data(:,:) = data64ch(reorder_idx,:);
            
            % trim side data
            i = start_idx;
            trim_idx = [i : 1 : i+channelNum-1];
            reordered_data(find(trim_idx<0),:) = 0;
            reordered_data(find(trim_idx>elementNum-1),:) = 0;
        end
        
        function RxMux = calculate_rx_mux(h,N_receive_channels,channel_data,N_sc)
            rx_HalfCh = N_receive_channels*0.5;
            rx_ch_mtx = [-rx_HalfCh:rx_HalfCh-1];
            
            RxMux = zeros(N_sc, N_receive_channels);
            scan_view_size = channel_data.probe.pitch*channel_data.probe.N_elements; % Lateral View Size
            
            sc_d = scan_view_size/(N_sc-1); % Muligen N_sc - 1Scanline distance
            one_angle = scan_view_size/(channel_data.probe.N_elements-1);
            SCvsEle = sc_d/one_angle;
            
            for sc = 1:N_sc
                idx = floor((sc-1)*SCvsEle) + 1;
                
                rx_idx_tmp = idx + rx_ch_mtx;
                rx_idx = rx_idx_tmp((rx_idx_tmp > 0) & (rx_idx_tmp <= channel_data.probe.N_elements));
                RxMux(sc,:) = rx_idx_tmp;
            end
        end
        
        function filt_data = bandpass_filter_data(~,data,channel_data,do_plot)
            
            % power spectrum
            [fx, pw] = tools.power_spectrum(data,channel_data.sampling_frequency);
            assert(sum(pw)>0,'Dataset is zero, error in bandpass_filter');
            
            % computing central frequency and bandwidth
            fpw=filter(ones(1,26)./26,1,pw);fpw=[fpw(13:end); zeros(12,1)];
            [dc, ic]=max(fpw.*(fx>0).'); fc=fx(ic);
            bw_up=min(fx((fx>fc)&(fpw<dc/2).')); % -6dB upper limit
            bw_do=max(fx((fx<fc)&(fpw<dc/2).')); % -6dB down limit
            fc=(bw_up+bw_do)/2;                  % center frequency
            bw=2*(bw_up-fc);
            
            % band pass filtering
%             transition=bw/10;
            bandpass_frequency_vector = [0.25, 0.5, 1.5, 1.75];
%             low_freq=max([0, fc-2*bw]);
%             high_freq=min([channel_data.sampling_frequency/2*0.99, fc+2*bw]);
%             bandpass_frequency_vector=[low_freq, low_freq+transition high_freq-transition high_freq];
            
            filt_data = zeros([size(tools.band_pass(data(:,:,:,1),channel_data.sampling_frequency,fc*bandpass_frequency_vector)), size(data, 4)], ...
                'like', data);
            
            w = waitbar(0, 'Bandpass filter...');
            for frame = 1:size(data,4)
                waitbar((frame-1)/size(data,4), w)
                
               
                filt_data(:,:,:,frame)= tools.band_pass(data(:,:,:,frame),channel_data.sampling_frequency,fc*bandpass_frequency_vector);
            end
            close(w)
            
            if do_plot
                figure();
                subplot(1,2,1);
                plot(fx*1e-6,db(pw),'k'); hold on; axis manual; grid on;
                xlabel('f [MHz]');
                ylabel('Relative amplitude');
                title('Before bandpass filter');
                subplot(1,2,2)
                % power spectrum
                [fx, pw_after] = tools.power_spectrum(data,channel_data.sampling_frequency);
                plot(fx*1e-6,db(pw_after),'k'); hold on; axis manual; grid on;
                xlabel('f [MHz]');
                ylabel('Relative amplitude');
                title('After bandpass filter');
            end  
        end
    end
end

