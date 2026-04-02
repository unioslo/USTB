function publish_all_examples(output_root, eval_code, isolate)
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
%   publish_all_examples(output_root, eval_code, isolate) when isolate is
%   true, runs each example in a separate MATLAB process to prevent
%   segfaults from killing the entire batch (default: false).
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
if nargin < 3
    isolate = false;
end

ustb_root = fileparts(mfilename('fullpath'));
examples_dir = fullfile(ustb_root, 'examples');

skip_dirs = {'FLUST', ...             % needs MUST toolbox + edit() calls
             'kWave', ...             % needs k-Wave toolbox + can segfault
             'REFoCUS', ...           % causes segfault in headless CI
             'verasonics', ...        % needs Verasonics hardware/data
             'alpinion', ...          % needs Alpinion hardware/data
             'acoustical_radiation_force_imaging', ... % needs hardware data
             'UiO_course_IN4015_Ultrasound_Imaging', ... % course exercises, some hang in CI
             fullfile('field_II','3D_simulation'), ... % 3D Field II, very long runtime
             fullfile('field_II','functions')};         % helper functions, not examples

skip_files = {'kWave_USTB_REFoCUS.m', ...            % needs k-Wave, causes segfault
              'calculate_VZC_curves.m', ...          % needs precomputed data from other scripts
              'FI_L11_parfor_compared_to_fresnel.m', ... % needs Parallel Computing Toolbox
              'STAI_L11_speckle_parfor.m', ...       % needs Parallel Computing Toolbox
              'FI_P4_cardiac_coherence.m', ...        % needs Parallel Computing Toolbox + long runtime
              'STAI_2D_array_cardiac.m', ...          % 3D simulation, very long runtime
              'STAI_2D_array_image_from_channeldata.m', ... % needs data from STAI_2D_array_cardiac
              'CPWC_2D_array_cardiac.m', ...          % 3D simulation, very long runtime
              'setUpParpool.m', ...                   % parpool helper, not an example
              'STAI_L11_speckle.m', ...               % Field II simulation, very slow
              'STAI_L11_resolution_phantom.m', ...    % Field II simulation, very slow
              'CPWC_L11_probe_sim.m', ...             % Field II simulation, very slow
              'FI_elevation_profile.m', ...              % Field II simulation, very slow
              'MATLAB_intro.m'};                      % uses ginput(), hangs in headless CI

all_m = dir(fullfile(examples_dir, '**', '*.m'));

addpath(genpath(ustb_root));

total_files = numel(all_m);
fprintf('Found %d .m files in examples/\n', total_files);

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
        fprintf('[SKIP]  (%d/%d) %s\n', k, total_files, strrep(src, [ustb_root filesep], ''));
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

    fprintf('[PUB]   (%d/%d) %s ... ', k, total_files, strrep(src, [ustb_root filesep], ''));

    if isolate
        % Run in a separate MATLAB process to isolate segfaults
        matlab_bin = fullfile(matlabroot, 'bin', 'matlab');
        cmd = sprintf('%s -batch "addpath(genpath(''%s'')); addpath(''/opt/field_ii''); cd(''%s''); opts.outputDir=''%s''; opts.format=''html''; opts.showCode=true; opts.evalCode=%s; opts.catchError=true; opts.createThumbnail=false; opts.maxOutputLines=Inf; publish(''%s'', opts);" 2>&1', ...
            matlab_bin, ustb_root, all_m(k).folder, out_dir, mat2str(eval_code), src);
        [status, output] = system(cmd);
        if status == 0
            fprintf('OK\n');
            succeeded{end+1} = src; %#ok<AGROW>
        else
            fprintf('FAILED (exit %d)\n', status);
            failed{end+1} = src; %#ok<AGROW>
        end
    else
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
