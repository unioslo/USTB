.. default-domain:: py

USTB for Python
===============

``ustb`` is a Python implementation of the UltraSound ToolBox. It mirrors the
MATLAB API (same class names, properties and ``go()`` pattern) and reads and
writes UFF files through `pyuff-ustb <https://pypi.org/project/pyuff-ustb/>`_.

Installation
------------

.. code-block:: bash

   pip install ustb

Python 3.10 or later is required. The beamformer is compiled with
`numba <https://numba.pydata.org/>`_, which is installed as a dependency.

Quick start
-----------

.. code-block:: python

   import numpy as np
   from pyuff_ustb.objects.uff import Uff
   from ustb.midprocess import DAS
   from ustb.enums import Dimension, Window

   uff_file = Uff("PICMUS_experiment_resolution_distortion.uff")
   channel_data = uff_file.read("channel_data")
   scan = uff_file.read("scan")

   mid = DAS()
   mid.channel_data = channel_data
   mid.scan = scan
   mid.dimension = Dimension.both
   mid.receive_apodization.window = Window.tukey50
   mid.receive_apodization.f_number = np.array([1.7, 1.7])
   mid.transmit_apodization.window = Window.tukey50
   mid.transmit_apodization.f_number = np.array([1.7, 1.7])
   b_data = mid.go()

   b_data.plot(title="PICMUS experiment resolution")

The datasets used in the examples are on Zenodo; see
``ustb.tools.download`` and the examples in ``python/examples`` in the
repository.

What is implemented
-------------------

Every process below is checked against MATLAB in the test suite, pixel by
pixel, on the same input (except SLSC, see :doc:`matlab_to_python`).

=====================  ==================================================================
Stage                  Classes
=====================  ==================================================================
Preprocess             ``FastDemodulation``, ``Demodulation``, ``SVDFilter``
Midprocess             ``DAS`` (generalized delay-and-sum)
Postprocess            ``CoherentCompounding``, ``IncoherentCompounding``,
                       ``CoherenceFactor``, ``GeneralizedCoherenceFactor``,
                       ``PhaseCoherenceFactor``, ``CaponMinimumVariance``,
                       ``DelayMultiplyAndSum``, ``ShortLagSpatialCoherence``,
                       ``SVDFilter``, ``AutocorrelationDisplacementEstimation``,
                       ``ModifiedAutocorrelationDisplacementEstimation``, ``Median``
Apodization            ``Apodization``: all windows, receive, transmit (plane and
                       diverging waves) and scanline (MLA)
Tools                  ``download``, ``power_spectrum``, ``estimate_frequency``,
                       ``scan_convert``, ``uniform_fov_weighting``
=====================  ==================================================================

Not yet available in Python: Fourier beamforming, the ULM pipeline, the
remaining postprocesses (e.g. EBMV, NLM, gray-level transforms, Wiener) and
GPU beamforming.

How it is tested against MATLAB
-------------------------------

MATLAB scripts in ``python/tests`` (``generate_*.m``) write reference
outputs. The tests pair MATLAB and Python pixels by position (the two order
scan pixels differently) and compare them pixel by pixel. Small references
are committed in ``python/tests/ci_reference`` and run in CI; the full
references are generated locally.

.. toctree::
   :maxdepth: 2

   matlab_to_python
   api
