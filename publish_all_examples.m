function publish_all_examples(output_root)
%PUBLISH_ALL_EXAMPLES Publish all USTB example scripts to HTML
%
%   publish_all_examples() publishes all .m files under examples/ to HTML,
%   preserving the folder structure. Output goes to examples_html/ by default.
%
%   publish_all_examples(output_root) writes HTML to the specified folder.
%
%   After publishing, run generate_examples_index.py to create the index page.
%
%   See also PUBLISH

if nargin < 1
    output_root = fullfile(fileparts(mfilename('fullpath')), 'examples_html');
end

ustb_root = fileparts(mfilename('fullpath'));
examples_dir = fullfile(ustb_root, 'examples');

skip_dirs = {fullfile('FLUST','Core'), fullfile('FLUST','Estimators'), ...
             fullfile('FLUST','Phantoms'), fullfile('FLUST','PSF_acquisition'), ...
             fullfile('FLUST','Support'), fullfile('FLUST','Tools'), ...
             fullfile('FLUST','Validation'), ...
             fullfile('field_II','functions'), ...
             fullfile('UiO_course_IN4015_Ultrasound_Imaging','module_6_sonar','utils'), ...
             fullfile('UiO_course_IN4015_Ultrasound_Imaging','module_2_wave_physics')};

all_m = dir(fullfile(examples_dir, '**', '*.m'));

addpath(genpath(ustb_root));

succeeded = {};
failed = {};
skipped = {};

for k = 1:numel(all_m)
    src = fullfile(all_m(k).folder, all_m(k).name);
    rel = strrep(all_m(k).folder, [examples_dir filesep], '');
    if strcmp(rel, examples_dir)
        rel = '';
    end

    should_skip = false;
    for s = 1:numel(skip_dirs)
        if contains(rel, skip_dirs{s})
            should_skip = true;
            break;
        end
    end
    if should_skip
        skipped{end+1} = src; %#ok<AGROW>
        fprintf('[SKIP]  %s\n', strrep(src, [ustb_root filesep], ''));
        continue;
    end

    out_dir = fullfile(output_root, rel);
    if ~exist(out_dir, 'dir')
        mkdir(out_dir);
    end

    opts.outputDir = out_dir;
    opts.format = 'html';
    opts.showCode = true;
    opts.evalCode = false;
    opts.catchError = true;
    opts.createThumbnail = false;

    fprintf('[PUB]   %s ... ', strrep(src, [ustb_root filesep], ''));
    try
        publish(src, opts);
        fprintf('OK\n');
        succeeded{end+1} = src; %#ok<AGROW>
    catch me
        fprintf('FAILED: %s\n', me.message);
        failed{end+1} = src; %#ok<AGROW>
    end
end

fprintf('\n=== Summary ===\n');
fprintf('Published: %d\n', numel(succeeded));
fprintf('Failed:    %d\n', numel(failed));
fprintf('Skipped:   %d\n', numel(skipped));
fprintf('Output:    %s\n', output_root);

if ~isempty(failed)
    fprintf('\nFailed files:\n');
    for k = 1:numel(failed)
        fprintf('  %s\n', failed{k});
    end
end

end
