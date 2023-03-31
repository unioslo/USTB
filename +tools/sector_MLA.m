% Sector MLA changes the number of sector scanlines in azimuth by scaling the
% original number by a factor
%
% sector_scan = sector_MLA(sector_scan_input, MLA)
%
% sector_scan_input : An uff sector scan object
% MLA               : An integer
%
% Last modified:
% 01.02.2023 - Anders Vrålstad
function sector_scan = sector_MLA(sector_scan_input,MLA)

assert(isa(sector_scan_input,'uff.sector_scan'));


azimuth_axis =  linspace(   sector_scan_input.azimuth_axis(1),...
                            sector_scan_input.azimuth_axis(end),...
                            sector_scan_input.N_azimuth_axis*MLA)';

if length(sector_scan_input.origin) == 1
    sector_scan = uff.sector_scan('depth_axis', sector_scan_input.depth_axis,...
                                    'azimuth_axis', azimuth_axis,...
                                    'origin', sector_scan_input.origin);
else
    for origin_index = 1:sector_scan_input.N_origins; origins_matrix(origin_index,:) = sector_scan_input.origin(origin_index).xyz; end     
    interp_origins_matrix = interp1(1:1:size(origins_matrix,1),origins_matrix,linspace(1,size(origins_matrix,1),sector_scan_input.N_azimuth_axis*MLA));
    for scanline_index = 1:sector_scan_input.N_azimuth_axis*MLA; uff_points(scanline_index) = uff.point('xyz',interp_origins_matrix(scanline_index,:)); end
    
    sector_scan = uff.sector_scan(  'depth_axis', sector_scan_input.depth_axis,...
                                    'azimuth_axis', azimuth_axis,...
                                    'origin', uff_points);
end

