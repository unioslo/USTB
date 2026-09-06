% Basic Assignment: Sound Speed and Wave Fundamentals
%
% This assignment introduces fundamental concepts of sound speed, wavelength,
% and frequency in ultrasound imaging. You will learn basic calculations
% and understand how these parameters affect ultrasound imaging.
%
% Author: Ole Marius Hoel Rindal and Claude
clear all;
close all;

fprintf('=== BASIC ASSIGNMENT: SOUND SPEED AND WAVE FUNDAMENTALS ===\n\n');

%% ASSIGNMENT SECTION - COMPLETE THE FOLLOWING TASKS
% ==========================================================================
% STUDENTS: Complete the tasks below. Solutions are provided at the bottom.
% ==========================================================================

fprintf('ASSIGNMENT TASKS\n');
fprintf('===============\n\n');

% Given information
c_soft_tissue = 1540;    % Sound speed in soft tissue [m/s]
c_water = 1500;          % Sound speed in water [m/s]
c_bone = 3200;           % Sound speed in bone [m/s]

fprintf('Given information:\n');
fprintf('Sound speed in soft tissue: %d m/s\n', c_soft_tissue);
fprintf('Sound speed in water: %d m/s\n', c_water);
fprintf('Sound speed in bone: %d m/s\n\n', c_bone);

%% TASK 1: Basic Sound Speed Calculations


%% VISUALIZATION
fprintf('CREATING VISUALIZATIONS...\n');

% Plot 1: Sound speeds comparison
figure(1);
materials = {'Soft Tissue', 'Water', 'Bone'};
speeds = [c_soft_tissue, c_water, c_bone];
bar(speeds);
set(gca, 'XTickLabel', materials);
xlabel('Material');
ylabel('Sound Speed [m/s]');
title('Sound Speed in Different Materials');
grid on;

fprintf('TASK 1: Sound Speed Calculations\n');
fprintf('--------------------------------\n');

fprintf('A) Calculate the ONE-WAY travel time for ultrasound to reach a target 25 mm deep in soft tissue.\n');
fprintf('   Formula: time = distance / speed\n');
fprintf('   Your answer: _____ microseconds\n\n');

fprintf('B) Calculate the ROUND-TRIP travel time for the same target (25 mm deep).\n');
fprintf('   Remember: ultrasound imaging measures round-trip time\n');
fprintf('   Your answer: _____ microseconds\n\n');

fprintf('C) If you measure a round-trip time of 52 microseconds, how deep is the target?\n');
fprintf('   Formula: distance = (speed × time) / 2  [divide by 2 because it''s round-trip]\n');
fprintf('   Your answer: _____ mm\n\n');

%% TASK 2: Wave Calculations  
fprintf('TASK 2: Wave Calculations\n');
fprintf('----------------------------------\n');
fprintf('Sound speed formula: c = f × λ  (speed = frequency × wavelength)\n\n');

% Plot 2: Frequency vs Wavelength
figure(2);
frequencies = linspace(1e6, 15e6, 100);
wavelengths = c_soft_tissue ./ frequencies * 1000;
plot(frequencies/1e6, wavelengths, 'b-', 'LineWidth', 2);
xlabel('Frequency [MHz]');
ylabel('Wavelength [mm]');
title('Wavelength vs Frequency in Soft Tissue');
grid on;

% Mark common clinical frequencies
hold on;
clinical_freqs = [2e6, 5e6, 10e6];
clinical_wavelengths = c_soft_tissue ./ clinical_freqs * 1000;
plot(clinical_freqs/1e6, clinical_wavelengths, 'ro', 'MarkerSize', 8, 'LineWidth', 2);
for i = 1:length(clinical_freqs)
    text(clinical_freqs(i)/1e6, clinical_wavelengths(i), ...
         sprintf('  %.0f MHz', clinical_freqs(i)/1e6), 'VerticalAlignment', 'bottom');
end


