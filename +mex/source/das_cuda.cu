/*================================================
 *
 * CUDA MEX general beamformer for USTB
 *
 * Stefano Fiorentini <stefano.fiorentini@ntnu.no>
 * Last edit 01.02.2023
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
 //prhs[9]   gpu ID (default is 0)
         
 //Output
 //plhs[0]   beanformed data [pixel, channel, wave, frame]

#include <mex.h>
#include <matrix.h>

#include <math.h>
#include <stdbool.h>
#include <string.h>

#include <cuComplex.h>
#include <cuda_runtime.h>
#include <cuda.h>
#include <device_launch_parameters.h>

// Constants
#define eps 1E-6f
#define pi acosf(-1.0)
#define thread_per_block 64

// Interpolation function
__device__  inline cuFloatComplex lerp(cuFloatComplex v0, cuFloatComplex v1, float t)
{
    cuFloatComplex v;
    
    v.x = fma(t, v1.x, fma(-t, v0.x, v0.x));
    v.y = fma(t, v1.y, fma(-t, v0.y, v0.y));

    return v;
}

// Beamforming kernel
__global__ void beamform(const int N_pixels, const int N_channels, const int N_waves, const float Fs, cuFloatComplex* bf_data, const cudaTextureObject_t tex,
	const float* __restrict__ tx_delay, const float* __restrict__ rx_delay, const float* __restrict__ tx_apod, const float* __restrict__ rx_apod, const float i0, const float wd)
{
	int pixel_idx = blockIdx.x * blockDim.x + threadIdx.x; // pixel idx
	int pixel_stride = blockDim.x * gridDim.x;

	extern __shared__ float t[];

	float *tDelay = t;
	float *tApod = (float*)&tDelay[blockDim.x*N_waves];

    // Load tx delay and tx apodization matrices in shared memory because they are read multiple times
	for (int i = pixel_idx; i < N_pixels; i += pixel_stride)
	{
		for (int j = 0; j < N_waves; j++)
        {
			tDelay[threadIdx.x+j*blockDim.x] = tx_delay[i + j * N_pixels];
			tApod[threadIdx.x+j*blockDim.x] = tx_apod[i + j * N_pixels];
		}
	}

	__syncthreads();

	for (int i = pixel_idx; i < N_pixels; i += pixel_stride)
	{
		for (int g = 0; g < N_channels; g++)
		{
			const float rApod = rx_apod[i + g * N_pixels];

            if (rApod > 0.0f)
            {
				const float rDelay = rx_delay[i + g * N_pixels];

                for (int j = 0; j < N_waves; j++)
                {
					const float apod = rApod * tApod[threadIdx.x+j*blockDim.x];

                    if (apod > 0.0f)
                    {
						const float delay = rDelay + tDelay[threadIdx.x+j*blockDim.x];
                        const float denay = fma(delay, Fs, -i0);

                        cuFloatComplex phase;

                        __sincosf(wd * delay, &phase.y, &phase.x);

				        const float n = denay - floor(denay);

                        const cuFloatComplex val = lerp(tex2D<cuFloatComplex>(tex, denay, g + j * N_channels), 
                                                        tex2D<cuFloatComplex>(tex, denay+1.0f, g + j * N_channels), n);

                        bf_data[i].x = fma((val.x * phase.x - val.y * phase.y), apod, bf_data[i].x);
                        bf_data[i].y = fma((val.x * phase.y + val.y * phase.x), apod, bf_data[i].y);
                    }
                }
            }
        }
	}
}

#define cudaErrorCheck(arg) { cudaAssert((arg), __LINE__); }
inline void cudaAssert(cudaError_t code, int line)
{
	if (code != cudaSuccess)
	{
		mexErrMsgIdAndTxt("Toolbox:SRP_SRC:GPU", "CUDA error: %s in line %d\n", cudaGetErrorString(code), line);
	}
}

void mexCheckArguments(int nlhs, mxArray* plhs[], int nrhs, const mxArray* prhs[]);

void mexFunction(int nlhs, mxArray* plhs[], int nrhs, const mxArray* prhs[])
{

	// Check arguments
	mexCheckArguments(nlhs, plhs, nrhs, prhs);

	// Extract relevant parameters

	size_t* channel_size = (size_t*) mxGetDimensions(prhs[0]);
	size_t* tx_delay_size = (size_t*) mxGetDimensions(prhs[5]);

	size_t N_times	= channel_size[0];		// number of time samples
	size_t N_channels = channel_size[1];	// number of channels
	size_t N_waves = (mxGetNumberOfDimensions(prhs[0]) > 2) ? channel_size[2] : 1;	// number of waves
	size_t N_frames = (mxGetNumberOfDimensions(prhs[0]) > 3) ? channel_size[3] : 1;	// number of frames
	size_t N_pixels = tx_delay_size[0];		// number of pixels

	float Fs = *mxGetSingles(prhs[1]);		// Sampling frequency
	float t0 = *mxGetSingles(prhs[2]);		// Initial time
	float Fd = *mxGetSingles(prhs[7]);		// Modulation frequency
	float i0 = t0 * Fs;               // Normalised initial sample

	float wd = fabsf(Fd) > eps ? 2 * pi * Fd : 0.0;		// Demodulation frequency expressed in rad/s

	// Allocate beamformed data matrix in RAM
	size_t beamformed_size[4];
	beamformed_size[0] = N_pixels;  
	beamformed_size[1] = 1;			
	beamformed_size[2] = 1;			
	beamformed_size[3] = N_frames; 
	plhs[0] = mxCreateNumericArray(4, (const size_t*)&beamformed_size, mxSINGLE_CLASS, mxCOMPLEX);

    // Set gpuDevice to run CUDA code
  	int dev = *mxGetInt32s(prhs[9]);
    cudaErrorCheck(cudaSetDevice(dev))
    
    // Get shared memory per block size of the selected GPU
    // int sharedMemPerBlock;
    //cudaErrorCheck(getCudaAttribute<int>(&sharedMemPerBlock,
    //                      CU_DEVICE_ATTRIBUTE_MAX_SHARED_MEMORY_PER_BLOCK, dev));

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

	// Allocate an array of 2D cudaArray and a cudaTextureObjects
	// Need 2 elements in the array to allow for asynchronous operations
	cudaArray** device_ch_data = (cudaArray**)malloc(N_streams * sizeof(cudaArray*)); // Array of pointers to cudaArrays
	cudaChannelFormatDesc channelDesc = cudaCreateChannelDesc(32, 32, 0, 0, cudaChannelFormatKindFloat); // channel descriptor for a cuFloatComplex type.
	cudaTextureObject_t* tex = (cudaTextureObject_t*)malloc(N_streams * sizeof(cudaTextureObject_t));

	for (size_t n_stream = 0; n_stream < N_streams; n_stream++)
	{
		cudaErrorCheck(cudaMallocArray(&device_ch_data[n_stream], &channelDesc, N_times, N_channels*N_waves, cudaArrayDefault)); // Allocate 2D texture

		// Input data properties
		cudaResourceDesc resDesc;
		memset(&resDesc, 0, sizeof(cudaResourceDesc));
		resDesc.resType = cudaResourceTypeArray;
		resDesc.res.array.array = device_ch_data[n_stream];

		// Texture properties
		cudaTextureDesc texDesc;
		memset(&texDesc, 0, sizeof(cudaTextureDesc));
		texDesc.filterMode = cudaFilterModePoint; // nearest neighbour interpolation
		texDesc.normalizedCoords = false; // coordinates are not normalized [0, 1, ..., N_times-1]
		texDesc.addressMode[0] = cudaAddressModeBorder; // out of bound coordinates are 0
        texDesc.addressMode[1] = cudaAddressModeBorder; // out of bound coordinates are 0
		texDesc.readMode = cudaReadModeElementType;

		// Texture Object
		cudaErrorCheck(cudaCreateTextureObject(&tex[n_stream], &resDesc, &texDesc, NULL));
	}

	// Define block_size and N_blocks
	dim3 dimBlock = dim3(thread_per_block, 1, 1);
	dim3 dimGrid = dim3((N_pixels + dimBlock.x - 1) / dimBlock.x, 1, 1);

	// Setupt cudaStream for asynchronous operations
	cudaStream_t* frame_stream = (cudaStream_t*)malloc(N_streams * sizeof(cudaStream_t));
	for (size_t n_stream = 0; n_stream < N_streams; n_stream++)
	{
		cudaErrorCheck(cudaStreamCreate(&frame_stream[n_stream]));
	}

	// Beamforming loop
	for (size_t n_frame = 0; n_frame < N_frames; n_frame += N_streams)
	{
		size_t Nc_streams = (N_frames - n_frame) < N_streams |  N_streams == 1 ? 1 : N_streams;

		for (size_t n_stream = 0; n_stream < Nc_streams; n_stream++)
		{
			// Copy channel data into cudaArray
			cudaErrorCheck(cudaMemcpy2DToArrayAsync(device_ch_data[n_stream], 
            0, 0, &host_ch_data[(n_frame + n_stream) * N_waves * N_channels * N_times], 
            N_times * sizeof(cuFloatComplex), N_times * sizeof(cuFloatComplex), N_channels * N_waves, 
            cudaMemcpyHostToDevice, frame_stream[n_stream]));

		}

		for (size_t n_stream = 0; n_stream < Nc_streams; n_stream++)
		{
			// Set device beamformed data to 0
			cudaErrorCheck(cudaMemsetAsync(device_bf_data[n_stream], 0, N_pixels * sizeof(cuFloatComplex), frame_stream[n_stream]));

			// Call beamforming kernel
			beamform <<< dimGrid, dimBlock, 2*thread_per_block*N_waves*sizeof(float), frame_stream[n_stream] >>> ((int) N_pixels, (int) N_channels, (int) N_waves, Fs, device_bf_data[n_stream], tex[n_stream], device_tx_delay,
				device_rx_delay, device_tx_apod, device_rx_apod, i0, wd);
			cudaErrorCheck(cudaPeekAtLastError());
		}

		for (size_t n_stream = 0; n_stream < Nc_streams; n_stream++)
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

void mexCheckArguments(int nlhs, mxArray* plhs[], int nrhs, const mxArray* prhs[])
{
	// Check number of arguments
	if (nrhs != 10)
	{
		mexErrMsgIdAndTxt("Toolbox:SRP_SRC:nrhs", "Wrong number of input arguments");
	}
	if (nlhs > 1)
	{
		mexErrMsgIdAndTxt("Toolbox:SRP_SRC:nlhs", "Too many output arguments");
	}

	// Check that bmf.dimension is set to dimension.both
	if (*mxGetInt32s(prhs[8]) != 3)
	{
		mexErrMsgTxt("In this implementation only dimension.both is supported");
	}

	// Channel data
	// Check dimension
	if (mxGetNumberOfDimensions(prhs[0]) < 2 || mxGetNumberOfDimensions(prhs[0]) > 4)
	{
		mexErrMsgIdAndTxt("Toolbox:SRP_SRC:Dimensions", "Wrong channel data format. Must be in the form [time, channel, wave, frame]");
	}
	// Get channel data size
	size_t* channel_size = (size_t*)mxGetDimensions(prhs[0]);

	// Check that channel data is of type complex float
	if (mxIsDouble(prhs[0]) && !mxIsComplex(prhs[0]))
	{
		mexErrMsgIdAndTxt("Toolbox:SRP_SRC:Float", "Channel data must be complex float");
	}

	// Transmit delay
	// check dimensions
	if (mxGetNumberOfDimensions(prhs[5]) > 2)
	{
		mexErrMsgIdAndTxt("Toolbox:SRP_SRC:Dimensions", "Wrong transmit delay matrix format. Expected 2 dimensions: [pixel, wave]");
	}
	// Get transmit delay matrix size
	size_t* tx_delay_size = (size_t*)mxGetDimensions(prhs[5]);

	// Check that the number of dimensions match
	if (mxGetNumberOfDimensions(prhs[5]) > 1 && tx_delay_size[1] != channel_size[2])
	{
		mexErrMsgIdAndTxt("Toolbox:SRP_SRC:Dimensions", "Channel data and transmit delay size do not match");
	}

	// check that tx delay matrix is of type float
	if (mxIsDouble(prhs[5]))
	{
		mexErrMsgIdAndTxt("Toolbox:SRP_SRC:Float", "The transmit delay must be of type float");
	}

	// Receive delay
	// check dimensions
	if (mxGetNumberOfDimensions(prhs[6]) > 2)
	{
		mexErrMsgIdAndTxt("Toolbox:SRP_SRC:Dimensions", "Wrong receive delay matrix format. Expected 2 dimensions: [pixel, channels]");
	}
	// Get receive delay matrix size
	size_t* rx_delay_size = (size_t*)mxGetDimensions(prhs[6]);

	// Check that the number of dimensions match
	if (mxGetNumberOfDimensions(prhs[6]) > 1 && rx_delay_size[1] != channel_size[1])
	{
		mexErrMsgIdAndTxt("Toolbox:SRP_SRC:Dimensions", "Channel data and receive delay size do not match");
	}

	// check that receive delay matrix is of type float
	if (mxIsDouble(prhs[6]))
	{
		mexErrMsgIdAndTxt("Toolbox:SRP_SRC:Float", "The receive delay must be of type float");
	}

	// Transmit apodization
	// check dimensions
	if (mxGetNumberOfDimensions(prhs[3]) > 2)
	{
		mexErrMsgIdAndTxt("Toolbox:SRP_SRC:Dimensions", "Wrong transmit apodization matrix format. Expected 2 dimensions: [pixel, waves]");
	}
	// Get tx data size
	size_t* tx_apodization_size = (size_t*)mxGetDimensions(prhs[3]);

	// Check that the number of dimensions match
	if (mxGetNumberOfDimensions(prhs[3]) > 1 && tx_apodization_size[1] != channel_size[2])
	{
		mexErrMsgIdAndTxt("Toolbox:SRP_SRC:Dimensions", "Channel data and transmit apodization size do not match");
	}

	// check that tx apodization matrix is of type float
	if (mxIsDouble(prhs[3]))
	{
		mexErrMsgIdAndTxt("Toolbox:SRP_SRC:Float", "The receive delay must be of type float");
	}

	// Receive apodization
	// check dimensions
	if (mxGetNumberOfDimensions(prhs[4]) > 2)
	{
		mexErrMsgIdAndTxt("Toolbox:SRP_SRC:Dimensions", "Wrong receive apodization matrix format. Expected 2 dimensions: [pixel, channels]");
	}
	// Get receive delay matrix size
	size_t* rx_apodization_size = (size_t*)mxGetDimensions(prhs[4]);

	// Check that the number of dimensions match
	if (mxGetNumberOfDimensions(prhs[4]) > 1 && rx_apodization_size[1] != channel_size[1])
	{
		mexErrMsgIdAndTxt("Toolbox:SRP_SRC:Dimensions", "Channel data and receive apodization size do not match");
	}

	// check that receive delay matrix is of type float
	if (mxIsDouble(prhs[4]))
	{
		mexErrMsgIdAndTxt("Toolbox:SRP_SRC:Float", "The receive apodization must be of type float");
	}

	// Sampling frequency
	// check dimensions
	if (!mxIsScalar(prhs[1]))
	{
		mexErrMsgTxt("The sampling frequency should be a scalar");
	}
	// check single precision
	if (mxIsDouble(prhs[1]))
	{
		mexErrMsgTxt("The sampling frequency should be of type float");
	}

	// Initial time
	// check dimensions
	if (!mxIsScalar(prhs[2]))
	{
		mexErrMsgIdAndTxt("Toolbox:SRP_SRC:Float", "The the initial time must be a scalar");
	}
	// check single precision
	if (mxIsDouble(prhs[2]))
	{
		mexErrMsgIdAndTxt("Toolbox:SRP_SRC:Float", "The initial time must be of type float");
	}

	// Modulation frequency
	// check dimension
	if (!mxIsScalar(prhs[7]))
	{
		mexErrMsgIdAndTxt("Toolbox:SRP_SRC:Scalar", "The modulation frequency must be a scalar");
	}
	// check single precision
	if (mxIsDouble(prhs[7]))
	{
		mexErrMsgIdAndTxt("Toolbox:SRP_SRC:Float", "The modulation frequency must be of type float");
	}
}