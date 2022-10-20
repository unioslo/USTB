classdef median < postprocess
    properties 
        m = 20;
        n = 20;
    end
    
    methods
        
        
        function output=go(h)
            % check that the input is combined image
            assert(size(h.input.data,2)==1,'median only works on combined images');
            assert(size(h.input.data,3)==1,'median only works on combined images');
            %assert(isa(h.input.scan,'uff.linear_scan'),'median only works for linear scans');
            
            
            % declare output structure
            h.output=uff.beamformed_data(h.input);

            if isa(h.input.scan,'uff.linear_scan')
                % the actual thing
                temp=reshape(h.input.data,[h.input.scan.N_z_axis, h.input.scan.N_x_axis, 1, size(h.input.data,4)]);
            elseif isa(h.input.scan,'uff.sector_scan')
                temp=reshape(h.input.data,[h.input.scan.N_depth_axis, h.input.scan.N_azimuth_axis, 1, size(h.input.data,4)]);
            else
                error('Median only support lienar and sector scans for now')
            end
            for n=1:size(temp,4)
                img(:, :, 1, n)=medfilt2(abs(temp(:,:,n)),[h.m h.n]);
            end
            
            
            h.output.data=reshape(img,size(h.input.data));
            
            % pass reference
            output = h.output;
        end
    end
end
