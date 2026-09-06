function T = uff_dataset_registry()
%UFF_DATASET_REGISTRY  Table of UFF datasets referenced under examples/ and publications/.
%
%   Each row describes one distinct dataset file available from the USTB dataset
%   repository (ustb.no/datasets). Used by RUN_DATASET_SMOKE_TESTS.
%
%   Columns (struct fields):
%     filename   - .uff file name
%     channel_h5 - HDF5 path to uff.channel_data (empty = auto-detect)
%     mode       - 'beamform' | 'beamformed_only'
%
%   mode 'beamformed_only' is for files that only store pre-beamformed results
%   (no channel_data), e.g. IUS2017 dark-region artifacts.
%
%   See also RUN_DATASET_SMOKE_TESTS, SIMPLE_PROCESS_DATASET

% Auto-generated inventory from examples/ and publications/ (repository paths
% in comments are hints for maintainers — not used at runtime).

T = struct('filename', {}, 'channel_h5', {}, 'mode', {}, 'note', {});

% --- examples/ (ustb.no/datasets) ---
T = add(T, 'Verasonics_P2-4_parasternal_long_small.uff', '', 'beamform', 'examples: FI phased array, minimal_example');
T = add(T, 'L7_FI_IUS2018.uff', '', 'beamform', 'examples: FI RTB / Verasonics');
T = add(T, 'L7_CPWC_193328.uff', '', 'beamform', 'examples: CPWC Verasonics');
T = add(T, 'L7_CPWC_TheGB.uff', '', 'beamform', 'examples: UiO course speed_of_sound');
T = add(T, 'Alpinion_L3-8_FI_hyperechoic_scatterers.uff', '', 'beamform', 'examples: Alpinion FI');
T = add(T, 'Alpinion_L3-8_FI_hypoechoic.uff', '', 'beamform', 'examples: advanced_beamforming');
T = add(T, 'Alpinion_L3-8_CPWC_hyperechoic_scatterers.uff', '', 'beamform', 'examples: CPWC Alpinion');
T = add(T, 'FieldII_STAI_uniform_fov.uff', '/channel_data', 'beamform', 'examples: STAI uniform FOV (Field II)');
T = add(T, 'FieldII_STAI_dynamic_range.uff', '', 'beamform', 'examples/publications: STAI dynamic range (/channel_data or /channel_data_speckle)');
T = add(T, 'ARFI_dataset.uff', '', 'beamform', 'examples: ARFI Verasonics');
T = add(T, 'PICMUS_experiment_resolution_distortion.uff', '', 'beamform', 'examples: PICMUS');
T = add(T, 'PICMUS_simulation_resolution_distortion.uff', '', 'beamform', 'examples: PICMUS');
T = add(T, 'PICMUS_experiment_contrast_speckle.uff', '', 'beamform', 'examples: PICMUS');
T = add(T, 'PICMUS_simulation_contrast_speckle.uff', '', 'beamform', 'examples: PICMUS');
T = add(T, 'PICMUS_carotid_cross.uff', '', 'beamform', 'examples: PICMUS in-vivo');
T = add(T, 'Verasonics_P2-4_parasternal_long_subject_1.uff', '', 'beamform', 'examples: SLSC / multi-frame');
T = add(T, 'FieldII_P4_point_scatterers.uff', '', 'beamform', 'examples: UiO phased array exercise');
T = add(T, 'experimental_STAI_dynamic_range.uff', '/channel_data', 'beamform', 'examples: UiO STAI sandbox');
T = add(T, 'P4_FI_121444_45mm_focus.uff', '', 'beamform', 'examples: REFoCUS');

