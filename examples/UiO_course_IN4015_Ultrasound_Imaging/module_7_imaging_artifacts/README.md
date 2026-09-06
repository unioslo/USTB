# Module 7 - Imaging Artifacts
This exercise is to explore the effects of using the wrong sound speed
in the reconstruction. As we learned in the lecture, the sound speed in
the body varies quite a lot, from e.g. 1460 in fat to 1600 in muscles. In this
exercise we will experiment with the sound speed in the reconstruction of
a single PW image and see how this affects the reconstructed image. 

## Literature:
See lecture slides.

## Delivery:
Please provide a written report that

- reports the results you are asked to find
- answers the questions raised
- provides the main code lines needed to solve the questions directly in the report
- includes all plots needed for supporting your arguments when answering the exercise parts and displaying your results.

The report should be uploaded to [devilry.ifi.uio.no](https://devilry.ifi.uio.no).  
**Deadline for uploading: Tuesday 24. November 2026 at 10:00.**

## Datasets
You have one available dataset you can use for this exercise:

+ L7_CPWC_TheGB.uff 

This is a plane wave dataset consisting of 11 individual plane wave transmissions, but we will
actually just use the center transmitted PW.

If you have any trouble downloading the data using the built-in download tool you 
can download the data directly from the USTB website:

+ https://www.ustb.no/datasets/L7_CPWC_TheGB.uff

## The exercise:
### Part I
Try to beamform the image with at least three different sound speeds
including 1460 m/s (fat), 1540 m/s (typical mean) and 1600 m/s (muscle). 
How does this affect the final image? How does it affect the resolution of the
point scatterer? How does it affect the size of the cyst? Notice that the point scatterer
"moves" with different sound speeds so you have to change what line to plot in the figure 
further down in the code.

### Part II
During the reconstruction process with varying sound speeds, you may have noticed that objects within the 
image shift and alter in size. To accurately evaluate the lowest point scatterer, you likely had to manually
adjust the depth index under consideration. Nevertheless, for applications such as machine learning, it is 
crucial that reconstructed objects remain stationary across images with different sound speeds, enabling a 
direct "pixel-by-pixel" comparison. How can the z_axis of the reconstructed scan be adjusted so that it appropriately 
scales with sound speed? Hint: One possible approach could be to use the wavelength as a unit, which you can find at
channel_data.lambda or calculate independently. Explain the reasoning behind why this method would be effective.
       
### Part III
Based on the two previous exercises - which sound speed was correct when
reconstructing this dataset? Perhaps you can suggest a criterion 
to evaluate the sound speed in the reconstruction?