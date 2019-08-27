clc

% ensure in right directory
myDir = fileparts(mfilename('fullpath'));
cd(myDir);

isWin    = strcmp(computer,'PCWIN') || strcmp(computer,'PCWIN64') || ~isempty(strfind(computer, 'mingw32')); %#ok<STREMP>
isLinux  = strcmp(computer,'GLNX86') || strcmp(computer,'GLNXA64') || ~isempty(strfind(computer, 'linux-gnu')); %#ok<STREMP>
isOctave = ismember(exist('OCTAVE_VERSION', 'builtin'), [102, 5]);  % If the built-in variable OCTAVE_VERSION exists, then we are running under GNU/Octave, otherwise not.
is64Bit = ~isempty(strfind(computer, '64')); %#ok<STREMP>


if isWin
    if isOctave
        if is64Bit
            bitLbl = '64';
        else
            error('32bit Octave not supported. You can try your luck. But then you''ll have to build PsychToolbox yourself as well for 32bit Octave');
        end
        inpArgs = {'-v', '-O', '--output', fullfile(myDir,'TobiiMex_matlab',bitLbl,sprintf('TobiiMex_matlab.%s',mexext)), '-DBUILD_FROM_MEX', sprintf('-L%s',fullfile(myDir,'deps','lib')), sprintf('-I%s',fullfile(myDir,'deps','include')), sprintf('-I%s',myDir), sprintf('-I%s',fullfile(myDir,'TobiiMex_matlab')), fullfile(myDir,'TobiiMex_matlab','TobiiMex_matlab.cpp'), fullfile(myDir,'src','TobiiMex.cpp'), fullfile(myDir,'src','types.cpp'), fullfile(myDir,'src','utils.cpp'), sprintf('-ltobii_research%s',bitLbl)};
        
        % i need to switch path to bindir or mex/mkoctfile fails because
        % gcc not found. Find proper solution for that later.
        tdir=eval('__octave_config_info__("bindir")');  % eval because invalid syntax for matlab, would cause whole file not to run
        cd(tdir);
        % get cppflags, add to it what we need
        flags = regexprep(mkoctfile('-p','CXXFLAGS'),'\r|\n','');   % strip newlines
        if isempty(strfind(flags,'-std=c++17')) %#ok<STREMP>
            setenv('CXXFLAGS',[flags ' -std=c++17']);
        end
        mex(inpArgs{:});
        cd(myDir);
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
    mex('-R2017b', '-v', '-O', 'CXXFLAGS="$CXXFLAGS -std=c++17"', '-outdir', fullfile(myDir,'TobiiMex_matlab',bitLbl), '-DBUILD_FROM_MEX', sprintf('-L%s',fullfile(myDir,'TobiiMex_matlab',bitLbl)), sprintf('-I%s',fullfile(myDir,'deps','include')), sprintf('-I%s',myDir), sprintf('-I%s',fullfile(myDir,'TobiiMex_matlab')), 'TobiiMex_matlab/TobiiMex_matlab.cpp', 'src/*.cpp', '-ltobii_research');
end