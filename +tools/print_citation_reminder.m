function print_citation_reminder()
%PRINT_CITATION_REMINDER  One-time reminder to cite USTB when the Generalized
%Beamformer (MIDPROCESS.DAS) is run.
%
%   Called from MIDPROCESS.DAS.GO(). Prints only once per MATLAB session,
%   tracked via a persistent flag, so it does not clutter the command
%   window when beamforming is run repeatedly (e.g. per frame, in a loop).
%
%   Other midprocess implementations (e.g. MIDPROCESS.FOURIER_BEAMFORMING)
%   have their own reference and are not covered by this reminder.
%
%   See also MIDPROCESS.DAS

persistent already_shown
if isempty(already_shown)
    already_shown = true;
    fprintf(['\n[USTB] If this toolbox contributes to your published work, please cite:\n' ...
        '  * Rodriguez-Molares et al., "The UltraSound ToolBox," IEEE IUS, 2017. doi:10.1109/ULTSYM.2017.8092389\n' ...
        '  * Rindal et al., "The Generalized Beamformer in the UltraSound ToolBox," Ultrasonics, 2026. doi:10.1016/j.ultras.2026.108289\n' ...
        'Datasets and individual processes may need additional references - see www.ustb.no/citation/\n\n']);
end

end
