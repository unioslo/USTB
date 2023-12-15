# Module 1 Introduction to the USTB: Getting familiar with the USTB and MATLAB

This module contains two exercises. The first exercise is to demonstrate that you have installed MATLAB and have set up the USTB. The second exercise is
is to familiarize ourselves with some MATLAB concepts that will come in handy later in the course.

## Delivery:
Please provide a written report that

- report the results you are asked to find
- answers the question raised
- provides the main code lines needed to solve the questions directly in the report
- all plots needed for supporting your arguments when answering the exercise parts

The report should be uploaded to [devilry.ifi.uio.no](https//devilry.ifi.uio.no).  
**Deadline for uploading: Wednesday 13. September at 10:00. **

## Exercise 1 : Set up MATLAB and the USTB
The first exercise is simply to demonstrate that you have installed MATLAB and sucessfully set up the USTB. Run the "minimal_example.m" in this folder and add
your name to the title of the figure of the ultrasound image. Save this figure and add it to your report.

NB! If you have trouble downloading the data using the download tool you can download the data directly from https://ustb.no/datasets/Verasonics_P2-4_parasternal_long_small.uff . 
Delete the corrupt file with the same filename and move the downloaded data to the "data/" folder in the USTB repository and rerun the example. 

## Exercise 2 : Introduction to MATLAB
In the second exercise you will be exposed to some MATLAB concepts that are relevant for the course. You need to answer each task found in the "MATLAB_intro.m" file. If you are new to MATLAB you may want to read "IN3015_IN4015_MATLAB_intro.pdf".

## Additional USTB exercise:
NB! You don't need add anything to the report from this exercise.

You are going to use the USTB quite alot in this course. Below are a few relevant USTB examples you should work thorugh. You should also install the simulation tools Field II and kWave that 
is used quite a lot together with the USTB. The kWave toolbox will for example be used in the exercise for module 2.

+ Get to know the UltraSound ToolBox by running and getting familiar with multiple examples 
	+ Pure USTB examples. Run at least five of these
		+ examples/uff/CPWC_UFF_Alpinion.m
		+ examples/uff/CPWC_UFF_Verasonics.m
		+ examples/uff/FI_UFF_phased_array.m
		+ examples/picmus/experimental_contrast_speckle.m
		+ examples/picmus/experimental_resolution_distortion.m
		+ examples/picmus/carotid_cross.m
		+ examples/picmus/carotid_long.m
		+ examples/acoustical_radiation_force_imaging/ARFI_UFF_Verasonics.m
        + examples/UiO_course_IN4015_Ultrasound_Imaging/module_1_intro_to_USTB/minimal_example.m
        + examples/UiO_course_IN4015_Ultrasound_Imaging/module_1_intro_to_USTB/maximal_example.m
	+ USTB + K-wave examples. You need to install and add the ultrasound simulator k-wave (http://www.k-wave.org/) to your MATLAB path. See simple description below.
		+ examples/kWave/CPWC_linear_array_cyst.m
	+ USTB + Field II examples. You need to install and add ultrasound simulator Field II (https://field-ii.dk/) to your MATLAB path. See simple description below.
		+ examples/field_II/STAI_L11_resolution_phantom.m
		
## How to download k-wave and Field II

### K-wave

Register a new profile (http://www.k-wave.org/forum/register.php) with the necessary information, go to download, and download the k-wave zip-file.
Next, extract the folder on your preferred spot, and add to path (see below).

### Field II

Go to the download site at (https://field-ii.dk/), and download the file for your operating system. Extract the folder (twice) at your preferred location.
Next, add to path (see below).

## How to add to path

There are multiple ways to add to path:

1. Create a new file called "startup.m" in your working directory, and add the path in this file by writing
    + addpath *filepath, i.e. Documents/MATLAB/k-wave*
2. Pathtool: open pathtool in Matlab by writing pathtool in the Command Window in Matlab. Click "Add Folder" to add k-wave and field-ii to path, and press save. To use this method, you have to have Admin rights on the computer you are using.
3. Use the command "addpath()" and possibly "genpath()" in the MATLAB command window.