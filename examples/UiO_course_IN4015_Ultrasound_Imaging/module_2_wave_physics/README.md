# Module 2 : Wave Physics

This module contains two exercises. The first  concerns transmit beams from 
continuous apertures. The aim is to understand how the beamwidth and 
depth-of-focus varies with aperture size, frequency, and focal point.  

This second exercise demonstrates how to run a simulation in k-wave to record a
signal originating from a single source. We then show how this recorded signal
can be written to a UFF channel data object in the USTB and beamformed into an image. 
Thus, we will do "receive beamforming" and reconstruct an image of the single source.
Your task is to implement your own pixel-based receive beamformer and verify that
your results are similar to the results from the USTB.

## Litterature:
The first example is covered in this weeks lecture and reading material.  

Background for the second exercise you can find at pages 1 and 2 of Jørgen 
Grythe's document "Beamforming Algorithms - beamformers" or pages 22-29 in 
the compendium by Rindal. However, remember that here you only need to do 
receive beamforming. 

## Delivery:
Please provide a written report that

- report the results you are asked to find
- answers the question raised
- provides the main code lines needed to solve the questions directly in the report
- all plots needed for supporting your arguments when answering the exercise parts

The report should be uploaded to [devilry.ifi.uio.no](devilry.ifi.uio.no).  
**Deadline for uploading: Wednesday 27. September at 10:00. **
 
## Exercise One:
The m-code that needs modification is *exercise_1_soundFieldFromLinearTransducer.m*.  
You also need the supporting m-code *rk_wave_lib.m*.  
When running *exercise_1_soundFieldFromLinearTransducer.m*, a couple of figures and a 
video (that is overwritten each time) is produced.

### Part I
Using the provided m-code, simulate the wave field using 31 element points,
speed-of-sound c = 1500 m/s, center frequency f0 = 2.5e6 Hz, 20 cycles in the 
excitation puls, and focal radius in the far-field (f.ex 10000e3 m).  

The provided plot of the wave field do also indicate the local -3 and -6 dB contour
(plottet with solid lines). In addition, with dashed lines, the (global) -3 and -6 dB contour 
calculated relative to the maximum pressure is potted

 - Using the solid lines, estimate the beamwidth (in either degrees, radians, or millimeters) at depths 10, 25, and 40 mm. Compare the 
 measured numbers with the 6 dB lateral resolution formulas given in Rindal's compendium, Eq.(1.8) and/or (1.9). 

 - When is the above calculation valid? Where is the farfield? Use the equation on bottom of p.4 (R = D^2 / (k*lambda)).

 NOTE: to "estimate" here means to use the generated plots to find the requested values.

 HINT: Use the MATLAB function ginput to estimate the width. Consider reporting your numerical results in a table along with Part II and Part III.

### Part II

- Reduce the center frequency by a factor two (to f0 = 1.25e6 Hz) and repeat the 
measurements and calculations done in Part I.  
- How does your findings fit your understanding (beamwidth and nearfield/farfield)?

### Part III

- Still using f0 = 1.25e6 Hz, increase the sensor size to 61 points and redo 
measurements and calculations.  
- How does your new findings fit your understanding?

### Part IV
Chose f0 = 2.5e6 Hz and sensor size 31 points. Adjust focal range to 5 mm. 
Again, the solid lines indicates the local -3 and -6 dB contour, but now the dashed lines 
can be used to estimate the depth-of-field.

- Using the solid lines, estimate the beamwidth at 5, 10 and 15 mm.
- Using the dashed lines, estimate the depth-of-field.


### Part V
Again, chose f0 = 2.5e6 Hz and sensor size 31 points. Adjust focal range to 15 mm. 

- Using the solid lines, estimate the beamwidth at 5, 10 and 15 mm.
- Using the dashed lines, estimate the depth-of-field.

### Part VI
Compare the beamwidths from Part IV, V. What is the effect and consequence of 
changing the focal range. Compare the measured numbers with theoretical results obtained from:
- Eq. (1.9) in Rindal's compendium.
- Eq. (9.22) in Cox and Treeby.
- Comment on the difference between the prefactor 9.7 in Eq.(9.22) vs 7.1 in Eq.(4) in Hendrix and Hykes - does it matter which one we use?

### Part VII
You want to make a sector image ranging from -30 to 30 degrees, imaging ranges from 20 to 
100 mm. To do this, you need to transmit several beams at different angles, illuminating the 
whole sector. Neighboring beams should overlap at least at -3 dB beam levels. 
(In practice, a denser sampling is often used to avoid "scalloping loss".)  

To simplify a bit, choose focal range at 50 mm. Using 51 element points, f0 = 2.5e6 Hz, 5 cycle long pulse and the -3 dB criterion specified above, 
how many beams are needed to illuminate the whole sector? 
Assuming no delays between beams or images, what is the corresponding frame rate (images per second)?

Hint: You can find the -3 dB width from simulation in k-wave.

## Exercise Two:
The m-code that needs modification is *exercise_2_main_kwave_single_source_example.m*.  
You also need the supporting m-code *run_kwave_simulation.m*.

An important part of this exercise is to try to understand what is going on in the code you are running.
A hot tip for running this code is to run it per "block". You can run the higlighted block
using "ctrl+enter".

### Part I
Implement your own receive pixel-based beamformer. Your assignment is to 
implement a receive beamformer. However, most of the code is allready written,
so you simply have to get the receive delay correct (thus update the line
that says <------ UPDATE THIS LINE) under #Part I# in the code.
Your image should be similar to the one resulting from the USTB. 
See the reference to the litterature above. 

### Part II

+ Change from 4 elements to 16 elements where you find <------- CHANGE NUMBER OF ELEMENTS HERE 
towards the top of the script. How does this change the beamformed image?
+ What happens when you change the transmit signal from *gausian_pulse* (high bandwidth) to *sinus* (low bandwidth)? 
How did this influence the beamformed image?

### Part III
Visualize the channel data before and after delay for the single source.
First of all, this plot is much better if you use e.g. 16 elements use the 
*gausian_pulse* as the signal transmitted so make sure you use this on line 12 and 15. 

Your task is to use the plot in Figure 9 to find the location of the source.
Use the cursor in the plot and find the maximum, and simply set the correct
value in the variables where you see "<------- UPDATE THIS LINE" for the x and z
location of the source.

Discuss and interpret the resulting plots in figure 11.

### Part IV

Discuss and answer the following questions:

+ What is illustrated in Figure 13? Explain the images and how they differ from the final image.
+ What is illustrated in Figure 14? Explain the images.
