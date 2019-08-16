clc

% ensure in right directory
myDir = fileparts(mfilename('fullpath'));
cd(myDir);

isWin    = streq(computer,'PCWIN') || streq(computer,'PCWIN64') || ~isempty(strfind(computer, 'mingw32')); %#ok<STREMP>
isLinux  = streq(computer,'GLNX86') || streq(computer,'GLNXA64') || ~isempty(strfind(computer, 'linux-gnu')); %#ok<STREMP>
isOctave = ismember(exist('OCTAVE_VERSION', 'builtin'), [102, 5]);  % If the built-in variable OCTAVE_VERSION exists, then we are running under GNU/Octave, otherwise not.
is64Bit = ~isempty(strfind(computer, '64')); %#ok<STREMP>


if isWin
    if isOctave
        % Octave...
    else
        if is64Bit
            bitLbl = '64';
            extra = {'-R2017b'};    % needed on R2019a to make sure we build a lib that runs on MATLABs as old as R2015b
        else
            error('We must build with VS2019 or later, but last supported 32bit matlab version, R2015b, doesn''t support that compiler. Compile the mex file through the msvc project')
        end
        mex(extra{:}, '-v', '-O', 'COMPFLAGS="$COMPFLAGS /std:c++latest /Gy /Oi /GL /permissive-"', '-outdir', fullfile(myDir,'TobiiMex_matlab',bitLbl), '-DBUILD_FROM_MEX', sprintf('-L%s',fullfile(myDir,'deps','lib')), sprintf('-I%s',fullfile(myDir,'deps','include')), sprintf('-I%s',myDir), sprintf('-I%s',fullfile(myDir,'TobiiMex_matlab')), 'TobiiMex_matlab\TobiiMex_matlab.cpp', 'src\*.cpp', 'LINKFLAGS="$LINKFLAGS /LTCG /OPT:REF /OPT:ICF"');
    end
else
    % Linux
    if is64Bit
        bitLbl = '64';
    else
        error('Support for 32bit MATLAB on Linux not planned. May actually just work, go ahead and try');
    end
    mex('-R2017b', '-v', '-O', 'CXXFLAGS="$CXXFLAGS -std=c++2a"', '-outdir', fullfile(myDir,'TobiiMex_matlab',bitLbl), '-DBUILD_FROM_MEX', sprintf('-L%s',fullfile(myDir,'TobiiMex_matlab',bitLbl)), sprintf('-I%s',fullfile(myDir,'deps','include')), sprintf('-I%s',myDir), sprintf('-I%s',fullfile(myDir,'TobiiMex_matlab')), 'TobiiMex_matlab/TobiiMex_matlab.cpp', 'src/*.cpp', '-ltobii_research');
end