% --- additional Zenodo datasets (not yet referenced in examples/) ---
T = add(T, 'Alpinion_L3-8_CPWC_hypoechoic.uff', '', 'beamform', 'Alpinion CPWC hypoechoic phantom');
T = add(T, 'FI_P4_cysts_center.uff', '', 'beamform', 'Field II P4 phased array cyst simulation');
T = add(T, 'FI_P4_point_scatterers.uff', '', 'beamform', 'Field II P4 phased array point scatterers');
T = add(T, 'FieldII_CPWC_simulation_v2.uff', '', 'beamform', 'Field II CPWC simulation');
T = add(T, 'FieldII_STAI_simulated_dynamic_range.uff', '', 'beamform', 'Field II STAI simulated dynamic range');
T = add(T, 'FieldII_speckle_DMASsimulation300000pts.uff', '', 'beamform', 'Field II DMAS speckle simulation');
T = add(T, 'L7_DW_TheGB.uff', '', 'beamform', 'L7-4 diverging wave (Generalized Beamformer)');
T = add(T, 'L7_FI_TheGB.uff', '', 'beamform', 'L7-4 focused imaging (Generalized Beamformer)');
T = add(T, 'L7_FI_Verasonics.uff', '', 'beamform', 'L7-4 focused imaging Verasonics');
T = add(T, 'L7_FI_Verasonics_CIRS.uff', '', 'beamform', 'L7-4 focused imaging Verasonics CIRS');
T = add(T, 'L7_FI_carotid_cross_1.uff', '', 'beamform', 'L7-4 in-vivo carotid cross-section');
T = add(T, 'L7_FI_carotid_cross_2.uff', '', 'beamform', 'L7-4 in-vivo carotid cross-section');
T = add(T, 'L7_STA_TheGB.uff', '', 'beamform', 'L7-4 synthetic transmit aperture (Generalized Beamformer)');
T = add(T, 'PICMUS_carotid_long.uff', '', 'beamform', 'PICMUS in-vivo carotid longitudinal');
T = add(T, 'PICMUS_numerical_calib_v2.uff', '', 'beamform', 'PICMUS numerical calibration');
T = add(T, 'STAI_UFF_CIRS_phantom.uff', '', 'beamform', 'STAI CIRS phantom');
T = add(T, 'SWE_L7_type_I.uff', '', 'beamform', 'Shear wave elastography type I');
T = add(T, 'SWE_L7_type_III.uff', '', 'beamform', 'Shear wave elastography type III');
T = add(T, 'SWE_L7_type_IV.uff', '', 'beamform', 'Shear wave elastography type IV');
T = add(T, 'Verasonics_P2-4_apical_four_chamber_subject_1.uff', '', 'beamform', 'In-vivo cardiac apical four-chamber');
T = add(T, 'experimental_dynamic_range_phantom.uff', '', 'beamform', 'Experimental dynamic range phantom');
T = add(T, 'reference_RTB_data.uff', '', 'beamformed_only', 'RTB reference data (beamformed only)');
T = add(T, 'speckle_sim_FI_P4_probe_apod_1_speckle_long_many_angles.uff', '', 'beamform', 'publications: Vralstad full aperture');
T = add(T, 'speckle_sim_FI_P4_probe_apod_2_speckle_long_many_angles.uff', '', 'beamform', 'publications: Vralstad 1/3 blocked');

