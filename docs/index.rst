USTB Documentation
===================

The UltraSound ToolBox (USTB) is an open-source MATLAB toolbox for processing
ultrasonic signals. It covers the whole processing pipeline from raw channel data
to displayed image, including conventional and adaptive beamforming algorithms.

The USTB contains **data classes** and **processing classes**. All data classes,
such as ``channel_data``, ``beamformed_data``, ``scan``, and ``probe`` can be
written to UFF files, while there are three main types of processing classes:
``preprocess``, ``midprocess``, and ``postprocess``.

.. toctree::
   :maxdepth: 2
   :caption: Data Classes

   api/uff

.. toctree::
   :maxdepth: 2
   :caption: Processing Classes

   api/preprocess
   api/midprocess
   api/postprocess

.. toctree::
   :maxdepth: 2
   :caption: Utilities and Core

   api/tools
   api/core

Examples
--------

Browse the full collection of published USTB examples organized by category:

`Examples Gallery <examples/index.html>`_
