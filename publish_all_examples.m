function publish_all_examples(output_root, eval_code)
%PUBLISH_ALL_EXAMPLES Publish all USTB example scripts to HTML
%
%   publish_all_examples() publishes all .m files under examples/ to HTML
%   with code execution enabled, preserving the folder structure. Output
%   goes to examples_html/ by default.
%
%   publish_all_examples(output_root) writes HTML to the specified folder.
%
%   publish_all_examples(output_root, eval_code) controls whether code is
%   executed (default: true). Set to false for a fast code-only pass.
%
%   After publishing, run generate_examples_index.py to create the index page.
%
%   See also PUBLISH

if nargin < 1
    output_root = fullfile(fileparts(mfilename('fullpath')), 'examples_html');
end
if nargin < 2
    eval_code = true;
end

ustb_root = fileparts(mfilename('fullpath'));
examples_dir = fullfile(ustb_root, 'examples');

skip_dirs = {'FLUST', ...             % needs MUST toolbox + edit() calls
             'field_II', ...          % needs Field II toolbox
             'kWave', ...             % needs k-Wave toolbox + can segfault
             'REFoCUS', ...           % causes segfault in headless CI
             'verasonics', ...        % needs Verasonics hardware/data
             'alpinion', ...          % needs Alpinion hardware/data
             'acoustical_radiation_force_imaging', ... % needs hardware data
             fullfile('UiO_course_IN4015_Ultrasound_Imaging','module_6_sonar','utils'), ...
             fullfile('UiO_course_IN4015_Ultrasound_Imaging','module_2_wave_physics')};

skip_files = {'kWave_USTB_REFoCUS.m', ...  % needs k-Wave, causes segfault
              'calculate_VZC_curves.m'};    % needs precomputed data from other scripts

all_m = dir(fullfile(examples_dir, '**', '*.m'));

addpath(genpath(ustb_root));

set(0, 'DefaultFigureVisible', 'off');

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
    if ~should_skip
        for s = 1:numel(skip_files)
            if strcmp(all_m(k).name, skip_files{s})
                should_skip = true;
                break;
            end
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
    opts.evalCode = eval_code;
    opts.catchError = true;
    opts.createThumbnail = false;
    opts.maxOutputLines = Inf;

    fprintf('[PUB]   %s ... ', strrep(src, [ustb_root filesep], ''));
    original_dir = pwd;
    try
        cd(all_m(k).folder);
        publish(src, opts);
        fprintf('OK\n');
        succeeded{end+1} = src; %#ok<AGROW>
    catch me
        fprintf('FAILED: %s\n', me.message);
        failed{end+1} = src; %#ok<AGROW>
    end
    cd(original_dir);
    close all;
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

set(0, 'DefaultFigureVisible', 'on');

end
