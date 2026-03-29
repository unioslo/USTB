% build_toolbox.m
% Builds the USTB toolbox (.mltbx) for release.
% Version is injected from the TOOLBOX_VERSION environment variable
% when run via GitHub Actions, or defaults to 'dev' for local builds.

full_version = getenv('TOOLBOX_VERSION');
if isempty(full_version)
    full_version = 'dev';
    fprintf('No TOOLBOX_VERSION set, using "%s"\n', full_version);
else
    fprintf('Building USTB v%s\n', full_version);
end

% ToolboxVersion only accepts Major.Minor.Bug.Build (no pre-release
% suffixes like -rc1), so strip everything from the first hyphen onward.
version = regexprep(full_version, '-.*', '');

output_file = sprintf('USTB_v%s.mltbx', full_version);

% Load options from the existing .prj file (preserves all your
% file lists, icons, dependencies etc.), then override version + output
opts = matlab.addons.toolbox.ToolboxOptions('USTB.prj');
opts.ToolboxVersion = version;
opts.OutputFile     = output_file;

matlab.addons.toolbox.packageToolbox(opts);

fprintf('Toolbox built: %s\n', output_file);
