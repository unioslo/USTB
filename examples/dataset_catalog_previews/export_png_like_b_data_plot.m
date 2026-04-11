function export_png_like_b_data_plot(b_data, filepath, dynamic_range_db)
%EXPORT_PNG_LIKE_B_DATA_PLOT  PNG thumbnail using uff.beamformed_data.plot (correct sector geometry).
%
%   Uses the built-in plot (pcolor + axis equal for sector_scan), then
%   exportgraphics/print — not a flat matrix imwrite, which stretches sector data.

if nargin < 3 || isempty(dynamic_range_db)
    dynamic_range_db = 60;
end

[p, ~] = fileparts(filepath);
if ~isfolder(p)
    mkdir(p);
end

fig = figure('Visible', 'off', 'Color', 'w', 'MenuBar', 'none', 'ToolBar', 'none');
try
    % First frame if multi-frame; same display as plot(..., dr, 'log').
    % Pass at most 8 args so plot() applies default mode and sets font_color (nargin<9 branch).
    b_data.plot(fig, '', dynamic_range_db, 'log', [], 1);

    cb = findobj(fig, 'Type', 'colorbar');
    if ~isempty(cb)
        delete(cb);
    end

    ax = gca(fig);
    axis(ax, 'tight');
    drawnow;

    % Capture axes only (sector pcolor + equal aspect); avoids flat-matrix stretch.
    if exist('exportgraphics', 'file') == 2 %#ok<EXIST>
        try
            exportgraphics(ax, filepath, 'Resolution', 120, 'BackgroundColor', 'white');
        catch
            F = getframe(ax);
            imwrite(F.cdata, filepath);
        end
    else
        F = getframe(ax);
        imwrite(F.cdata, filepath);
    end

    % Cap longest edge for the catalog (keep aspect from plot).
    try
        A = imread(filepath);
        mx = max(size(A, 1), size(A, 2));
        if mx > 900
            if exist('imresize', 'file') == 2 %#ok<EXIST>
                A = imresize(A, 900 / mx);
            else
                step = ceil(mx / 900);
                A = A(1:step:end, 1:step:end, :);
            end
            imwrite(A, filepath);
        end
    catch
    end
catch ME
    close(fig);
    rethrow(ME);
end
close(fig);
end
