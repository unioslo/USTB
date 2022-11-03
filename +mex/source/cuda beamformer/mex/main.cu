/*================================================
 *
 * CUDA general beamformer for USTB
 *
 * Stefano Fiorentini <stefano.fiorentini@ntnu.no>
 * Last edit 02.11.2022
 *
 *================================================*/

 //Inputs
 //prhs[0]	 channel_data [time, channel, wave, frame]
 //prhs[1]   sampling frequency (Hz)
 //prhs[2]	 initial time (s)

 //prhs[3]	 transmit apodization [pixel, wave]
 //prhs[4]	 receive apodization [pixel, channel]

 //prhs[5]	 transmit delay [pixel, wave]
 //prhs[6]	 receive delay [pixel, channel]

 //prhs[7]   modulation frequency (Hz)
 //prhs[8]   sum mode 0 -> NONE, 1->RX, 2->TX, 3->BOTH

 //Output
 //plhs[0]   beanformed data [pixel, channel, wave, frame]

#include <mex.h>
#include <matrix.h>

#include <math.h>
#include <stdbool.h>
#include <string.h>

#include <cuComplex.h>
#include <cuda_runtime.h>
#include <device_launch_parameters.h>

#include "beamform_iq_kernel.cu"
#include "beamform_rf_kernel.cu"
#include "mexCheckArguments.c"

#define cudaErrorCheck(arg) { cudaAssert((arg), __FILE__, __LINE__); }
inline void cudaAssert(cudaError_t code, const char* file, int line)
{
	if (code != cudaSuccess)
	{
		mexErrMsgIdAndTxt("Toolbox:SRP_SRC:GPU", "CUDA error: %s in file %s line %d\n", cudaGetErrorString(code), file, line);
	}
}

void mexCheckArguments(int nlhs, mxArray* plhs[], int nrhs, const mxArray* prhs[]);

// Constants
#define eps 1E-6
#define pi acosf(-1.0)
#define thread_per_block 256

