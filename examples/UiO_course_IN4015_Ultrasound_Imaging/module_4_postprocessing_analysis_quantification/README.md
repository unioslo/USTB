# Module 4 - Postprocessing analysis quantification
This example and exercise demonstrates what we in the USTB define as
postprocessing processing objects. Thus, how one can work with the
delayed data after beamforming. More specificly we are going to look at
coherent and incoherent compounding of individual plane wave images.
When you do plane wave imaging you can create one low quality image
from each transmit. These low quality images can be combined together
to create images of higher quality. We will explore this in this
exercise.

## Litterature:
See section 1.4, 1.7, 1.9 – 1.11. in the compendium "Software Beamforming
 in Medical Ultrasound Imaging". As well as the lecture slides.

## Delivery:
Please provide a written report that

- report the results you are asked to find
- answers the question raised
- provides the main code lines needed to solve the questions directly in the report
- all plots needed for supporting your arguments when answering the exercise parts and displaying your results.

The report should be uploaded to [devilry.ifi.uio.no](devilry.ifi.uio.no).  
**Deadline for uploading: Wednesday 25. October at 10:00. **

## Datasets
You have two available datasets you can use for this exercise

+ PICMUS_experiment_resolution_distortion.uff 
+ PICMUS_simulation_contrast_speckle.uff

Both are plane wave datasets consiting of 75 individual plane wave transmission.
You can implement the coherent, incoherence and mix coherence using any of these
dataset, but to evaluate the resolution in part IV you should use the resolution
dataset, and to evaluate the contrast in part V you should use the contrast dataset.

If you have any trouble downloading the data using the built in download tool you 
can download the data directly from the USTB website:

+ https://www.ustb.no/datasets/PICMUS_experiment_resolution_distortion.uff
+ https://www.ustb.no/datasets/PICMUS_simulation_contrast_speckle.uff

## The exercise:
### Part I
Implement both coherent compounding and incoherent
compounding of the individual plane wave images. You can read about
coherent and incoherent compounding in section 1.7.3 and 1.7.4 in
the compendium "Software Beamforming in Medical Ultrasound Imaging"
Note: the weight w is 1 in both cases here.

### Part II
Comparing your implementation to the USTB implementation.
       
### Part III
Implement a mix of coherent and incoherent compounding.
We can also do something inbetween full coherent and incoherent
compounding. We can for example split the low quality images into two parts,
and sum the different halfs coherently, before summing those two images
incoherently. If you for example split the transmit angles into two.
And then sum the plane wave images resulting from the first half of the transmits
coherently but separately, and then the transmits from the second half of the transmits
coherently but separately. These two results can then be combined incoherently. 
Thus you have done mix compounding. You can put the results in the mix_compounding variable-

### Part IV
Compare the resoluting resolution from coherent, incoherent and mixed compounding.
Discuss how the different compounding strategies influenced the resolution
of the point scatter. Often resolution is measured as the Full Width Half Maximum (FWHM)
equal to the width at -6 dB. Improved resolution means smaller width of the point scatter. 
Discuss how the different compounding strategies influenced the resolution of this point scatter.

### Part V 
Measure the contrast of the resulting images using the contrast ratio (CR)
and the contrast-to-noise ratio (CNR). You should measure the contrast of the
single plane wave image and the three different compounding techniques and discuss the results.
The implementation to measure the CR is allready provided, but you have to calculate the CNR.
