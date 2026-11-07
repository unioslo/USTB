.. default-domain:: py

MATLAB to Python
================

The Python classes mirror the MATLAB ones: create the object, set its
properties, call ``go()``. Names change from ``snake_case`` classes in MATLAB
packages to ``CamelCase`` classes in Python modules; properties keep their
MATLAB names.

.. code-block:: matlab

   mid = midprocess.das();
   mid.channel_data = channel_data;
   mid.scan = scan;
   mid.dimension = dimension.both;
   mid.receive_apodization.window = uff.window.tukey50;
   mid.receive_apodization.f_number = 1.7;
   b_data = mid.go();
   b_data.plot([], 'Title');

.. code-block:: python

   mid = DAS()
   mid.channel_data = channel_data
   mid.scan = scan
   mid.dimension = Dimension.both
   mid.receive_apodization.window = Window.tukey50
   mid.receive_apodization.f_number = np.array([1.7, 1.7])
   b_data = mid.go()
   b_data.plot(title="Title")

Class mapping
-------------

==================================================  ==========================================================
MATLAB                                              Python
==================================================  ==========================================================
``midprocess.das``                                  ``ustb.midprocess.DAS``
``preprocess.fast_demodulation``                    ``ustb.preprocess.FastDemodulation``
``preprocess.demodulation``                         ``ustb.preprocess.Demodulation``
``preprocess.svd_filter``                           ``ustb.preprocess.SVDFilter``
``postprocess.coherent_compounding``                ``ustb.postprocess.CoherentCompounding``
``postprocess.incoherent_compounding``              ``ustb.postprocess.IncoherentCompounding``
``postprocess.coherence_factor``                    ``ustb.postprocess.CoherenceFactor``
``postprocess.generalized_coherence_factor``        ``ustb.postprocess.GeneralizedCoherenceFactor``
``postprocess.phase_coherence_factor``              ``ustb.postprocess.PhaseCoherenceFactor``
``postprocess.capon_minimum_variance``              ``ustb.postprocess.CaponMinimumVariance``
``postprocess.delay_multiply_and_sum``              ``ustb.postprocess.DelayMultiplyAndSum``
``postprocess.short_lag_spatial_coherence``         ``ustb.postprocess.ShortLagSpatialCoherence``
``postprocess.svd_filter``                          ``ustb.postprocess.SVDFilter``
``postprocess.autocorrelation_displacement_...``    ``ustb.postprocess.AutocorrelationDisplacementEstimation``
``postprocess.modified_autocorrelation_...``        ``ustb.postprocess.ModifiedAutocorrelationDisplacementEstimation``
``postprocess.median``                              ``ustb.postprocess.Median``
``uff.apodization``                                 ``ustb.apodization.Apodization``
``uff.beamformed_data``                             ``ustb.beamformed_data.BeamformedData``
``dimension``, ``uff.window``, ``uff.wavefront``    ``ustb.enums.Dimension``, ``Window``, ``Wavefront``
``pipeline``                                        ``ustb.Pipeline``
``tools.download``, ``tools.power_spectrum``,       ``ustb.tools.download``, ``power_spectrum``,
``tools.estimate_frequency``                        ``estimate_frequency``
``uff.channel_data``, ``uff.scan``, ``uff.probe``,  ``pyuff_ustb.objects`` (``ChannelData``, ``LinearScan``,
``uff.wave``, ... and UFF file I/O                  ``SectorScan``, ``Probe``, ``Wave``, ``Uff``, ...)
==================================================  ==========================================================

Conventions
-----------

- **Two-element settings** such as ``f_number``, ``tilt``, ``MLA``,
  ``minimum_aperture`` are ``[x, y]`` arrays. A scalar is expanded to both
  axes, as by the MATLAB setters.
- **Indices that come from MATLAB keep MATLAB's 1-based meaning**, e.g. the
  ``cutoff`` of the SVD filters (``cutoff = 2`` removes the first, strongest
  singular component).
- **Data layout** is the same: channel data ``[time, channel, wave, frame]``,
  beamformed data ``[pixel, channel, wave, frame]``.
- **Pixel order differs.** MATLAB orders scan pixels with depth varying
  fastest; ``pyuff_ustb`` orders sector-scan pixels with azimuth varying
  fastest. All processes handle both; it only matters when you reshape
  ``data`` to an image yourself (use ``BeamformedData.get_image()``).

Known differences from MATLAB
-----------------------------

These are deliberate. Everything else is meant to match MATLAB, and is
tested to do so.

- **SLSC**: MATLAB computes the correlations in a compiled MEX
  (``mex.slsc_mex``) whose source is not in the repository. The Python
  version implements the published definition (normalized correlation over a
  centered depth kernel of ``K`` samples, averaged per lag over the active
  elements) and is tested on signals with known coherence, not against
  MATLAB.
- **Apodization at zero depth**: where MATLAB's windows give NaN (an infinite
  ratio for pixels at exactly zero depth), Python gives 0.
- **Capon and DMAS, transmit dimension**: MATLAB indexes the receive
  apodization linearly (``rx_apodization(n_channel)``), which picks a pixel
  instead of a channel; Python uses the channel's column. With the default
  (no) apodization the results are identical.
- **DMAS transmit apodization**: MATLAB also sets the probe on the transmit
  apodization, which makes it compute a receive-style apodization; Python
  computes the transmit (wave) apodization.
- **SVD filter**: Python always filters across the frame axis (MATLAB uses
  the last non-singleton dimension, which is the wave or channel axis when
  there is one frame), does not modify ``cutoff``, and raises an error for a
  cutoff that selects no components (MATLAB returns zeros).
- **Capon output convention** is kept from MATLAB: the output is the complex
  conjugate of the textbook ``w^H x`` (same envelope).
- **GCF**: an ``M0`` larger than the aperture raises a ``ValueError`` (MATLAB
  fails with an index error).
