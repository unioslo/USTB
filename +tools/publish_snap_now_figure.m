function publish_snap_now_figure(fig_h)
%PUBLISH_SNAP_NOW_FIGURE  drawnow + strip uicontrol + snapnow for publish HTML embed.
if nargin < 1 || isempty(fig_h) || ~isgraphics(fig_h)
    fig_h = gcf;
end
drawnow;
if isgraphics(fig_h)
    delete(findall(fig_h, 'Type', 'uicontrol'));
end
snapnow;
end
