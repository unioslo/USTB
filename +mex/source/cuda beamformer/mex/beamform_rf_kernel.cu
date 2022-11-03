#include <cuda_runtime.h>
#include <cuComplex.h>
#include <device_launch_parameters.h>

// RF Beamforming kernel
__global__ void beamform(const size_t N_pixels, const size_t N_channels, const size_t N_waves, const float Fs, cuFloatComplex* bf_data, const cudaTextureObject_t tex,
	const float* tx_delay, const float* rx_delay, const float* tx_apod, const float* rx_apod, const float i0)
{
	size_t pixel_idx = blockIdx.x * blockDim.x + threadIdx.x; // pixel idx
	size_t pixel_stride = blockDim.x * gridDim.x;

	for (size_t i = pixel_idx; i < N_pixels; i += pixel_stride)
	{

		for (size_t j = 0; j < N_waves; j++)
		{
			float tDelay = tx_delay[i + j * N_pixels];
			float tApod = tx_apod[i + j * N_pixels];

			for (size_t g = 0; g < N_channels; g++)
			{
				float delay = tDelay + rx_delay[i + g * N_pixels];
				float apod = tApod * rx_apod[i + g * N_pixels];

				float denay = delay * Fs - i0;

				// For maximum bandwidth usage adiacent threads must fetch adiacent memory locations in texture --> inputSamplingRate ~= outputSamplingRate
				cuFloatComplex pre_bf_data = tex1DLayered<cuFloatComplex>(tex, denay, g + j * N_channels);

				bf_data[i].x += pre_bf_data.x * apod;
				bf_data[i].y += pre_bf_data.y * apod;
			}
		}
	}
}