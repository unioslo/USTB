classdef wiener < postprocess
    properties 
        m = 20;
        n = 20;
        sigma = 60;
        run_on_logcompressed = true;
    end
    
    methods        
        function output=go(h)
            % check that the input is combined image
            assert(prod(size(h.input.data, [2,3]))==1,'lee filter only works on combined images');
            
            % declare output structure
            h.output=uff.beamformed_data(h.input);

            if isa(h.input.scan,'uff.linear_scan')
                tmp=reshape(h.input.data,[h.input.scan.N_z_axis, h.input.scan.N_x_axis, size(h.input.data,4)]);
            elseif isa(h.input.scan,'uff.sector_scan')
                tmp=reshape(h.input.data,[h.input.scan.N_depth_axis, h.input.scan.N_azimuth_axis, size(h.input.data,4)]);
            else
                error('Lee filter supports linear and sector scans for now')
            end

            out = zeros(size(tmp));

            if h.run_on_logcompressed
                tmp = 20*log10(abs(tmp));
            else
                tmp = abs(tmp);
            end

            for n = 1:size(tmp, 3) %#ok<*PROP> 
                out(:,:,n) = wiener2(tmp(:,:,n), [h.m, h.n], h.sigma);
            end
            
            if h.run_on_logcompressed
                out = 10.^(out/20);
            end

            h.output.data=reshape(out,size(h.input.data));
            
            % pass reference
            output = h.output;
        end
    end

    methods (Access=private)


    end
end
