function b_data = dataset_preview_beamform(uff_file)
%DATASET_PREVIEW_BEAMFORM  Beamform for website preview — matches the canonical example per dataset.
%
%   See comments per case for the source script under examples/ or publications/.

[~, name, ext] = fileparts(uff_file);
fn = [name ext];

switch fn
    case 'Verasonics_P2-4_parasternal_long_small.uff'
        % examples/UiO_course/.../minimal_example.m
        channel_data = uff.read_object(uff_file, '/channel_data');
        depth_axis = linspace(0e-3, 110e-3, 1024).';
        azimuth_axis = linspace(channel_data.sequence(1).source.azimuth, ...
            channel_data.sequence(end).source.azimuth, channel_data.N_waves).';
        scan = uff.sector_scan('azimuth_axis', azimuth_axis, 'depth_axis', depth_axis);
        mid = midprocess.das();
        mid.channel_data = channel_data;
        mid.dimension = dimension.both();
        mid.scan = scan;
        mid.transmit_apodization.window = uff.window.scanline;
        mid.receive_apodization.window = uff.window.none;
        b_data = mid.go();

    case 'L7_FI_IUS2018.uff'
        % examples/uff/FI_UFF_Verasonics_RTB.m (first FI image)
        channel_data = uff.read_object(uff_file, '/channel_data');
        x_axis = zeros(channel_data.N_waves, 1);
        for n = 1:channel_data.N_waves
            x_axis(n) = channel_data.sequence(n).source.x;
        end
        z_axis = linspace(1e-3, 62e-3, 512 * 2).';
        scan = uff.linear_scan('x_axis', x_axis, 'z_axis', z_axis);
        mid = midprocess.das();
        mid.dimension = dimension.both();
        mid.channel_data = channel_data;
        mid.scan = scan;
        mid.transmit_apodization.window = uff.window.scanline;
        mid.receive_apodization.window = uff.window.none;
        mid.receive_apodization.f_number = 1.7;
        b_data = mid.go();

    case 'L7_CPWC_193328.uff'
        % examples/uff/CPWC_UFF_Verasonics.m
        channel_data = uff.read_object(uff_file, '/channel_data');
        scan = uff.linear_scan();
        scan.x_axis = linspace(channel_data.probe.x(1), channel_data.probe.x(end), 256).';
        scan.z_axis = linspace(0, 50e-3, 256).';
        mid = midprocess.das();
        mid.dimension = dimension.both;
        mid.channel_data = channel_data;
        mid.scan = scan;
        mid.transmit_apodization.window = uff.window.none;
        mid.transmit_apodization.f_number = 1.7;
        mid.receive_apodization.window = uff.window.none;
        mid.receive_apodization.f_number = 1.7;
        b_data = mid.go();

    case 'L7_CPWC_TheGB.uff'
        % examples/.../speed_of_sound.m (Part I, 1460 m/s, single transmit)
        channel_data = uff.read_object(uff_file, '/channel_data');
        channel_data.N_frames = 1;
        channel_data.sequence = channel_data.sequence(6);
        channel_data.data = channel_data.data(:, :, 6);
        channel_data.sound_speed = 1460;
        for seq = 1:channel_data.N_waves
            channel_data.sequence(seq).sound_speed = channel_data.sound_speed;
        end
        scan = uff.linear_scan();
        scan.x_axis = linspace(channel_data.probe.x(1), channel_data.probe.x(end), 512).';
        scan.z_axis = linspace(3e-3, 50e-3, 512).';
        mid = midprocess.das();
        mid.dimension = dimension.both;
        mid.channel_data = channel_data;
        mid.scan = scan;
        mid.transmit_apodization.window = uff.window.none;
        mid.receive_apodization.window = uff.window.tukey50;
        b_data = mid.go();

    case 'Alpinion_L3-8_FI_hyperechoic_scatterers.uff'
        % examples/uff/FI_UFF_Alpinion.m
        b_data = beamform_alpinion_fi(channel_data_from(uff_file));

    case 'Alpinion_L3-8_FI_hypoechoic.uff'
        % examples/advanced_beamforming/FI_UFF_synthetic_TX_SLSC.m (DAS before switching to scanline TX)
        channel_data = uff.read_object(uff_file, '/channel_data');
        z_axis = linspace(0e-3, 60e-3, 750).';
        x_axis = zeros(channel_data.N_waves, 1);
        for n = 1:channel_data.N_waves
            x_axis(n) = channel_data.sequence(n).source.x;
        end
        scan = uff.linear_scan('x_axis', x_axis, 'z_axis', z_axis);
        das = midprocess.das();
        das.channel_data = channel_data;
        das.dimension = dimension.transmit();
        das.scan = scan;
        das.transmit_apodization.window = uff.window.tukey25;
        das.transmit_apodization.f_number = 4;
        das.receive_apodization.window = uff.window.tukey25;
        das.receive_apodization.f_number = 3;
        b_delayed = das.go();
        cc = postprocess.coherent_compounding();
        cc.input = b_delayed;
        b_data = cc.go();

    case 'Alpinion_L3-8_CPWC_hyperechoic_scatterers.uff'
        % examples/uff/CPWC_UFF_Alpinion.m
        channel_data = uff.read_object(uff_file, '/channel_data');
        scan = uff.linear_scan();
        scan.x_axis = linspace(channel_data.probe.x(1), channel_data.probe.x(end), 512).';
        scan.z_axis = linspace(1e-3, 50e-3, 512).';
        mid = midprocess.das();
        mid.dimension = dimension.both;
        mid.channel_data = channel_data;
        mid.scan = scan;
        mid.receive_apodization.window = uff.window.tukey25;
        mid.receive_apodization.f_number = 1.7;
        b_data = mid.go();

    case 'FieldII_STAI_uniform_fov.uff'
        % examples/uff/STAI_UFF_beamform_with_demodulation.m (demodulated IQ branch, right-hand figure)
        ch = uff.channel_data();
        if has_h5_dataset(uff_file, '/channel_data_speckle')
            ch.read(uff_file, '/channel_data_speckle');
        else
            ch.read(uff_file, '/channel_data');
        end
        demod = preprocess.fast_demodulation();
        demod.plot_on = false;
        demod.input = ch;
        ch_demod = demod.go();
        sca = uff.linear_scan('x_axis', linspace(ch.probe.x(1), ch.probe.x(end), 512).', ...
            'z_axis', linspace(2.5e-3, 55e-3, 512).');
        mid = midprocess.das();
        mid.scan = sca;
        mid.channel_data = ch_demod;
        mid.dimension = dimension.both();
        mid.receive_apodization.window = uff.window.boxcar;
        mid.receive_apodization.f_number = 1.75;
        mid.transmit_apodization.window = uff.window.boxcar;
        mid.transmit_apodization.f_number = 1.75;
        b_data = mid.go();

    case 'FieldII_STAI_dynamic_range.uff'
        % publications/DynamicRange/process_simulation.m (DAS image with uniform FOV weights)
        % Preview: same lateral/depth extent as the paper script but fewer pixels to avoid OOM.
        channel_data = uff.channel_data();
        channel_data.read(uff_file, '/channel_data');
        scan = uff.linear_scan('x_axis', linspace(-20e-3, 20e-3, 512).', ...
            'z_axis', linspace(6e-3, 52.5e-3, 1024).');
        mid = midprocess.das();
        mid.channel_data = channel_data;
        mid.scan = scan;
        mid.dimension = dimension.transmit();
        mid.receive_apodization.window = uff.window.boxcar;
        mid.receive_apodization.f_number = 1.75;
        mid.transmit_apodization.window = uff.window.boxcar;
        mid.transmit_apodization.f_number = 1.75;
        b_data_tx = mid.go();
        clear channel_data
        b_data_tx.data = b_data_tx.data + randn(size(b_data_tx.data)) * eps; % as in process_simulation.m
        [weights, ~, ~] = tools.uniform_fov_weighting(mid);
        das = postprocess.coherent_compounding();
        das.input = b_data_tx;
        b_data_das = das.go();
        b_data_das.data = b_data_das.data .* weights(:);
        b_data = b_data_das;

    case 'ARFI_dataset.uff'
        % examples/acoustical_radiation_force_imaging/ARFI_UFF_Verasonics.m
        channel_data = uff.read_object(uff_file, '/channel_data');
        sca = uff.linear_scan();
        sca.x_axis = linspace(channel_data.probe.x(1), channel_data.probe.x(end), 256).';
        sca.z_axis = linspace(0, 30e-3, 768).';
        pipe = pipeline();
        pipe.channel_data = channel_data;
        pipe.scan = sca;
        pipe.receive_apodization.window = uff.window.tukey50;
        pipe.receive_apodization.f_number = 1.7;
        pipe.transmit_apodization.window = uff.window.tukey50;
        pipe.transmit_apodization.f_number = 1.7;
        b_data = pipe.go({midprocess.das postprocess.coherent_compounding});

    case {'PICMUS_experiment_resolution_distortion.uff', 'PICMUS_simulation_resolution_distortion.uff', ...
            'PICMUS_experiment_contrast_speckle.uff', 'PICMUS_simulation_contrast_speckle.uff', ...
            'PICMUS_carotid_cross.uff'}
        % examples/picmus/experiment_resolution_distortion.m (and invivo_carotid_cross.m for carotid)
        channel_data = uff.read_object(uff_file, '/channel_data');
        scan = uff.read_object(uff_file, '/scan');
        pipe = pipeline();
        pipe.channel_data = channel_data;
        pipe.scan = scan;
        pipe.receive_apodization.window = uff.window.tukey50;
        pipe.receive_apodization.f_number = 1.7;
        pipe.transmit_apodization.window = uff.window.tukey50;
        pipe.transmit_apodization.f_number = 1.7;
        b_data = pipe.go({midprocess.das postprocess.coherent_compounding});

    case 'Verasonics_P2-4_parasternal_long_subject_1.uff'
        % examples/advanced_beamforming/FI_UFF_short_lag_spatial_coherence.m (cardiac DAS)
        channel_data = uff.read_object(uff_file, '/channel_data');
        depth_axis = linspace(0e-3, 110e-3, 512).';
        azimuth_axis = zeros(channel_data.N_waves, 1);
        for n = 1:channel_data.N_waves
            azimuth_axis(n) = channel_data.sequence(n).source.azimuth;
        end
        scan = uff.sector_scan('azimuth_axis', azimuth_axis, 'depth_axis', depth_axis);
        mid = midprocess.das();
        mid.dimension = dimension.transmit;
        mid.channel_data = channel_data;
        mid.scan = scan;
        mid.transmit_apodization.window = uff.window.scanline;
        mid.receive_apodization.window = uff.window.none;
        b_delayed = mid.go();
        das = postprocess.coherent_compounding();
        das.input = b_delayed;
        b_data = das.go();

    case 'FieldII_P4_point_scatterers.uff'
        % examples/.../FI_UFF_phased_array_exercise.m
        channel_data = uff.read_object(uff_file, '/channel_data');
        depth_axis = linspace(0e-3, 110e-3, 1024).';
        azimuth_axis = zeros(channel_data.N_waves, 1);
        for n = 1:channel_data.N_waves
            azimuth_axis(n) = channel_data.sequence(n).source.azimuth;
        end
        scan = uff.sector_scan('azimuth_axis', azimuth_axis, 'depth_axis', depth_axis);
        mid = midprocess.das();
        mid.channel_data = channel_data;
        mid.scan = scan;
        mid.dimension = dimension.both();
        mid.transmit_apodization.window = uff.window.scanline;
        mid.receive_apodization.window = uff.window.none;
        b_data = mid.go();

    case 'experimental_STAI_dynamic_range.uff'
        % examples/.../STAI_sandbox.m (demodulated beamforming)
        channel_data = uff.channel_data();
        channel_data.read(uff_file, '/channel_data');
        demod = preprocess.demodulation();
        demod.input = channel_data;
        demod.modulation_frequency = channel_data.pulse.center_frequency;
        ch_demod = demod.go();
        sca = uff.linear_scan('x_axis', linspace(channel_data.probe.x(1), channel_data.probe.x(end), 512).', ...
            'z_axis', linspace(2.5e-3, 55e-3, 512).');
        mid = midprocess.das();
        mid.scan = sca;
        mid.channel_data = ch_demod;
        mid.dimension = dimension.both();
        mid.receive_apodization.window = uff.window.boxcar;
        mid.receive_apodization.f_number = 1.75;
        mid.transmit_apodization.window = uff.window.none;
        mid.transmit_apodization.f_number = 1.75;
        b_data = mid.go();

    case 'FieldII_STAI_axial_gradient_v2.uff'
        % publications/DynamicRange/process_simulation_only_axial_gradient.m (DAS with uniform FOV weights)
        % Preview: subsampled z grid (same extent) to reduce memory.
        channel_data = uff.channel_data();
        channel_data.read(uff_file, '/channel_data');
        scan = uff.linear_scan('x_axis', linspace(-20e-3, 20e-3, 512).', ...
            'z_axis', linspace(8e-3, 55e-3, 1024).');
        mid = midprocess.das();
        mid.channel_data = channel_data;
        mid.scan = scan;
        mid.dimension = dimension.transmit();
        mid.receive_apodization.window = uff.window.boxcar;
        mid.receive_apodization.f_number = 1.75;
        mid.transmit_apodization.window = uff.window.boxcar;
        mid.transmit_apodization.f_number = 1.75;
        b_tx = mid.go();
        clear channel_data
        b_tx.data = b_tx.data + randn(size(b_tx.data)) * eps;
        [weights, ~, ~] = tools.uniform_fov_weighting(mid);
        cc = postprocess.coherent_compounding();
        cc.input = b_tx;
        b_das = cc.go();
        b_das.data = b_das.data .* weights(:);
        b_data = b_das;

    case 'FieldII_STAI_gradient_full_field_100.uff'
        % publications/DynamicRange/process_simulation_full_gradient.m (DAS after compounding + weights)
        % Preview: subsampled z grid (same extent) to reduce memory.
        channel_data = uff.channel_data();
        channel_data.read(uff_file, '/channel_data');
        scan = uff.linear_scan('x_axis', linspace(-20e-3, 20e-3, 256).', ...
            'z_axis', linspace(5e-3, 50e-3, 1024).');
        mid = midprocess.das();
        mid.channel_data = channel_data;
        mid.scan = scan;
        mid.dimension = dimension.transmit();
        mid.receive_apodization.window = uff.window.boxcar;
        mid.receive_apodization.f_number = 1.75;
        mid.transmit_apodization.window = uff.window.boxcar;
        mid.transmit_apodization.f_number = 1.75;
        b_tx = mid.go();
        [weights, ~, ~] = tools.uniform_fov_weighting(mid);
        das = postprocess.coherent_compounding();
        das.input = b_tx;
        b_das = das.go();
        b_das.data = b_das.data .* weights(:);
        b_data = b_das;

    case 'P4_FI_121444_45mm_focus.uff'
        % examples/REFoCUS/FI_REFOCUS_coherence.m — conventional scan-line DAS + compounding
        channel_data = uff.read_object(uff_file, '/channel_data');
        channel_data.N_frames = 1;
        for seq = 1:channel_data.N_waves
            channel_data.sequence(seq).origin.xyz = [0, 0, 0];
        end
        depth_axis = linspace(0e-3, 60e-3, 512).';
        azimuth_axis = zeros(channel_data.N_waves, 1);
        for n = 1:channel_data.N_waves
            azimuth_axis(n) = channel_data.sequence(n).source.azimuth;
        end
        MLA = 1;
        scan_MLA = uff.sector_scan('azimuth_axis', ...
            linspace(channel_data.sequence(1).source.azimuth, channel_data.sequence(end).source.azimuth, ...
            length(channel_data.sequence) * MLA)', 'depth_axis', depth_axis);
        mid_sl = midprocess.das();
        mid_sl.channel_data = channel_data;
        mid_sl.dimension = dimension.transmit();
        mid_sl.scan = scan_MLA;
        mid_sl.receive_apodization.window = uff.window.none;
        mid_sl.receive_apodization.f_number = 1.7;
        mid_sl.transmit_apodization.window = uff.window.scanline;
        b_delayed = mid_sl.go();
        cc = postprocess.coherent_compounding();
        cc.input = b_delayed;
        b_data = cc.go();

    case 'FieldII_speckle_simulation.uff'
        % examples/field_II/STAI_L11_speckle_parfor.m
        channel_data = uff.read_object(uff_file, '/channel_data');
        scan = uff.linear_scan('x_axis', linspace(-5e-3, 5e-3, 256).', ...
            'z_axis', linspace(15e-3, 20e-3, 256).');
        pipe = pipeline();
        pipe.channel_data = channel_data;
        pipe.scan = scan;
        b_data = pipe.go({midprocess.das() postprocess.coherent_compounding()});

    case 'test02.uff'
        % examples/uff/CPWC_UFF_read.m — beamforming uses /scan from file (same as stored b_data)
        channel_data = uff.read_object(uff_file, '/channel_data');
        scan = uff.read_object(uff_file, '/scan');
        mid = midprocess.das();
        mid.dimension = dimension.both;
        mid.channel_data = channel_data;
        mid.scan = scan;
        mid.transmit_apodization.window = uff.window.tukey50;
        mid.transmit_apodization.f_number = 1.0;
        mid.receive_apodization.window = uff.window.tukey50;
        mid.receive_apodization.f_number = 1.0;
        b_data = mid.go();

    case 'speckle_sim_FI_P4_probe_apod_3_speckle_long_many_angles.uff'
        % publications/TUFFC/Vralstad_et_al_.../Correction_of_simulated_blockage.m (RTB block)
        channel_data = uff.read_object(uff_file, '/channel_data');
        channel_data.data = channel_data.data ./ max(channel_data.data(:));
        depth_axis = linspace(0e-3, 110e-3, 512).';
        azimuth_axis = zeros(channel_data.N_waves, 1);
        for n = 1:channel_data.N_waves
            azimuth_axis(n) = channel_data.sequence(n).source.azimuth;
        end
        scan = uff.sector_scan('azimuth_axis', azimuth_axis, 'depth_axis', depth_axis);
        Fnumber = channel_data.sequence(1).source.distance / (max(channel_data.probe.x) * 2);
        mid = midprocess.das();
        mid.channel_data = channel_data;
        mid.dimension = dimension.both();
        mid.scan = scan;
        mid.code = code.mex;
        mid.receive_apodization.window = uff.window.boxcar;
        mid.receive_apodization.f_number = 1.7;
        mid.transmit_apodization.window = uff.window.hamming;
        mid.transmit_apodization.f_number = Fnumber;
        mid.transmit_apodization.minimum_aperture = 3e-3;
        b_data = mid.go();

    case 'L7_FI_Verasonics_CIRS_points.uff'
        % publications/TUFFC/.../FI_UFF_delay_multiply_and_sum_Fig5_and_Fig6.m (DAS)
        channel_data = uff.read_object(uff_file, '/channel_data');
        z_axis = linspace(5e-3, 45e-3, 1700).';
        x_axis = zeros(channel_data.N_waves, 1);
        for n = 1:channel_data.N_waves
            x_axis(n) = channel_data.sequence(n).source.x;
        end
        scan = uff.linear_scan('x_axis', x_axis, 'z_axis', z_axis);
        delay = midprocess.das();
        delay.channel_data = channel_data;
        delay.scan = scan;
        delay.dimension = dimension.transmit();
        delay.transmit_apodization.window = uff.window.scanline;
        delay.receive_apodization.window = uff.window.none;
        delay.receive_apodization.f_number = 1.7;
        delayed_b_data = delay.go();
        das = postprocess.coherent_compounding();
        das.input = delayed_b_data;
        b_data = das.go();

    case 'L7_FI_carotid_cross_sub_2.uff'
        % publications/TUFFC/.../Invivo_experiment_MLA.m (DAS with MLA pipeline)
        channel_data = uff.channel_data();
        channel_data.read(uff_file, '/channel_data');
        if size(channel_data.data, 4) >= 2
            channel_data.data = channel_data.data(:, :, :, 2);
        end
        MLA = 4;
        z_axis = linspace(7e-3, 25e-3, 768).';
        x_axis = linspace(channel_data.sequence(1).source.x, channel_data.sequence(end).source.x, ...
            channel_data.N_waves .* MLA);
        scan = uff.linear_scan('x_axis', x_axis', 'z_axis', z_axis);
        pipe = pipeline();
        pipe.scan = scan;
        pipe.channel_data = channel_data;
        pipe.transmit_apodization.window = uff.window.scanline;
        pipe.transmit_apodization.MLA = [MLA, 1];
        pipe.transmit_apodization.MLA_overlap = [2, 0];
        pipe.receive_apodization.window = uff.window.boxcar;
        pipe.receive_apodization.f_number = 1;
        das = midprocess.das();
        das.dimension = dimension.both;
        b_data = pipe.go({das});

    case 'invitro_20.uff'
        % publications/TUFFC/.../Invitro_experiment.m
        mix = uff.channel_data();
        mix.read(uff_file, '/mix');
        M = 45;
        x0 = -0.2118e-3;
        z0 = 15.62e-3;
        sca = uff.linear_scan('x_axis', x0 + linspace(-4e-3, 9e-3, 256).', ...
            'z_axis', z0 + linspace(-4e-3, 4e-3, 2.5 * 256).');
        pipe = pipeline();
        pipe.scan = sca;
        pipe.channel_data = mix;
        pipe.transmit_apodization.window = uff.window.flat;
        pipe.transmit_apodization.f_number = 1;
        pipe.transmit_apodization.minimum_aperture = M * mix.probe.pitch;
        pipe.transmit_apodization.maximum_aperture = M * mix.probe.pitch;
        pipe.receive_apodization.window = uff.window.flat;
        pipe.receive_apodization.f_number = 1;
        pipe.receive_apodization.minimum_aperture = M * mix.probe.pitch;
        pipe.receive_apodization.maximum_aperture = M * mix.probe.pitch;
        das = midprocess.das();
        das.dimension = dimension.both;
        b_data = pipe.go({das});

    case 'insilico_20.uff'
        % publications/IUS2019/GCNR_NLM/NLM_proceedings.m
        mix = uff.channel_data();
        mix.read(uff_file, '/mix');
        sca = uff.linear_scan('x_axis', linspace(-6e-3, 6e-3, 256).', ...
            'z_axis', linspace(14e-3, 26e-3, 256).');
        M = 55;
        x0 = 0e-3;
        z0 = 20e-3;
        aperture = M * mix.probe.pitch;
        F = z0 / aperture;
        r_off = round(1.2 * mix.lambda * F, 5);
        r = 3e-3;
        ri = r - r_off;
        pipe = pipeline();
        pipe.scan = sca;
        pipe.channel_data = mix;
        pipe.transmit_apodization.window = uff.window.flat;
        pipe.transmit_apodization.f_number = 1;
        pipe.transmit_apodization.minimum_aperture = M * mix.probe.pitch;
        pipe.transmit_apodization.maximum_aperture = M * mix.probe.pitch;
        pipe.receive_apodization.window = uff.window.flat;
        pipe.receive_apodization.f_number = 1;
        pipe.receive_apodization.minimum_aperture = M * mix.probe.pitch;
        pipe.receive_apodization.maximum_aperture = M * mix.probe.pitch;
        das = midprocess.das();
        das.dimension = dimension.both;
        b_data = pipe.go({das});

    case 'insilico_side_100_M45.uff'
        % publications/TUFFC/.../Insilico_experiment.m
        mix = uff.channel_data();
        mix.read(uff_file, '/mix');
        M = 45;
        sca = uff.linear_scan('x_axis', linspace(-6e-3, 6e-3, 128).', ...
            'z_axis', linspace(17e-3, 23e-3, 2.5 * 128).');
        pipe = pipeline();
        pipe.scan = sca;
        pipe.channel_data = mix;
        pipe.transmit_apodization.window = uff.window.flat;
        pipe.transmit_apodization.f_number = 1;
        pipe.transmit_apodization.minimum_aperture = M * mix.probe.pitch;
        pipe.transmit_apodization.maximum_aperture = M * mix.probe.pitch;
        pipe.receive_apodization.window = uff.window.flat;
        pipe.receive_apodization.f_number = 1;
        pipe.receive_apodization.minimum_aperture = M * mix.probe.pitch;
        pipe.receive_apodization.maximum_aperture = M * mix.probe.pitch;
        das = midprocess.das();
        das.dimension = dimension.both;
        b_data = pipe.go({das});

    case 'FieldII_CPWC_point_scatterers_res_v2.uff'
        % publications/IUS2020/.../process_CPWC_L7_4_probe_point_scatter.m (DAS only, no compounding)
        channel_data = uff.channel_data();
        channel_data.read(uff_file, '/channel_data');
        sca = uff.linear_scan('x_axis', linspace(-3e-3, 3e-3, 512).', ...
            'z_axis', linspace(35e-3, 42e-3, 256).');
        pipe = pipeline();
        pipe.channel_data = channel_data;
        pipe.scan = sca;
        pipe.receive_apodization.window = uff.window.none;
        b_data = pipe.go({midprocess.das()});

    case 'P4_FI.uff'
        % publications/IUS2018/.../FI_UFF_phased_array_MLA_and_RTB_delay_models.m (conventional)
        channel_data = uff.read_object(uff_file, '/channel_data');
        scan = uff.sector_scan('azimuth_axis', ...
            linspace(channel_data.sequence(1).source.azimuth, channel_data.sequence(end).source.azimuth, ...
            length(channel_data.sequence))', ...
            'depth_axis', linspace(0, 90e-3, 512)');
        mid = midprocess.das();
        mid.channel_data = channel_data;
        mid.dimension = dimension.both();
        mid.scan = scan;
        mid.transmit_apodization.window = uff.window.scanline;
        mid.receive_apodization.window = uff.window.tukey25;
        mid.receive_apodization.f_number = 1.7;
        b_data = mid.go();

    case 'beamformed_simulated_data.uff'
        b_data = uff.read_object(uff_file, '/b_data_das');

    case 'beamformed_experimental_data.uff'
        b_data = uff.read_object(uff_file, '/b_data_das');

    otherwise
        error('dataset_preview_beamform:noCase', ...
            'No preview recipe for %s — add a case in dataset_preview_beamform.m', fn);
end
end

function ch = channel_data_from(uff_file)
ch = uff.read_object(uff_file, '/channel_data');
end

function b_data = beamform_alpinion_fi(channel_data)
x_axis = zeros(channel_data.N_waves, 1);
for n = 1:channel_data.N_waves
    x_axis(n) = channel_data.sequence(n).source.x;
end
z_axis = linspace(1e-3, 55e-3, 512).';
scan = uff.linear_scan('x_axis', x_axis, 'z_axis', z_axis);
mid = midprocess.das();
mid.dimension = dimension.both();
mid.channel_data = channel_data;
mid.scan = scan;
mid.transmit_apodization.window = uff.window.scanline;
mid.receive_apodization.window = uff.window.tukey25;
mid.receive_apodization.f_number = 1.7;
b_data = mid.go();
end

function ok = has_h5_dataset(file, pathstr)
ok = false;
try
    h5info(file, pathstr);
    ok = true;
catch
end
end
