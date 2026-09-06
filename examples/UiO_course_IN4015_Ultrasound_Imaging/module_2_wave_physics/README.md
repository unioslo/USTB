# Module 2 : Wave Physics

This module contains two exercises. The first concerns basic assignments
related to various properties of waves such as sound speed and frequency. The aim is to 
get some hands-on experience calculating and applying these fundamental variables. 

This second exercise demonstrates how to run a simulation in k-wave to record a
signal originating from a single source. We then show how this recorded signal
can be written to a UFF channel data object in the USTB and beamformed into an image. 
Thus, we will do "receive beamforming" and reconstruct an image of the single source.
Your task is to implement your own pixel-based receive beamformer and verify that
your results are similar to the results from the USTB.

## Literature:
The first example is covered in this week's lecture and reading material.  

Background for the second exercise you can find at pages 1 and 2 of Jørgen 
Grythe's document "Beamforming Algorithms - beamformers" or pages 22-29 in 
the compendium by Rindal. However, remember that here you only need to do 
receive beamforming. 

## Delivery:
Please provide a written report that

- reports the results you are asked to find
- answers the questions raised
- provides the main code lines needed to solve the questions directly in the report
- includes all plots needed for supporting your arguments when answering the exercise parts

The report should be uploaded to [devilry.ifi.uio.no](https://devilry.ifi.uio.no).  
**Deadline for uploading: Tuesday 15. September 2026 at 10:00.**
 
## Exercise One:
Please follow and answer the questions in *exercise_1_assignment_basic_sound_speed_and_waves.m* and write all your answers in the report

## Exercise Two:
The m-code that needs modification is *exercise_2_main_kwave_single_source_example.m*.  
You also need the supporting m-code *run_kwave_simulation.m*.

An important part of this exercise is to try to understand what is going on in the code you are running.
A hot tip for running this code is to run it per "block". You can run the highlighted block
using "ctrl+enter".

### Part I
Implement your own receive pixel-based beamformer. Your assignment is to 
implement a receive beamformer. However, most of the code is already written,
so you simply have to get the receive delay correct (thus update the line
that says <------ UPDATE THIS LINE) under #Part I# in the code.
Your image should be similar to the one resulting from the USTB. 
See the reference to the literature above. 

### Part II

+ Change from 4 elements to 16 elements where you find <------- CHANGE NUMBER OF ELEMENTS HERE 
towards the top of the script. How does this change the beamformed image?
+ What happens when you change the transmit signal from *gaussian_pulse* (high bandwidth) to *sinus* (low bandwidth)? 
How did this influence the beamformed image?

### Part III
Visualize the channel data before and after delay for the single source.
First of all, this plot is much better if you use e.g. 16 elements and use the 
*gaussian_pulse* as the signal transmitted so make sure you use this on line 12 and 15. 

Your task is to use the plot in Figure 9 to find the location of the source.
Use the cursor in the plot and find the maximum, and simply set the correct
value in the variables where you see "<------- UPDATE THIS LINE" for the x and z
location of the source.

Discuss and interpret the resulting plots in figure 11.

### Part IV

Discuss and answer the following questions:

+ What is illustrated in Figure 13? Explain the images and how they differ from the final image.
+ What is illustrated in Figure 14? Explain the images.
