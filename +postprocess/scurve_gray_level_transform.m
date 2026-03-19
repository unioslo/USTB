classdef scurve_gray_level_transform < postprocess
    %SCURVE_GRAY_LEVEL_TRANSFORM   S-curve (sigmoid) gray-level mapping for dynamic range stretching.
    %
    %   Applies an S-curve transfer function (1/(1+exp(-a*(x_dB-b)))) in log space,
    %   mapped to linear space via cubic spline. Provides a sigmoidal compression
    %   for dynamic range stretching of beamformed ultrasound images.
    %
    %   Input:  uff.beamformed_data -> Output: uff.beamformed_data
    %
    %   Properties:
    %       a               sigmoid steepness parameter
    %       b               sigmoid center point [dB]
    %       c               scaling factor
    %       plot_functions  enable debug plotting of transfer functions
    %       scan            uff.scan object (optional)
    %
    %   Example:
    %       obj = postprocess.scurve_gray_level_transform();
    %
    %   See also POSTPROCESS, GRAY_LEVEL_TRANSFORM, POLYNOMIAL_GRAY_LEVEL_TRANSFORM
    %
    %   References:
    %       Rindal et al., "Dynamic Range Stretching in Ultrasound Imaging"
    %
    %   implementers: Ole Marius Hoel Rindal <olemarius@olemarius.net>
    %                 Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>
    %
    %   $Last updated: 2017/09/12$
    
    %% constructor
    methods (Access = public)
        function h=gray_level_transform()
            h.name='Gray Level Transform';
            h.reference= 'Rindal, Austeng, Fatemi Rodriguez-Molares, "Dynamic Range Strecthing in Ultrasound Imaging"';
            h.implemented_by={'Ole Marius Hoel Rindal <olemarius@olemarius.net>','Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>'};
            h.version='v1.0.0';
        end
    end
    
    %% Additional properties
    properties
        a = 0.1;
        b = -40;
        c = 0.01;
        plot_functions = 0;
        scan;
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

            x_dB_compressed = 1./(1+exp(-h.a.*(x_dB-h.b)));
            x_dB_compressed = (x_dB_compressed-max(x_dB_compressed))./h.c;
            
            %%
            
            % find the cublic spline that approximate the compressed values
            x_compressed=10.^(x_dB_compressed/20);
            gamma = fit(x.',x_compressed.','cubicspline');

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
            
            %%
   
            if h.plot_functions
                %%
                f8888 = figure(8888);clf;
                subplot(1,2,2);
                plot(x,x,'k','LineWidth',2); hold on; grid on; axis equal tight;
                plot(x,x_compressed,'b','LineWidth',2); hold on;
                plot(x,gamma(x),'r:','LineWidth',2);
                title('Linear space');
                xlabel('Input signal');
                ylabel('Output signal');
                legend('location','nw','Uniform','p(b) mapped to linear','v(b)');
                
                %%
                f8889 = figure(8889);clf;
                subplot(1,2,1);hold all;
                plot(x_dB,x_dB,'k','LineWidth',2); hold on; grid on; axis equal tight;
                plot(x_dB,x_dB_compressed,'b','LineWidth',2); hold on;
                plot(x_dB,20*log10(gamma(x)),'r:','LineWidth',2); hold on;
                %title('Log space');
                xlabel('Input signal [dB]');
                ylabel('Output signal [dB]');
                legend('location','nw','Uniform','p(b)','20log_{10}(v(b))');
                
                f8899 = figure(8899);clf;
                subplot(1,2,1);hold all;
                plot(x_dB,x_dB,'k','LineWidth',2); hold on; grid on; axis equal tight;
                plot(x_dB,x_dB_compressed,'b','LineWidth',2); hold on;
                %title('Log space');
                xlabel('Input signal [dB]');
                ylabel('Output signal [dB]');
                legend('location','nw','Uniform','p(B)');
                xlim([-80 0]);
                saveas(f8888,[ustb_path,filesep,'publications/DynamicRange/figures/GLT_theory_lin'],'eps2c')
                saveas(f8889,[ustb_path,filesep,'publications/DynamicRange/figures/GLT_theory_log'],'eps2c')
                saveas(f8899,[ustb_path,filesep,'publications/DynamicRange/figures/GLT_theory_log_stripped'],'eps2c')
            end
            
            % update hash
            h.save_hash();
        end
    end
    
end



