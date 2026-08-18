# UltraSound ToolBox (USTB) #

An open source MATLAB toolbox for beamforming, processing, and visualization of ultrasonic signals. The USTB is developed as a joint effort of:
 
* [Department of Circulation and Medical Imaging of NTNU](https://www.ntnu.no/isb), 
* [Department of Informatics of the University of Oslo](http://www.uio.no/), and
* [CREATIS Laboratory of the University of Lyon](https://www.creatis.insa-lyon.fr/site7/en).

### Repository mirrors ###

The USTB source is available from **both** of these official locations; use whichever host you prefer for cloning or forking:

* **GitHub:** [github.com/unioslo/USTB](https://github.com/unioslo/USTB)
* **Bitbucket:** [bitbucket.org/ustb/ustb](https://bitbucket.org/ustb/ustb)

### How do I get set up? ###

* Just clone the repository and add the folder (without subfolders) to MATLAB's path

### Citationware ###

The USTB is made possible through the contribution of several labs around the world. It contains pieces of intellectual property from many authors, and because of that different references must be cited depending on your use of USTB. There are three kinds of intellectual properties that must be acknowledged: datasets, processes, and the toolbox itself. Please se our website http://www.ustb.no/citation/ for details on how to properly refence the intellectual property. Be sure to reference our proceedings paper from IUS (IEEE International Ultrasonics Symposium) 2017 whenever you are using the toolbox in research or other publications:

* Rodriguez-Molares, A., Rindal, O. M. H., Bernard, O., Nair, A., Bell, M. A. L., Liebgott, H., Austeng, A., Løvstakken, L. (2017). *The UltraSound ToolBox.* IEEE International Ultrasonics Symposium, IUS, 1–4. https://doi.org/10.1109/ULTSYM.2017.8092389

Machine-readable citation metadata: [`CITATION.cff`](CITATION.cff) (GitHub citation / CFF) and [`citation.bib`](citation.bib) (BibTeX) at the repository root. The code is released under the [MIT License](LICENSE); citation expectations for research are separate from that license (see the website citation page).

### Current version ###

The USTB is actively developed, so there might be structural changes between releases. The current version in `master` is:

* v2.3: https://github.com/unioslo/USTB/releases/tag/v2.3.3

compared to the previous version:

* v2.2: https://github.com/unioslo/USTB/releases/tag/v2.2.4

the main changes are:

* A new implementation of the sector scan allowing to compensate for blocked arrays
* Improve the speed of the beamformer
* A CUDA implementation of the generalized beamformer
* corrected implementation of Unified Delay Model for RTB/MLA processing
* major update of the FLUST simulator
* corrected issue with diverging wave delay calculation
* corrected data location for unit tests
* added examples and exercises used in the course IN3015/4015 Ultrasound Imaging at the University of Oslo.
* several bugfixes and other improvements have been done as well.
* more tests have been added

### Using a MAC? ###
If you are using a Mac and are getting an error running the das_c.mexmaca64 file be sure to install the oneTBB parallelization library.
oneTBB (formerly Intel TBB) can be installed with Homebrew using the command "brew install tbb".

### Documentation ###
Unfortunately, we have not had the time or resources to write a full documentation of the USTB. However, there are plenty of well documented examples that will help you to get started and hopefully understand the code. You find the examples under the /examples folder. 

### How to contribute? ###
Contributions to USTB are welcome! We follow a standard GitHub pull request workflow where all changes are merged directly into the primary `master` branch after automated testing and review.

To contribute code to the project:

* **Step 1:** Create your own fork of the project repository ([github.com/unioslo/USTB](https://github.com/unioslo/USTB)).
* **Step 2:** Create a feature or bugfix branch from your fork's `master` branch.
* **Step 3:** Create a Pull Request (PR) from your branch back to the official repository's `master` branch.
* **Step 4:** Once automated tests pass and the review is approved, your PR will be merged into `master` and you have successfully contributed!

### Did you find a bug or have suggestions? ###
Please use the GitHub issue tracker to report bugs and make suggestions: [github.com/unioslo/USTB/issues](https://github.com/unioslo/USTB/issues). All feedback is much appreciated. Don’t hesitate to contact us if you have any problems.

### Who do I talk to? ###

The project administrators are:

* Ole Marius Hoel Rindal <omrindal@ifi.uio.no>,
* Stefano Fiorentini <stefano.fiorentini@ntnu.no>,
* Alfonso Rodriguez-Molares <alfonso.r.molares@ntnu.no>
* Anders Emil Vrålstad <anders.e.vralstad@ntnu.no>

Collaborators:

* Håvard Kjellmo Arnestad
* Magnus Dalen Kvalevåg
* Olivier Bernard
* Andreas Austeng 
* Arun Nair
* Muyinatu A. Lediju Bell, 
* Lasse Løvstakken 
* Svein Bøe 
* Hervé Liebgott 
* Øyvind Krøvel-Velle Standal 
* Jochen Rau 
