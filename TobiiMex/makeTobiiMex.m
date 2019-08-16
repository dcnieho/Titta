% ensure in right directory
myDir = fileparts(mfilename('fullpath'));
cd(myDir);

% If the built-in variable OCTAVE_VERSION exists,
% then we are running under GNU/Octave, otherwise not.
if ~ismember(exist('OCTAVE_VERSION', 'builtin'), [102, 5])
    mex('-O', 'COMPFLAGS="$COMPFLAGS /std:c++latest"', '-outdir', fullfile(myDir,'TobiiMex_matlab','build'), '-DBUILD_FROM_MEX', '-largeArrayDims', '-DMEX_DOUBLE_HANDLE', sprintf('-L%s',fullfile(myDir,'deps','lib')), sprintf('-I%s',fullfile(myDir,'deps','include')), sprintf('-I%s',myDir), sprintf('-I%s',fullfile(myDir,'TobiiMex_matlab')), 'TobiiMex_matlab\TobiiMex_matlab.cpp', 'src\*.cpp', 'LINKFLAGS="$LINKFLAGS"')
%     movefile(['..\Projects\Windows\build\Screen.' mexext], [PsychtoolboxRoot 'PsychBasic\MatlabWindowsFilesR2007a\']);
end