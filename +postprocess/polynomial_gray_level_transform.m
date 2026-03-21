classdef polynomial_gray_level_transform < postprocess
    %POLYNOMIAL_GRAY_LEVEL_TRANSFORM   Polynomial gray-level mapping for dynamic range stretching.
    %
    %   Applies a cubic polynomial (p(b) = a*b^3 + b*b^2 + c*b + d) in log space,
    %   mapped to linear space via cubic spline interpolation. Used for dynamic
    %   range stretching of beamformed ultrasound images prior to display.
    %
    %   Input:  uff.beamformed_data -> Output: uff.beamformed_data
    %
    %   Properties:
    %       a               cubic coefficient
    %       b               quadratic coefficient
    %       c               linear coefficient
    %       d               constant offset
    %       plot_functions  enable debug plotting of transfer functions
    %       scan            uff.scan object (optional)
    %       is_exp          experimental flag
    %
    %   Example:
    %       obj = postprocess.polynomial_gray_level_transform();
    %
    %   See also POSTPROCESS, GRAY_LEVEL_TRANSFORM, SCURVE_GRAY_LEVEL_TRANSFORM
    %
    %   References:
    %       Rindal, O. M. H., Austeng, A., Fatemi, A., Rodriguez-Molares, A.,
    %       "The effect of dynamic range alterations in the estimation of
    %       contrast," IEEE TUFFC, vol. 66, no. 7, pp. 1198-1208, 2019.
    %       https://ieeexplore.ieee.org/document/8691813
    %
    %   implementers: Ole Marius Hoel Rindal <olemarius@olemarius.net>
    %                 Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>
    %
    %   $Last updated: 2017/09/12$
    
    %% constructor
    methods (Access = public)
        function h=polynomial_gray_level_transform()
            h.name='Gray Level Transform';
            h.reference= 'Rindal, Austeng, Fatemi Rodriguez-Molares, "Dynamic Range Strecthing in Ultrasound Imaging"';
            h.implemented_by={'Ole Marius Hoel Rindal <olemarius@olemarius.net>','Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>'};
            h.version='v1.0.0';
        end
    end
    
    %% Additional properties
    properties
        a = 0;
        b = 0.01;
        c = 0.8;
        d = 0;
        plot_functions = 0;
        scan;
        is_exp = 0;
    end
    
    methods
        function output = go(h)
            % check if we can skip calculation
            if h.check_hash()
                output= h.output;
                return;
            end
            
            %%
            % declare output structure
            output=uff.beamformed_data(h.input); % ToDo: instead we should copy everything but the data
            
            % linear space
            x=logspace(-200/20,0,400);
            
            % dB space
            x_dB=20*log10(x);
            %x_dB_compressed=-a*x_dB.^2+b*x_dB;
            x_dB_compressed=h.a*x_dB.^3+h.b*x_dB.^2+h.c*x_dB + h.d;
            % find the cublic spline that approximate the compressed values
            x_compressed=10.^(x_dB_compressed/20);
            gamma = fit(x.',x_compressed.','cubicspline');

            
            % Prøv : GLT( signal./ sqrt( |mean signal power at the top of the gradient| ) ) 
            %%
%             if h.is_exp
%                 mask = h.scan.z > 40.5/1000 & h.scan.z < 48/1000 & h.scan.x > -12.5/1000 & h.scan.x < -12/1000;
%             else % Is simulation
%                 mask = h.scan.z > 47.5/1000 & h.scan.z < 52.5/1000 & h.scan.x > -10.5/1000 & h.scan.x < -9.5/1000;
%             end
            
            %%
            signal = abs(h.input.data);
            max_value = max(signal(:));
            %max_value = (mean(abs(h.input.data(mask))))
            for ch = 1:h.input.N_channels
                for wa = 1:h.input.N_waves
                    for fr = 1:h.input.N_frames
                        output.data(:,ch,wa,fr)  = gamma(signal(:,ch,wa,fr)./max_value);
                    end
                end
            end
           
            %% Get rid of "true zeros" that will cause -inf
            
            output.data(output.data==0) = eps;
            
            
%             %%
%             h.input.data = h.input.data;
%             img = h.input.get_image('none');
%             img_db = db(abs(img./max_value));
%             figure;
%             imagesc(img_db);colormap gray;
%             colorbar;caxis([-60 max(img_db(:))]);
%             
%             img = h.input.get_image();
%             img_vect = img(:);
%             value_at = mean(img_vect(mask))
%             
%             figure;
%             subplot(211)
%             imagesc(reshape(img(:).*mask,2048,1024));;caxis([-60 0]);colorbar
%             subplot(212)
%             imagesc(reshape(img(:),2048,1024));caxis([-60 0]);colorbar
            %%
   
            if h.plot_functions
                %%
                f8888 = figure(8888);clf;
                %subplot(1,2,2);
                plot(x,x,'k','LineWidth',2); hold on; grid on; axis equal tight;
                plot(x,x_compressed,'b','LineWidth',2); hold on;
                plot(x,gamma(x),'r:','LineWidth',2);
                title('Linear space');
                xlabel('Input signal');
                ylabel('Output signal');
                legend('location','nw','Uniform','p(b) mapped to linear','v(b)');
                
                %%
                f8889 = figure(8889);clf;
                %subplot(1,2,1);hold all;
                plot(x_dB,x_dB,'k','LineWidth',2); hold on; grid on; axis equal tight;
                plot(x_dB,x_dB_compressed,'b','LineWidth',2); hold on;
                plot(x_dB,20*log10(gamma(x)),'r:','LineWidth',2); hold on;
                %title('Log space');
                xlabel('Input signal [dB]');
                ylabel('Output signal [dB]');
                legend('location','nw','Uniform','p(b)','20log_{10}(v(b))');
                
                f8899 = figure(8899);clf;
                %subplot(1,2,1);
                hold all;
                plot(x_dB,x_dB,'k','LineWidth',2); hold on; grid on; axis equal tight;
                plot(x_dB,x_dB_compressed,'b','LineWidth',2); hold on;
                %title('Log space');
                xlabel('Input signal [dB]');
                ylabel('Output signal [dB]');
                legend('location','nw','Uniform','p(B)');
                xlim([-80 0]);
                %saveas(f8888,[ustb_path,filesep,'publications/DynamicRage/figures/GLT_theory_lin'],'eps2c')
                %saveas(f8889,[ustb_path,filesep,'publications/DynamicRage/figures/GLT_theory_log'],'eps2c')
                %saveas(f8899,[ustb_path,filesep,'publications/DynamicRage/figures/GLT_theory_log_stripped'],'eps2c')
            end
            
            % update hash
            h.save_hash();
        end
    end
    
end



