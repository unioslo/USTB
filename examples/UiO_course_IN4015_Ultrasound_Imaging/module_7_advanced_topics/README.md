# Module 7 : Advanced Methods in Ultrasound Imaging

In this exercise you will explore more advanced beamforming, known
as adaptive beamforming since we are adapting the beamforming process
to the data we have received. More specifically, we will investigate the coherence factor.

## Litterature:
Section 1.8, 1.9 and 1.11 in the compendium, and specifically equation 1.38  for the coherence factor.

## Delivery: 
Please provide a written report that

- report the results you are asked to find
- answers the question raised
- provides the main code lines needed to solve the questions directly in the report
- all plots needed for supporting your arguments when answering the exercise parts and displaying your results.

The report should be uploaded to [devilry.ifi.uio.no](devilry.ifi.uio.no).  
**Deadline for uploading: Tuesday 23. November at 12:00. **

## Datasets
You will use the simulated Synthetic Transmit Aperture Imaging (STAI) dataset
from the publication 
    Rindal, O. M. H., Austeng, A., Fatemi, A., & Rodriguez-Molares, A. (2019).
    The Effect of Dynamic Range Alterations in the Estimation of Contrast. 
    IEEE Transactions on Ultrasonics, Ferroelectrics, and Frequency Control, 
    66(7), 1198–1208. https://doi.org/10.1109/TUFFC.2019.2911267

The dataset might fail to download, if so delete it from the folder data,
and download it from this Google drive link:
https://drive.google.com/file/d/1xAXoEWhPcYjam9R1iuQ0gWKdDXiVlPCX/view?usp=sharing


## The exercise:
### Part I
    Calculate the coherence factor as in equation 1.38 in the compendium.

### Part II
    Check your implementation agains the USTB implementation.

### Part III
    Analyse the delayed data:
    + Describe how the plotted delayed data will affect the coherence factor?
    + What is the image you plot of the coherent sum equal to?

### Part IV
    Applying the CF as a image weight to the DAS image

### Part V
    Compare DAS CF to DAS image:
    + What are the differences between the results of the conventional DAS to the image with DAS weighted with CF?
    + What happened to the object from x = 0 to x = 2.5 mm at z = 30 mm in the two plots?
    + In the plot below we also plot the mean lateral line through the gradient
        from x = +-14mm at z = 40 to 48 mm. Theoretically, this should go from 0
        to -50 dB, which one is most correct?


### Part VI
    Calculate the contrast ratio for DAS and CF and discuss these results in
    relation to the response to the gradient in V.
