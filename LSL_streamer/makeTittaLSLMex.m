clc

% ensure in right directory
myDir = fileparts(mfilename('fullpath'));
cd(myDir);

isWin    = strcmp(computer,'PCWIN')                             || strcmp(computer,'PCWIN64') || ~isempty(strfind(computer, 'mingw32')); %#ok<STREMP>
isLinux  = strcmp(computer,'GLNX86')                            || strcmp(computer,'GLNXA64') || ~isempty(strfind(computer, 'linux-gnu')); %#ok<STREMP>
isOSX    = strcmp(computer,'MAC')    || strcmp(computer,'MACI') || strcmp(computer, 'MACI64') || ~isempty(strfind(computer, 'apple-darwin')); %#ok<STREMP>
isOctave = ismember(exist('OCTAVE_VERSION', 'builtin'), [102, 5]);  % If the built-in variable OCTAVE_VERSION exists, then we are running under GNU/Octave, otherwise not.
is64Bit = ~isempty(strfind(computer, '64')); %#ok<STREMP>
assert(is64Bit,'only 64-bit builds are supported');
platform = 'Windows';
if isLinux
    platform = 'Linux';
elseif isOSX
    platform = 'OSX';
end

if isOctave
    error("building on Octave is not supported");
else
    inpArgs = {'-R2017b'    % needed on R2019a and later to make sure we build a lib that runs on MATLABs as old as at least R2015b
        '-v'
        '-outdir'
        fullfile(myDir,'TittaLSLMex','+TittaLSL','+detail')
        '-DBUILD_FROM_SCRIPT'
        sprintf('-I"%s"',fullfile(myDir,'deps','include'))
        sprintf('-I"%s"',myDir)
        sprintf('-I"%s"',fullfile(myDir,'..','SDK_wrapper'))
        sprintf('-I"%s"',fullfile(myDir,'..','SDK_wrapper','deps','include'))
        fullfile('TittaLSLMex','TittaLSLMex.cpp')
        fullfile('src','*.cpp')
        fullfile('..','SDK_wrapper','src','*.cpp')
        }.';

    if isWin
        inpArgs = [inpArgs {
            'COMPFLAGS="$COMPFLAGS /std:c++latest /Gy /Oi /GL /permissive- /O2"'
            sprintf('-L"%s"',fullfile(myDir,'deps','lib'))
            sprintf('-L"%s"',fullfile(myDir,'..','SDK_wrapper','deps','lib'))
            'LINKFLAGS="$LINKFLAGS /LTCG /OPT:REF /OPT:ICF"'}.'];
    elseif isLinux
        inpArgs = [inpArgs {
            'CXXFLAGS="$CXXFLAGS -std=c++2a -ffunction-sections -fdata-sections -flto -fvisibility=hidden -O3"'
            'LDFLAGS="$LDFLAGS -Wl,-rpath,''$ORIGIN'' -Wl,--gc-sections -flto"'
            sprintf('-L%s',fullfile(myDir,'TittaLSLMex','+TittaLSL','+detail'))
            '-ltobii_research'
            '-llsl'}.'];
    elseif isOSX
        inpArgs = [inpArgs {
            'CXXFLAGS="\$CXXFLAGS -std=c++2a -ffunction-sections -fdata-sections -flto -fvisibility=hidden -mmacosx-version-min=''11'' -O3"'
            'LDFLAGS="\$LDFLAGS -Wl,-rpath,''@loader_path'' -dead_strip -flto -mmacosx-version-min=''11''"'
            sprintf('-L%s',fullfile(myDir,'TittaLSLMex','+TittaLSL','+detail'))
            '-ltobii_research'
            '-llsl'}.'];
    end
    mex(inpArgs{:});
end