fprintf('A) Calculate the wavelength of 5 MHz ultrasound in soft tissue.\n');
fprintf('   Formula: λ = c / f\n');
fprintf('   Your answer: _____ mm\n\n');

fprintf('B) What frequency is needed to get a wavelength of 0.4 mm in soft tissue?\n');
fprintf('   Formula: f = c / λ\n');
fprintf('   Your answer: _____ MHz\n\n');

%% TASK 3: Material Comparison
fprintf('TASK 3: Material Comparison\n');
fprintf('--------------------------\n');

fprintf('A) Compare round-trip travel time to reach 30 mm depth in:\n');
fprintf('   - Soft tissue: _____ microseconds\n');
fprintf('   - Water: _____ microseconds\n');
fprintf('   - Bone: _____ microseconds\n\n');

fprintf('B) Compare wavelength of 3 MHz ultrasound in:\n');
fprintf('   - Soft tissue: _____ mm\n');
fprintf('   - Water: _____ mm\n');
fprintf('   - Bone: _____ mm\n\n');

%% TASK 4: Clinical Understanding
fprintf('TASK 4: Clinical Understanding\n');
fprintf('-----------------------------\n');

% Plot 3: Clinical trade-off illustration
figure(3);
freq_range = 1:15; % MHz
resolution_quality = freq_range; % Higher frequency = better resolution
penetration_quality = 16 - freq_range; % Lower frequency = better penetration

plot(freq_range, resolution_quality, 'r-', 'LineWidth', 3, 'DisplayName', 'Resolution Quality');
hold on;
plot(freq_range, penetration_quality, 'b-', 'LineWidth', 3, 'DisplayName', 'Penetration Quality');
xlabel('Frequency [MHz]');
ylabel('Relative Quality');
title('Resolution vs Penetration Trade-off');
legend('show');
grid on;


fprintf('A) Why do we use LOW frequencies (2-5 MHz) for deep abdominal imaging?\n');
fprintf('   Your answer: _________________________________\n\n');

fprintf('B) Why do we use HIGH frequencies (10-15 MHz) for superficial imaging?\n');
fprintf('   Your answer: _________________________________\n\n');

fprintf('C) What is the fundamental trade-off in ultrasound frequency selection?\n');
fprintf('   Your answer: _________________________________\n\n');

%% TASK 5: Problem Solving
fprintf('TASK 5: Problem Solving\n');
fprintf('----------------------\n');

fprintf('A) An ultrasound system is calibrated for soft tissue (c = 1540 m/s).\n');
fprintf('   You image through water (c = 1480 m/s) and measure 40 mm depth.\n');
fprintf('   What is the TRUE depth in the water?\n');
fprintf('   Hint: The system assumes wrong speed, so distance = measured_distance × (true_speed / assumed_speed)\n');
fprintf('   Your answer: _____ mm\n\n');

fprintf('B) You want lateral resolution better than 0.2 mm in soft tissue.\n');
fprintf('   What minimum frequency do you need?\n');
fprintf('   Hint: Lateral resolution ≈ wavelength/2\n');
fprintf('   Your answer: _____ MHz\n\n');

fprintf('C) An ultrasound echo comes from a pixel 30 mm in front of the middle receive element.\n');
fprintf('   A second receive element is located 5 mm to the side.\n');
fprintf('   Assuming c = 1540 m/s, how long does the echo take to reach each element?\n\n');

fprintf('                 * Pixel\n');
fprintf('                 |\\\n');
fprintf('                 | \\\n');
fprintf('        30 mm    |  \\\n');
fprintf('                 |   \\\n');
fprintf('                 |    \\\n');
fprintf('                 |     \\\n');
fprintf('                 *------*\n');
fprintf('              middle   side\n');
fprintf('              element  element\n');
fprintf('                 < 5 mm >\n\n');

fprintf('   Your answers: _____ microseconds and _____ microseconds\n\n');

