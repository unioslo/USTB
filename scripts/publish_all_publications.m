function publish_all_publications(output_root)
%PUBLISH_ALL_PUBLICATIONS  MATLAB publish() for scripts linked from website/publications.html
%
%   Writes under output_root/publications/<venue>/<slug>/ matching deploy:
%     website/examples/publications/<venue>/<slug>/<script>.html
%
%   If output HTML already exists for a job (e.g. from a previously
%   downloaded tarball), that job is skipped. This allows incremental
%   publishing of only new/changed scripts.
%
%   See publish_publications.sh and website/publications.html iframes.

if nargin < 1 || isempty(output_root)
    output_root = fullfile(fileparts(mfilename('fullpath')), 'publications_html');
end

ustb_root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(ustb_root));

% Each row: relative folder under publications/, absolute path to .m
jobs = {
    'preprint/generalized_beamformer', fullfile(ustb_root, 'sandbox', 'The_Generalized_Beamformer', 'CPWC_double_adaptive_redone.m')
    'preprint/generalized_beamformer', fullfile(ustb_root, 'sandbox', 'The_Generalized_Beamformer', 'TheGB_all_transmit_sequences.m')
    'TUSON/Vralstad_et_al_2026_Retrospective_transmit_correction_of_blocked_arrays', fullfile(ustb_root, 'publications', 'TUSON', 'Vralstad_et_al_2026_Retrospective_transmit_correction_of_blocked_arrays', 'Correction_of_simulated_blockage.m')
    'TUFFC/Dynamic_range_2020', fullfile(ustb_root, 'publications', 'DynamicRange', 'dynamic_range_test.m')
    'TUFFC/Prieur_fDMAS_2018', fullfile(ustb_root, 'publications', 'TUFFC', 'Prieur_et_al_Signal_coherence_and_image_amplitude_with_the_fDMAS', 'FI_UFF_FIeldII_simulations_Fig2_and_Fig3.m')
    'IUS/2018_virtual_source_model', fullfile(ustb_root, 'publications', 'IUS2018', 'Rindal_et_al_ASimpleArtifactFreeVirtualSourceModel', 'Proceedings_FI_UFF_Verasonics_RTB_delay_models.m')
    'IUS/2017_dark_region_artifact', fullfile(ustb_root, 'publications', 'IUS2017', 'Rindal_et_al_TheDarkRegionArtifactInAdaptiveUltrasoundBeamforming', 'process_beamformed_experimental_data.m')
    };

opts = struct('format', 'html', 'showCode', true, 'evalCode', true, ...
    'catchError', true, 'createThumbnail', false, 'maxOutputLines', Inf, ...
    'figureSnapMethod', 'print');

failed = {};
skipped = 0;

for k = 1:size(jobs, 1)
    rel = jobs{k, 1};
    src = jobs{k, 2};
    out_dir = fullfile(output_root, 'publications', rel);

    [~, script_name] = fileparts(src);
    expected_html = fullfile(out_dir, [script_name, '.html']);

    if isfile(expected_html) && ~html_has_publish_error(expected_html)
        fprintf('[PUB-P] SKIP (already exists): %s/%s.html\n', rel, script_name);
        skipped = skipped + 1;
        continue
    end

    if isfile(expected_html)
        fprintf('[PUB-P] Re-publishing (previous HTML had errors): %s/%s.html\n', rel, script_name);
        delete(expected_html);
    end

    if ~isfile(src)
        fprintf('[PUB-P] SKIP missing source: %s\n', src);
        failed{end+1} = sprintf('missing source: %s', rel); %#ok<AGROW>
        continue
    end

    if ~exist(out_dir, 'dir')
        mkdir(out_dir);
    end

    opts.outputDir = out_dir;
    fprintf('[PUB-P] %s ... ', rel);

    original_dir = pwd;
    try
        cd(fileparts(src));
        publish(src, opts);
        fprintf('OK\n');
    catch me
        fprintf('FAILED: %s\n', me.message);
        failed{end+1} = sprintf('%s: %s', rel, me.message); %#ok<AGROW>
    end
    cd(original_dir);
    close all;
end

fprintf('\n=== Publications publish summary ===\n');
fprintf('Jobs: %d | Skipped (existing): %d | Published: %d\n', ...
    size(jobs, 1), skipped, size(jobs, 1) - skipped - numel(failed));
if ~isempty(failed)
    fprintf('Problems (%d):\n', numel(failed));
    for i = 1:numel(failed)
        fprintf('  %s\n', failed{i});
    end
end

function bad = html_has_publish_error(html_path)
% Return true if published HTML contains a MATLAB runtime error block.
    bad = false;
    try
        txt = fileread(html_path);
    catch
        return
    end
    bad = contains(txt, 'Error using') || contains(txt, 'Error in ');
end

end
