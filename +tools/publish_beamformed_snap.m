function publish_beamformed_snap(b_obj, varargin)
%PUBLISH_BEAMFORMED_SNAP  beamformed_data.plot + snapnow for MATLAB publish (-batch/-nodisplay).
%   Mirrors publication scripts that passed an explicit Figure handle rather than disposable axes.
%
% varargin is forwarded to beamformed_data.plot after the figure parent.

hv = strcmp(tools.headless_publish_figure_visible(), 'on');
if hv
    fh = figure('Visible', 'on');
    if isempty(varargin)
        b_obj.plot(fh);
    else
        b_obj.plot(fh, varargin{:});
    end
else
    if isempty(varargin)
        b_obj.plot([]);
    else
        b_obj.plot([], varargin{:});
    end
    fh = gcf;
end

drawnow;
if hv && isgraphics(fh)
    delete(findall(fh, 'Type', 'uicontrol'));
end
snapnow;
if hv && isgraphics(fh)
    close(fh);
end

end
