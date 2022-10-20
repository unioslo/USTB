filename = 'source\dasFast_c.cpp';
% filename = 'source\das_c_GE_omp.cpp';
compiler_option = '-D_WIN_ /GL /fp:fast /arch:AVX2'; % check if processor supports AVX2

% compiler_option = '-D_UNIX_ /O2 /GL /fp:fast /arch:AVX2 -IC:\Program Files (x86)\Intel\oneAPI\tbb\2021.2.0\include\tbb -LC:\Program Files (x86)\Intel\oneAPI\tbb\2021.2.0\lib\intel64\vc14 -ltbb';
% compiler_option = '-D_UNIX_ /O2 /GL /fp:fast /arch:AVX2 -I''"C:\Program Files (x86)\Intel\oneAPI\tbb\2021.2.0\include\tbb''" -L''"C:\Program Files (x86)\Intel\oneAPI\tbb\2021.2.0\lib\intel64\vc14''" -ltbb ';
compstr = ['mex -R2018a ' filename ' COMPFLAGS="$COMPFLAGS ' compiler_option '"'];
disp(compstr);
eval(compstr);