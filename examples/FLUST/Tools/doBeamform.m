function [realTab, BFstruct] = doBeamform( realTabCh, pipe, chunkSize)
if nargin < 3
    chunkSize = 1;
end
for aa = 1:length( pipe )
    bmf = midprocess.das();
    bmf.code = code.mexFast;
    currData_rsh = reshape( realTabCh(:,:,:,aa,:), size( realTabCh,1), size( realTabCh,2), 1, size( realTabCh,3), size( realTabCh,5) );
    for realInd = 1:chunkSize:size( realTabCh, 5)
        currinds = realInd:min( realInd+chunkSize-1, size( realTabCh,5 ) );
        pipe(aa).channel_data.data = currData_rsh(:,:,1,:,currinds);
        pipe(aa).channel_data.data = pipe(aa).channel_data.data(:,:,1,:);
        BFstruct=pipe(aa).go({bmf});
        if aa == 1 && realInd == 1
            dsize = size( BFstruct.data);
            realTab = zeros( [dsize([1 2]) size( realTabCh, [3 4 5] )], 'like', single(1i));
        end
        realTab(:,:,:,aa, currinds) = reshape( BFstruct.data, size( realTab,1), size( realTab, 2), size( realTab, 3), []);
        clc
        disp( [num2str( aa) '/' num2str( length( pipe) ) ] );
        disp( [num2str( realInd) '/' num2str( size( realTabCh, 5) ) ] );
    end
end
% realTab = permute( realTab, [1 2 3 5 4] );

if isa( BFstruct.scan, 'uff.sector_scan')
    szZ = length(BFstruct.scan.depth_axis); % size( PSFs, 1);
    szX = length(BFstruct.scan.azimuth_axis); % size( PSFs, 2);
elseif isa( BFstruct.scan, 'uff.linear_scan') || isa( BFstruct.scan, 'uff.linear_scan_rotated')
    szZ = length(BFstruct.scan.z_axis); % size( PSFs, 1);
    szX = length(BFstruct.scan.x_axis); % size( PSFs, 2);
end
realTab = reshape( realTab, [szZ szX size( realTab, [3 4 5])] );

end