function publish_TheGB()
%PUBLISH_THEGB Publish the Generalized Beamformer paper examples to HTML
%
%   publish_TheGB() publishes selected scripts from the Generalized
%   Beamformer sandbox to HTML with code execution and figures.
%   Output is written to the webpage/ subfolder.
%
%   After publishing, run generate_TheGB_index.py to create the landing page.
%
%   See also PUBLISH, PUBLISH_ALL_EXAMPLES

this_dir = fileparts(mfilename('fullpath'));
ustb_root = fileparts(fileparts(this_dir));
output_dir = fullfile(this_dir, 'webpage');

addpath(genpath(ustb_root));

scripts = {
    fullfile(this_dir, 'CPWC_double_adaptive_redone.m'), ...
        'Double Adaptive Beamforming', ...
        'Compares five TX/RX DAS/MV configurations with gCNR and resolution analysis';
    fullfile(this_dir, 'illustrate_virtual_sources.m'), ...
        'Virtual Source Geometry', ...
        'Illustrates probe geometry, virtual sources, and scan types for DW/STA/PW';
    fullfile(this_dir, 'FI_coherence_factor.m'), ...
        'Focused Imaging with Coherence Factor', ...
        'Focused imaging on phased array with scanline vs RTB coherence factor';
    fullfile(this_dir, 'kWave_USTB_generalized_beamformer.m'), ...
        'k-Wave Simulation', ...
        'Full-wave simulation with selectable transmit waveform (FI/PW/STAI/DW)';
};

if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

set(0, 'DefaultFigureVisible', 'off');

opts.outputDir = output_dir;
opts.format = 'html';
opts.showCode = true;
opts.evalCode = true;
opts.catchError = true;
opts.createThumbnail = false;
opts.maxOutputLines = Inf;

fprintf('=== Publishing Generalized Beamformer Examples ===\n\n');

for k = 1:size(scripts, 1)
    src = scripts{k, 1};
    title = scripts{k, 2};
    [~, name, ~] = fileparts(src);

    fprintf('[%d/%d] %s (%s) ... ', k, size(scripts,1), title, name);

    original_dir = pwd;
    try
        cd(fileparts(src));
        publish(src, opts);
        fprintf('OK\n');
    catch me
        fprintf('FAILED: %s\n', me.message);
    end
    cd(original_dir);
    close all;
end

fprintf('\nDone. Output in: %s\n', output_dir);
fprintf('Run generate_TheGB_index.py to create the index page.\n');

set(0, 'DefaultFigureVisible', 'on');

end
