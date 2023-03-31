filename = '+mex/source/dasFast_c.cpp';
compiler_option = '-/GL /fp:fast /arch:AVX512 -I /usr/include/tbb'; % check if processor supports AVX2

compstr = ['mex -R2018a ' filename ' COMPFLAGS="$COMPFLAGS /fp:fast /arch:AVX512' compiler_option '"'];
disp(compstr);
eval(compstr);