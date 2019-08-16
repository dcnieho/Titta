% ensure in right directory
myDir = fileparts(mfilename('fullpath'));
cd(myDir);

isWin    = streq(computer,'PCWIN') || streq(computer,'PCWIN64') || ~isempty(strfind(computer, 'mingw32')); %#ok<STREMP>
isOctave = ismember(exist('OCTAVE_VERSION', 'builtin'), [102, 5]);  % If the built-in variable OCTAVE_VERSION exists, then we are running under GNU/Octave, otherwise not.
if isWin
    if isOctave
        % Octave...
    else
        is64Bit = ~isempty(strfind(computer, 'x86_64')) || streq(computer,'PCWIN64'); %#ok<STREMP>
        bitLbl = '64';
        if ~is64Bit
            bitLbl = '32';
        end
        mex('-R2017b', '-v', '-O', 'COMPFLAGS="$COMPFLAGS /std:c++latest"', '-outdir', fullfile(myDir,'TobiiMex_matlab',bitLbl), '-DBUILD_FROM_MEX', sprintf('-L%s',fullfile(myDir,'deps','lib')), sprintf('-I%s',fullfile(myDir,'deps','include')), sprintf('-I%s',myDir), sprintf('-I%s',fullfile(myDir,'TobiiMex_matlab')), 'TobiiMex_matlab\TobiiMex_matlab.cpp', 'src\*.cpp', 'LINKFLAGS="$LINKFLAGS"');
    end
else
    % Linux
end