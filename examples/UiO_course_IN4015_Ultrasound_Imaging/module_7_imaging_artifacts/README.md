# Module 7 - Imaging Artifacts
This exercise is to explore the effects of using the wrong sound speed
in the reconstruction. As we learned in the lecture, the sound speed in
the body varies quite a lot, from e.g. 1460 in fat to 1600 in muscles. In this
exercise we will experiment with the sound speed in the reconstruction of
a single PW image and see how this affects the reconstructed image. 

## Litterature:
See lecture slides.

## Delivery:
Please provide a written report that

- report the results you are asked to find
- answers the question raised
- provides the main code lines needed to solve the questions directly in the report
- all plots needed for supporting your arguments when answering the exercise parts and displaying your results.

The report should be uploaded to [devilry.ifi.uio.no](devilry.ifi.uio.no).  
**Deadline for uploading: Wednesday 6. October at 10:00. **

## Datasets
You have one available datasets you can use for this exercise

+ L7_CPWC_TheGB.uff 

This is a plane wave datasets consiting of 11 individual plane wave transmission, but we will
actually just use the center transmitted PW.

If you have any trouble downloading the data using the built in download tool you 
can download the data directly from the USTB website:

+ https://www.ustb.no/datasets/L7_CPWC_TheGB.uff

## The exercise:
### Part I
Try to beamform the image with at least three different sound speeds
including 1460 m/s (fat), 1540 m/s (typical mean) and 1600 m/s (muscle). 
How does this affect the final image? How does it affect the resolution of the
point scatter? How does it affect the size of the cyst? Notice that the point scatter
"moves" with different sound speeds so you have to change what line to plot in the figure 
further down in the code.

### Part II
As you have probably experienced now, when you reconstruct an image with
different sound speed, the objects in the image move and change sizes. To
evaluate the lowest point scatter you had to manually change what depth
index to investigate. However, to be able to use for example machine
learning to evaluate sound speed we need the reconstructed objects to be
at the same pixel in images with different reconstructed sound speeds so 
that one can compare two images with different sound speeds "pixel by
pixel". How can you set the z_axis of the reconstructed scan so that it
scales with the sound speed? 
Hint: Perhaps you can use the wavelength as a unit? It is found at
channel_data.lambda or you can calculate it on your own.
Explain why this works.
       
### Part III
Based on the two previous exercises - which sound speed was correct when
reconstruction this dataset? Perhaps you can suggest a criteria 
to evaluate the sound speed in the reconstruction?