# UltraSound ToolBox (USTB) #

An open source MATLAB toolbox for beamforming, processing, and visualization of ultrasonic signals. The USTB is developed as a joint effort of:
 
* [Department of Circulation and Medical Imaging of NTNU](https://www.ntnu.no/isb), 
* [Department of Informatics of the University of Oslo](http://www.uio.no/), and
* [CREATIS Laboratory of the University of Lyon](https://www.creatis.insa-lyon.fr/site7/en).

### How do I get set up? ###

* Just clone the repository and add the folder (without subfolders) to MATLAB's path

### Citationware ###

The USTB is made possible through the contribution of several labs around the world. It contains pieces of intellectual property from many authors, and because of that different references must be cited depending on your use of USTB. There are three kinds of intellectual properties that must be acknowledged: datasets, processes, and the toolbox itself. Please se our website http://www.ustb.no/citation/ for details on how to properly refence the intellectual property. Be sure to reference our proceedings paper from IUS (IEEE International Ultrasonics Symposium) 2017 whenever you are using the toolbox in research or other publications:

* Rodriguez-Molares, A., Rindal, O. M. H., Bernard, O., Nair, A., Bell, M. A. L., Liebgott, H., Austeng, A., Løvstakken, L. (2017). *The UltraSound ToolBox.* IEEE International Ultrasonics Symposium, IUS, 1–4. https://doi.org/10.1109/ULTSYM.2017.8092389

### Current version ###

The USTB is still under development, so there might be larger structural changes. The current version in main is;

* v2.3: https://bitbucket.org/ustb/ustb/commits/tag/v2.3.3

compared to the previous version

* v2.2: https://bitbucket.org/ustb/ustb/commits/tag/v2.2.4

the main changes are:

* corrected implementation of Unified Delay Model for RTB/MLA processing
* major update of the FLUST simulator
* corrected issue with divering wave delay calculation
* corrected data location for unit tests
* added examples and exercises used in the course IN3015/4015 Ultrasound Imaging at the University of Oslo.
* several bugfixes and other improvements have been done as well.
* more tests have been added


### Documentation ###
Unfortunately, we have not had the time or resources to write a full documentation of the USTB. However, there are plenty of well documented examples that will help you to get started and hopefully understand the code. You find the examples under the /examples folder. 

### How to contribute? ###
First of all, please make yourself familiar with the Gitflow workflow. See for example this tutorial: https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow. According to the Gitflow workflow there are two types of contributions to the code a, __hotifx__ and a __feature__:

* __hotfix__: This is a change done on the main branch. Typically, an urgent bugfix often related to a reported issue: https://bitbucket.org/ustb/ustb/issues?status=new&status=open
* __feature__: This is a change done on the develop branch. Typically, a larger change to the code or added or improved functionality. 

To contribute to the project with your code you should do the following:

* Step 1: Create your own fork of the project. 
* Step 2: Create a hotfix branch from the main branch to fix an urgent bug, or a feature branch from the develop branch to add a feature.
* Step 3: Create a pull request from your forked repository back to our repository and add @omrindal and @alfonsomolares as reviewers. 
* Step 4: Once we have time to review your code and are happy with the changes we will merge your pull request into the USTB and you have sucessfully contributed!

Once we are happy and comfortable that the develop branch is stable and useful we will merge it into main and a new version will be released :D

### Did you find a bug or have suggestions? ###
Please use the issue tracker to report bugs and make suggestions: https://bitbucket.org/ustb/ustb/issues?status=new&status=open. All feedback is much appreciated. Don’t hesitate to contact us if you have any problems.

### Who do I talk to? ###

The project administrators are:

* Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>,
* Ole Marius Hoel Rindal <omrindal@ifi.uio.no>,
* Stefano Fiorentini <stefano.fiorentini@ntnu.no>.
 

Collaborators:

* Olivier Bernard
* Andreas Austeng 
* Arun Nair
* Muyinatu A. Lediju Bell, 
* Lasse Løvstakken 
* Svein Bøe 
* Hervé Liebgott 
* Øyvind Krøvel-Velle Standal 
* Jochen Rau 
* Stefano Fiorentini
