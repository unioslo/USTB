.. default-domain:: py

Python API
==========

Preprocess
----------

| **Input:** channel data |rarr| **Output:** channel data

.. autoclass:: ustb.preprocess.FastDemodulation
   :members: go

.. autoclass:: ustb.preprocess.Demodulation
   :members: go

.. autoclass:: ustb.preprocess.SVDFilter
   :members: go

Midprocess
----------

| **Input:** channel data |rarr| **Output:** beamformed data

.. autoclass:: ustb.midprocess.DAS
   :members: go

Postprocess
-----------

| **Input:** beamformed data |rarr| **Output:** beamformed data

Compounding
^^^^^^^^^^^

.. autoclass:: ustb.postprocess.CoherentCompounding
   :members: go

.. autoclass:: ustb.postprocess.IncoherentCompounding
   :members: go

Adaptive beamforming
^^^^^^^^^^^^^^^^^^^^

.. autoclass:: ustb.postprocess.CoherenceFactor
   :members: go

.. autoclass:: ustb.postprocess.GeneralizedCoherenceFactor
   :members: go

.. autoclass:: ustb.postprocess.PhaseCoherenceFactor
   :members: go

.. autoclass:: ustb.postprocess.CaponMinimumVariance
   :members: go, K_in_lambda

.. autoclass:: ustb.postprocess.DelayMultiplyAndSum
   :members: go

.. autoclass:: ustb.postprocess.ShortLagSpatialCoherence
   :members: go, K_in_lambda

Flow
^^^^

.. autoclass:: ustb.postprocess.SVDFilter
   :members: go

.. autoclass:: ustb.postprocess.AutocorrelationDisplacementEstimation
   :members: go

.. autoclass:: ustb.postprocess.ModifiedAutocorrelationDisplacementEstimation
   :members: go

Image processing
^^^^^^^^^^^^^^^^

.. autoclass:: ustb.postprocess.Median
   :members: go

Data and apodization
--------------------

.. autoclass:: ustb.beamformed_data.BeamformedData
   :members: plot, get_image, save_as_gif

.. autoclass:: ustb.apodization.Apodization
   :members: data

.. autoclass:: ustb.enums.Dimension
   :members:
   :undoc-members:

.. autoclass:: ustb.enums.Window
   :members:
   :undoc-members:

.. autoclass:: ustb.enums.Wavefront
   :members:
   :undoc-members:

Pipeline
--------

.. autoclass:: ustb.Pipeline
   :members:

Tools
-----

.. autofunction:: ustb.tools.download

.. autofunction:: ustb.tools.zenodo_dataset_files_base

.. autofunction:: ustb.tools.power_spectrum

.. autofunction:: ustb.tools.estimate_frequency

.. autofunction:: ustb.tools.scan_convert

.. autofunction:: ustb.tools.uniform_fov_weighting

.. autofunction:: ustb.plotting.plot_beamformed_data

.. autofunction:: ustb.plotting.plot_channel_data
