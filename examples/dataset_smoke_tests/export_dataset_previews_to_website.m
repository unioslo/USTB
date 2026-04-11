function results = export_dataset_previews_to_website(varargin)
%EXPORT_DATASET_PREVIEWS_TO_WEBSITE  Beamform each registry dataset and save PNG previews for the website.
%
%   Run from MATLAB with USTB on the path (repository root):
%     addpath('examples/dataset_smoke_tests');
%     addpath('examples/dataset_catalog_previews');
%     export_dataset_previews_to_website();
%
%   Beamforming matches examples/dataset_catalog_previews/dataset_preview_beamform.m
%   (one case per dataset, copied from the canonical example script).
%
%   Writes PNGs to website/assets/images/datasets/<slug>.png using the same
%   naming as website/scripts/build_datasets_page.py (see website_slug_for_dataset).
%
%   Name-value:
%     'url'              — primary dataset base (default 'https://www.ustb.no/datasets',
%                          no trailing slash)
%     'stop_on_error'    — default false
%     'website_root'     — override path to repo root (default: ustb_path())
%     'indices'          — optional row vector of 1-based indices into the registry
%                          (default: all). Use to split export across runs and limit memory.
%     'local_only'       — if true, do not download: only process files already in
%                          data_path(); missing files get a gray stub (default false).
%
%   Tries several public URL bases if the first returns 404. Missing files get a
%   gray stub PNG so the website still has one image per row.
%
%   After exporting, regenerate the HTML:
%     python3 website/scripts/build_datasets_page.py

p = inputParser;
addParameter(p, 'url', 'https://www.ustb.no/datasets', @(s) ischar(s) || isstring(s));
addParameter(p, 'stop_on_error', false, @islogical);
addParameter(p, 'website_root', '', @(s) ischar(s) || isstring(s));
addParameter(p, 'indices', [], @(x) isempty(x) || (isnumeric(x) && isvector(x) && all(x > 0)));
addParameter(p, 'local_only', false, @islogical);
parse(p, varargin{:});

repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repo_root, 'examples', 'dataset_catalog_previews'));

primary_url = normalize_dataset_base(char(p.Results.url));
stop_on_error = p.Results.stop_on_error;
local_only = p.Results.local_only;
if isempty(p.Results.website_root)
    root = ustb_path();
else
    root = char(p.Results.website_root);
end

out_dir = fullfile(root, 'website', 'assets', 'images', 'datasets');
if ~isfolder(out_dir)
    mkdir(out_dir);
end

local_path = data_path();
if local_path(end) ~= filesep
    local_path = [local_path filesep];
end

T = uff_dataset_registry();
idx = p.Results.indices;
if ~isempty(idx)
    idx = unique(round(idx(:)'));
    idx = idx(idx <= numel(T));
    T = T(idx);
end
n = numel(T);
results = repmat(struct('filename', '', 'ok', false, 'message', '', 'png', ''), n, 1);

fprintf('Exporting %d dataset preview(s) -> %s\n', n, out_dir);

for i = 1:n
    fn = T(i).filename;
    results(i).filename = fn;

    uff_file = fullfile(local_path, fn);
    dl_ok = false;
    last_err = '';
    if local_only
        if isfile(uff_file)
            dl_ok = true;
        else
            last_err = 'local_only: file not in data_path()';
        end
    else
        for ub = dataset_url_bases(primary_url)
            try
                tools.download(fn, ub{1}, local_path);
                dl_ok = true;
                break
            catch ME
                last_err = ME.message;
            end
        end
    end
    if ~dl_ok
        results(i).message = ['Download failed: ' last_err];
        fprintf('[FAIL] %s — %s\n', fn, results(i).message);
        slug = website_slug_for_dataset(fn);
        write_gray_stub_preview(fullfile(out_dir, [slug '.png']), fn);
        fprintf('       (wrote gray stub preview %s.png)\n', slug);
        if stop_on_error
            return
        else
            continue
        end
    end
    try
        b_data = dataset_preview_beamform(uff_file);
    catch ME
        results(i).message = ME.message;
        fprintf('[FAIL] %s — %s\n', fn, ME.message);
        slug = website_slug_for_dataset(fn);
        write_gray_stub_preview(fullfile(out_dir, [slug '.png']), fn);
        if stop_on_error
            return
        else
            continue
        end
    end

    if isempty(b_data)
        results(i).message = 'empty b_data';
        fprintf('[FAIL] %s — empty b_data\n', fn);
        slug = website_slug_for_dataset(fn);
        write_gray_stub_preview(fullfile(out_dir, [slug '.png']), fn);
        if stop_on_error
            return
        else
            continue
        end
    end

    slug = website_slug_for_dataset(fn);
    png_path = fullfile(out_dir, [slug '.png']);
    try
        export_png_like_b_data_plot(b_data, png_path);
    catch ME
        results(i).message = ME.message;
        fprintf('[FAIL] %s — PNG: %s\n', fn, ME.message);
        write_gray_stub_preview(png_path, fn);
        if stop_on_error
            return
        else
            continue
        end
    end

    results(i).ok = true;
    results(i).png = png_path;
    results(i).message = 'ok';
    fprintf('[ OK ] %s -> %s\n', fn, png_path);
    clear b_data
end

n_ok = sum([results.ok]);
fprintf('Finished: %d / %d beamformed preview(s); stubs used for the rest.\n', n_ok, n);
end

function s = normalize_dataset_base(u)
s = strtrim(u);
while endsWith(s, '/')
    s = s(1:end-1);
end
end

function C = dataset_url_bases(primary)
bases = {
    primary
    'https://www.ustb.no/datasets'
    'http://www.ustb.no/datasets'
    'https://ustb.no/datasets'
    'http://ustb.no/datasets'
    'https://www.ultrasoundtoolbox.com/datasets'
    };
C = {};
for k = 1:numel(bases)
    b = normalize_dataset_base(char(bases{k}));
    if isempty(b)
        continue
    end
    if ~any(strcmp(C, b))
        C{end+1} = b; %#ok<AGROW>
    end
end
end

function write_gray_stub_preview(path, label)
% Minimal 400x260 RGB PNG without Image Processing Toolbox.
% Neutral gray (R=G=B) — a green-only channel was used previously and looked
% like a bad beamformed image on the public datasets page.
w = 400; h = 260;
gray = uint8(218 * ones(h, w));
rgb = cat(3, gray, gray, gray);
if exist('imwrite', 'file') == 2 %#ok<EXIST>
    imwrite(rgb, path);
else
    error('imwrite not available; install Image Processing Toolbox or use Octave with imwrite.');
end
% Optional: could overlay text with getframe+text — keep file dependency-free
if nargin >= 2 && ~isempty(label)
    % label unused in minimal stub (filename is in page already)
end
end
