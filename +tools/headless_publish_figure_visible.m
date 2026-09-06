function vis = headless_publish_figure_visible()
%HEADLESS_PUBLISH_FIGURE_VISIBLE  Figure Visible char for MATLAB publish() in -batch / -nodisplay.
%   With Visible 'off', many figures (colorbar, triptychs) are skipped in published HTML snapshots.
%
% See also SNAPNOW, PUBLISH, publish_beamformed_snap, publish_snap_now_figure.

tf = ~usejava('desktop');
if exist('batchStartupOptionUsed', 'file') == 2 %#ok<EXIST>
    try %#ok<*TRYNC>
        tf = tf | batchStartupOptionUsed;
    catch
    end
end
if tf
    vis = 'on';
else
    vis = 'off';
end

end
