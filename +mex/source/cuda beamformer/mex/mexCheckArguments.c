#include <mex.h>
#include <matrix.h>

void mexCheckArguments(int nlhs, mxArray* plhs[], int nrhs, const mxArray* prhs[])
{
	// Check number of arguments
	if (nrhs != 9)
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