void mexFunction(int nlhs, mxArray* plhs[], int nrhs, const mxArray* prhs[])
{

	// Check arguments
	mexCheckArguments(nlhs, plhs, nrhs, prhs);

	// Extract relevant parameters

	size_t* channel_size = (size_t*) mxGetDimensions(prhs[0]);
	size_t* tx_delay_size = (size_t*) mxGetDimensions(prhs[5]);

	size_t N_times	= channel_size[0];		// number of time samples
	size_t N_channels	= channel_size[1];	// number of channels
	size_t N_waves = (mxGetNumberOfDimensions(prhs[0]) > 2) ? channel_size[2] : 1;	// number of waves
	size_t N_frames = (mxGetNumberOfDimensions(prhs[0]) > 3) ? channel_size[3] : 1;	// number of frames
	size_t N_pixels = tx_delay_size[0];		// number of pixels

	float Fs = *mxGetSingles(prhs[1]);		// Sampling frequency
	float t0 = *mxGetSingles(prhs[2]);		// Initial time
	float Fd = *mxGetSingles(prhs[7]);		// Modulation frequency
	float i0 = t0 * Fs;						// Normalised initial sample

	bool IQ = fabsf(Fd) > eps;				// Toggle whether channel data is in IQ or RF format
	float wd = IQ ? 2 * pi * Fd : 0.0;		// Demodulation frequency expressed in rad/s

	// Allocate beamformed data matrix in RAM
	size_t beamformed_size[4];
	beamformed_size[0] = N_pixels;  
	beamformed_size[1] = 1;			
	beamformed_size[2] = 1;			
	beamformed_size[3] = N_frames; 
	plhs[0] = mxCreateNumericArray(4, (const size_t*)&beamformed_size, mxSINGLE_CLASS, mxCOMPLEX);

	// Get pointer to beamformed data and pin memory for asynchronous memory transfer with the GPU
	mxComplexSingle* host_bf_data = mxGetComplexSingles(plhs[0]);
	cudaErrorCheck(cudaHostRegister(host_bf_data, beamformed_size[0] * beamformed_size[1] * beamformed_size[2] * beamformed_size[3] * sizeof(mxComplexSingle), cudaHostRegisterDefault)); // Pin paged memory for asynchronous transfers

	// Get pointer to channel data and pin memory for asynchronous memory transfer with the GPU
	mxComplexSingle* host_ch_data = mxGetComplexSingles(prhs[0]);
	cudaErrorCheck(cudaHostRegister(host_ch_data, N_times * N_channels * N_waves * N_frames * sizeof(mxComplexSingle), cudaHostRegisterDefault)); // Pin paged memory for asynchronous transfers

	// Transfer delay and apodization matrices to GPU
	// Retrieve pointer to host arrays
	float* host_tx_delay = mxGetSingles(prhs[5]);
	float* host_tx_apod = mxGetSingles(prhs[3]);
	float* host_rx_delay = mxGetSingles(prhs[6]);
	float* host_rx_apod = mxGetSingles(prhs[4]);

	// Allocate device memory
	float* device_tx_delay;
	float* device_tx_apod;
	float* device_rx_delay;
	float* device_rx_apod;

	cudaErrorCheck(cudaMalloc((void**)&device_tx_delay, N_pixels * N_waves * sizeof(float)));
	cudaErrorCheck(cudaMalloc((void**)&device_tx_apod, N_pixels * N_waves * sizeof(float)));
	cudaErrorCheck(cudaMalloc((void**)&device_rx_delay, N_pixels * N_channels * sizeof(float)));
	cudaErrorCheck(cudaMalloc((void**)&device_rx_apod, N_pixels * N_channels * sizeof(float)));

	// Transfer data
	cudaErrorCheck(cudaMemcpy(device_tx_delay, host_tx_delay, N_pixels * N_waves * sizeof(float), cudaMemcpyHostToDevice));
	cudaErrorCheck(cudaMemcpy(device_tx_apod, host_tx_apod, N_pixels * N_waves * sizeof(float), cudaMemcpyHostToDevice));
	cudaErrorCheck(cudaMemcpy(device_rx_delay, host_rx_delay, N_pixels * N_channels * sizeof(float), cudaMemcpyHostToDevice));
	cudaErrorCheck(cudaMemcpy(device_rx_apod, host_rx_apod, N_pixels * N_channels * sizeof(float), cudaMemcpyHostToDevice));

	// If only one frame has to be processed, then only allocate one stream, otherwise allocate 2
	size_t N_streams = (N_frames > 1) ? 2 : 1;

	// Allocate device memory for beamformed data
	cuFloatComplex** device_bf_data = (cuFloatComplex**) malloc(N_streams * sizeof(cudaArray**));
	
	for (size_t n_stream = 0; n_stream < N_streams; n_stream++)
	{
		cudaErrorCheck(cudaMalloc((void**)&device_bf_data[n_stream], N_pixels * sizeof(cuFloatComplex)));
	}

	// Allocate an array of 1D Layered cudaArray and a cudaTextureObjects
	// Need 2 elements in the array to allow for asynchronous operations
	cudaArray** device_ch_data = (cudaArray**)malloc(N_streams * sizeof(cudaArray*)); // Array of pointers to cudaArrays
	cudaChannelFormatDesc channelDesc = cudaCreateChannelDesc(32, 32, 0, 0, cudaChannelFormatKindFloat); // channel descriptor for a cuFloatComplex type.
	cudaTextureObject_t* tex = (cudaTextureObject_t*)malloc(N_streams * sizeof(cudaTextureObject_t));

	for (size_t n_stream = 0; n_stream < N_streams; n_stream++)
	{
		cudaErrorCheck(cudaMalloc3DArray(&device_ch_data[n_stream], &channelDesc, make_cudaExtent(N_times, 0, N_channels * N_waves), cudaArrayLayered)); // Allocate 1D Layered texture

		// Input data properties
		cudaResourceDesc resDesc;
		memset(&resDesc, 0, sizeof(cudaResourceDesc));
		resDesc.resType = cudaResourceTypeArray;
		resDesc.res.array.array = device_ch_data[n_stream];

		// Texture properties
		cudaTextureDesc texDesc;
		memset(&texDesc, 0, sizeof(cudaTextureDesc));
		texDesc.filterMode = cudaFilterModeLinear; // linear interpolation between texels
		texDesc.normalizedCoords = 0; // coordinates are not normalized [0, 1, ..., N_times-1]
		texDesc.addressMode[0] = cudaAddressModeBorder; // out of bound coordinates are 0
		texDesc.readMode = cudaReadModeElementType;

		// Texture Object
		cudaErrorCheck(cudaCreateTextureObject(&tex[n_stream], &resDesc, &texDesc, NULL));
	}

	// Define block_size and N_blocks
	dim3 block_size = dim3(thread_per_block);
	dim3 N_blocks = dim3((N_pixels + block_size.x - 1) / block_size.x);

	// Setupt cudaStream for asynchronous operations
	cudaStream_t* frame_stream = (cudaStream_t*)malloc(N_streams * sizeof(cudaStream_t));
	for (size_t n_stream = 0; n_stream < N_streams; n_stream++)
	{
		cudaErrorCheck(cudaStreamCreate(&frame_stream[n_stream]));
	}

	// cudaMemcpy3D properties
	cudaMemcpy3DParms* memcpyParams = (cudaMemcpy3DParms*) malloc(N_streams * sizeof(cudaMemcpy3DParms));

	for (size_t n_stream = 0; n_stream < N_streams; n_stream++)
	{
		memset(&memcpyParams[n_stream], 0, sizeof(cudaMemcpy3DParms));
		memcpyParams[n_stream].extent = make_cudaExtent(N_times, 1, N_channels * N_waves); // cudaExtent object for a 1D layered texture;
		memcpyParams[n_stream].kind = cudaMemcpyHostToDevice;
		memcpyParams[n_stream].dstArray = device_ch_data[n_stream];
	}

	// Beamforming loop
	for (size_t n_frame = 0; n_frame < N_frames; n_frame += N_streams)
	{
		size_t N_streams_currFrame = (N_frames - n_frame) % N_streams == 0 ? N_streams : 1;

		for (size_t n_stream = 0; n_stream < N_streams_currFrame; n_stream++)
		{
			// Copy channel data into dedicated texture memory
			memcpyParams[n_stream].srcPtr = make_cudaPitchedPtr(&host_ch_data[(n_frame + n_stream) * N_waves * N_channels * N_times], N_times * sizeof(cuFloatComplex), N_times, 1);
			cudaErrorCheck(cudaMemcpy3DAsync(&memcpyParams[n_stream], frame_stream[n_stream]));

		}

		for (size_t n_stream = 0; n_stream < N_streams_currFrame; n_stream++)
		{
			// Set device beamformed data to 0
			cudaErrorCheck(cudaMemsetAsync(device_bf_data[n_stream], 0, N_pixels * sizeof(cuFloatComplex), frame_stream[n_stream]));
		}

		for (size_t n_stream = 0; n_stream < N_streams_currFrame; n_stream++)
		{
			// Call beamforming kernel
			if (!IQ)
			{
				beamform << < N_blocks, block_size, 0, frame_stream[n_stream] >> > (N_pixels, N_channels, N_waves, Fs, device_bf_data[n_stream], tex[n_stream], device_tx_delay,
					device_rx_delay, device_tx_apod, device_rx_apod, i0);
				cudaErrorCheck(cudaPeekAtLastError());
			}
			else
			{
				beamform_iq << < N_blocks, block_size, 0, frame_stream[n_stream] >> > (N_pixels, N_channels, N_waves, Fs, device_bf_data[n_stream], tex[n_stream], device_tx_delay,
					device_rx_delay, device_tx_apod, device_rx_apod, i0, wd);
				cudaErrorCheck(cudaPeekAtLastError());
			}
		}

		for (size_t n_stream = 0; n_stream < N_streams_currFrame; n_stream++)
		{
			// Transfer beamformed data back to host
			cudaErrorCheck(cudaMemcpyAsync(&host_bf_data[(n_frame + n_stream) * N_pixels], device_bf_data[n_stream], N_pixels * sizeof(cuFloatComplex), cudaMemcpyDeviceToHost, frame_stream[n_stream]));
		}
	} // end of frame loop

	for (size_t n_stream = 0; n_stream < N_streams; n_stream++)
	{
		// Destroy cudaStreams
		cudaErrorCheck(cudaStreamDestroy(frame_stream[n_stream]));

		// Free Texture memory
		cudaErrorCheck(cudaFreeArray(device_ch_data[n_stream]));
		cudaErrorCheck(cudaDestroyTextureObject(tex[n_stream]));

		// Free beamformed data memory
		cudaErrorCheck(cudaFree(device_bf_data[n_stream]));
	}

	cudaErrorCheck(cudaFree(device_tx_apod));
	cudaErrorCheck(cudaFree(device_tx_delay));
	cudaErrorCheck(cudaFree(device_rx_apod));
	cudaErrorCheck(cudaFree(device_rx_delay));

	// Unpin host memory
	cudaErrorCheck(cudaHostUnregister(host_ch_data));
	cudaErrorCheck(cudaHostUnregister(host_bf_data));
}