% --- additional Zenodo datasets (not yet referenced in examples/) ---
T = add(T, 'Alpinion_L3-8_CPWC_hypoechoic.uff', '', 'beamform', 'Alpinion CPWC hypoechoic phantom');
T = add(T, 'FI_P4_cysts_center.uff', '', 'beamform', 'Field II P4 phased array cyst simulation');
T = add(T, 'FI_P4_point_scatterers.uff', '', 'beamform', 'Field II P4 phased array point scatterers');
T = add(T, 'FieldII_CPWC_simulation_v2.uff', '', 'beamform', 'Field II CPWC simulation');
T = add(T, 'FieldII_STAI_simulated_dynamic_range.uff', '', 'beamform', 'Field II STAI simulated dynamic range');
T = add(T, 'FieldII_speckle_DMASsimulation300000pts.uff', '', 'beamform', 'Field II DMAS speckle simulation');
T = add(T, 'L7_DW_TheGB.uff', '', 'beamform', 'L7-4 diverging wave (Generalized Beamformer)');
T = add(T, 'L7_FI_TheGB.uff', '', 'beamform', 'L7-4 focused imaging (Generalized Beamformer)');
T = add(T, 'L7_FI_Verasonics.uff', '', 'beamform', 'L7-4 focused imaging Verasonics');
T = add(T, 'L7_FI_Verasonics_CIRS.uff', '', 'beamform', 'L7-4 focused imaging Verasonics CIRS');
T = add(T, 'L7_FI_carotid_cross_1.uff', '', 'beamform', 'L7-4 in-vivo carotid cross-section');
T = add(T, 'L7_FI_carotid_cross_2.uff', '', 'beamform', 'L7-4 in-vivo carotid cross-section');
T = add(T, 'L7_STA_TheGB.uff', '', 'beamform', 'L7-4 synthetic transmit aperture (Generalized Beamformer)');
T = add(T, 'PICMUS_carotid_long.uff', '', 'beamform', 'PICMUS in-vivo carotid longitudinal');
T = add(T, 'PICMUS_numerical_calib_v2.uff', '', 'beamform', 'PICMUS numerical calibration');
T = add(T, 'STAI_UFF_CIRS_phantom.uff', '', 'beamform', 'STAI CIRS phantom');
T = add(T, 'SWE_L7_type_I.uff', '', 'beamform', 'Shear wave elastography type I');
T = add(T, 'SWE_L7_type_III.uff', '', 'beamform', 'Shear wave elastography type III');
T = add(T, 'SWE_L7_type_IV.uff', '', 'beamform', 'Shear wave elastography type IV');
T = add(T, 'Verasonics_P2-4_apical_four_chamber_subject_1.uff', '', 'beamform', 'In-vivo cardiac apical four-chamber');
T = add(T, 'experimental_dynamic_range_phantom.uff', '', 'beamform', 'Experimental dynamic range phantom');
T = add(T, 'reference_RTB_data.uff', '', 'beamformed_only', 'RTB reference data (beamformed only)');
T = add(T, 'speckle_sim_FI_P4_probe_apod_1_speckle_long_many_angles.uff', '', 'beamform', 'publications: Vralstad full aperture');
T = add(T, 'speckle_sim_FI_P4_probe_apod_2_speckle_long_many_angles.uff', '', 'beamform', 'publications: Vralstad 1/3 blocked');

% --- publications/ (Zenodo 20261898) ---
T = add(T, 'speckle_sim_FI_P4_probe_apod_3_speckle_long_many_angles.uff', '', 'beamform', 'publications: Vralstad blockage');
T = add(T, 'L7_FI_Verasonics_CIRS_points.uff', '', 'beamform', 'publications: TUFFC fDMAS');
T = add(T, 'L7_FI_carotid_cross_sub_2.uff', '', 'beamform', 'publications: TUFFC GCNR');
T = add(T, 'invitro_20.uff', '', 'beamform', 'publications: TUFFC GCNR');
T = add(T, 'insilico_20.uff', '', 'beamform', 'publications: IUS2019 GCNR NLM');
T = add(T, 'FieldII_CPWC_point_scatterers_res_v2.uff', '', 'beamform', 'publications: IUS2020 resolution');
T = add(T, 'beamformed_simulated_data.uff', '', 'beamformed_only', 'publications: IUS2017 dark region (beamformed only)');
T = add(T, 'beamformed_experimental_data.uff', '', 'beamformed_only', 'publications: IUS2017 dark region (beamformed only)');

T = dedupe_by_filename(T);
end

function T = add(T, filename, channel_h5, mode, note)
s.filename = filename;
s.channel_h5 = channel_h5;
s.mode = mode;
s.note = note;
T = [T, s]; %#ok<AGROW>
end

function T = dedupe_by_filename(T)
[~, ia] = unique({T.filename}, 'stable');
T = T(ia);
end
