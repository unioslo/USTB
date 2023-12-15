# Module 3 : US Processing Chain

The assignment for **Module 3** is to implement your own beamforming from
scratch. In Module 2, we used pixel based beamforming, but only did recieve 
beamforming. In this module, we are taking both the receive delay and the transmit
part of the total propagation delay into account, using beambased beamforming. 
This means that we are now using the transmit angles and distance to find the positions, 
rather than the predefined pixels as we did in Module 2.

You will implement the full beamforming and reconstruction of ultrasound images
from a phased array, and compare your implementation with the beamforming in the USTB. 

## Litterature
The relevant litterature for this assignment is the lecture slide. Especially the
slides on beambased beamforming. However, the compendium: “Software Beamforming
in Medical Ultrasound Imaging”, is relevant. Especially section 1.5 to 1.7 as 
well as 1.9. However, the other sections prior to 1.5 is also very relevant.
But remember that you are implementing a beambased beamformer, while the compendium
describes the pixel based beamformer in the USTB.

## Delivery:
Please provide a written report that

- report the results you are asked to find
- answers the question raised
- provides the main code lines needed to solve the questions directly in the report
- all plots needed for supporting your arguments when answering the exercise parts

The report should be uploaded to [devilry.ifi.uio.no](devilry.ifi.uio.no).  
**Deadline for uploading: Wednesday 11. October at 10:00. **

## Datasets
You have two available datasets you can use for this exercise

+ Verasonics_P2-4_parasternal_long_small.uff which is a in-vivo cardiac dataset
+ FieldII_P4_point_scatterers.uff which is a simulated dataset of point scatters

It is perhaps easiest to get your code running correctly using the dataset
with the point scatterers. However, you should also try to use the cardiac dataset.

+ You will also have the option to record your own dataset on the Verasonics scanner
in the lab. More information regarding this will be given in the lecture and the group lecture

The two datasets can be downloaded directly from (if you have issues with the automatic download in the USTB):

+ https://www.ustb.no/datasets/FieldII_P4_point_scatterers.uff
+ https://www.ustb.no/datasets/Verasonics_P2-4_parasternal_long_small.uff

## The exercise:
### Part I : Do phased array beamforming with the USTB

Here you dont't have to implement anything. Just run the code as it is.
You will later compare your beamformed image with the image resulting
from this beamforming. Just try to understand what is going on.

### Part II : Implement your own beambased beamforming from scratch.

Please see the slides on beambased beamforming, and especially the slide
on the geometry og beambased beamforming on tips on how to implement this.

A hint is to review the exercise from module 2 on wave physics where you
implemented a receive beamformer. Now you are extending the beamforming to also
include to compensate for the transmit part of the propagation delay as
well as handling multiple transmits.

Pseudocode for the beambased phased array beamformer you will implement


    for each transmit
        calculate the transmit part and the receive part of the delay for
        every receive channel. Remember to calculate the delays in seconds
        not distance, and remember to subtract the offset for each transmit
        event to get a correct time zero convention.

        for each receive channel
            use your calculated delays to timedelay the channeldata by
            interpolating (using interp1) for each dept sample for each transmit
            the call to interp1 might look like this:
            interp1(sample_time, rfData(:,r,t)', delays(t,:,r))'
                where r is the current receive channel and t is the current transmit
                you allready have sample_time and rfData, and need to calculate the delays
                as described in the first loop.

The resulting beamformed image should be stored in the variable img, and the rest
of the code will compare it to the implementation in the USTB. When they are similar
you are done with the exercise. We only show differences larger than -100 dB. 
Differences smaller than -90 dB can be ignored, since they most likely originate from  numerical
differences resulting from minor differences in implementation.

### Part III :  Inspecting receive apodization 
In this exercise you will inspect how the receive apodization influences the image.  You should change the receive
beamforming window to a Hamming window, and set the f# to 2 by commenting out and filling
out the lines marked with "<--- UNCOMMENT AND FILL OUT THIS LINE".

In the report, answer the following questions:
What happened to the images when you changed the receive apodization? 
Is it easiest to see the changes in the cardiac dataset or the dataset
with point scatterers?