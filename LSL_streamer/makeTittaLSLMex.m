clc

% ensure in right directory
myDir = fileparts(mfilename('fullpath'));
cd(myDir);

isWin    = strcmp(computer,'PCWIN')                             || strcmp(computer,'PCWIN64') || ~isempty(strfind(computer, 'mingw32')); %#ok<STREMP>
isLinux  = strcmp(computer,'GLNX86')                            || strcmp(computer,'GLNXA64') || ~isempty(strfind(computer, 'linux-gnu')); %#ok<STREMP>
isOSX    = strcmp(computer,'MAC')    || strcmp(computer,'MACI') || strcmp(computer, 'MACI64') || ~isempty(strfind(computer, 'apple-darwin')); %#ok<STREMP>
isAppleSilicon = strcmp(computer, 'MACA64');
isOctave = ismember(exist('OCTAVE_VERSION', 'builtin'), [102, 5]);  % If the built-in variable OCTAVE_VERSION exists, then we are running under GNU/Octave, otherwise not.
is64Bit = ~isempty(strfind(computer, '64')); %#ok<STREMP>
assert(is64Bit,'only 64-bit builds are supported');
platform = 'Windows';
if isLinux
    platform = 'Linux';
elseif isOSX
    platform = 'OSX';
end

for SDK_version=1:2
    % only sdk v2 has support for apple silicon
    if isAppleSilicon && SDK_version==1
        continue
    end

    out_stem = sprintf('TittaLSLMex_v%d',SDK_version);

    % prep output location
    outDir = fullfile(myDir,'TittaLSLMex','+TittaLSL','+detail');


    if isOctave
        error("building on Octave is not supported");
    else
        % prep input file
        cpp_file = fullfile(myDir,'TittaLSLMex',sprintf('%s.cpp',out_stem));
        copyfile(fullfile(myDir,'TittaLSLMex','TittaLSLMex.cpp'), cpp_file);

        inpArgs = {'-R2017b'    % needed on R2019a and later to make sure we build a lib that runs on MATLABs as old as at least R2015b
            '-v'
            '-outdir'
            fullfile(myDir,'TittaLSLMex','+TittaLSL','+detail')
            sprintf('-DTOBII_SDK_MAJOR_VERSION=%d',SDK_version)
            '-DBUILD_FROM_SCRIPT'
            sprintf('-I"%s"',fullfile(myDir,'deps','include'))
            sprintf('-I"%s"',myDir)
            sprintf('-I"%s"',fullfile(myDir,'..','SDK_wrapper'))
            sprintf('-I"%s"',fullfile(myDir,'..','SDK_wrapper','deps','include'))
            sprintf('-I"%s"',fullfile(myDir,'..','SDK_wrapper','deps','include',sprintf('SDKv%d',SDK_version)))
            cpp_file
            fullfile(myDir,'src','*.cpp')
            fullfile(myDir,'..','SDK_wrapper','src','*.cpp')
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
                sprintf('-l:libtobii_research.so.%d',SDK_version)
                '-llsl'}.'];
        elseif isOSX
            inpArgs = [inpArgs {
                'CXXFLAGS="\$CXXFLAGS -std=c++2a -ffunction-sections -fdata-sections -flto -fvisibility=hidden -mmacosx-version-min=''11'' -O3"'
                'LDFLAGS="\$LDFLAGS -Wl,-rpath,''@loader_path'' -dead_strip -flto -mmacosx-version-min=''11''"'
                sprintf('-L%s',fullfile(myDir,'TittaLSLMex','+TittaLSL','+detail'))
                sprintf('-l:libtobii_research.%d',SDK_version)
                '-llsl'}.'];
        end
        mex(inpArgs{:});

        % clean up input file
        delete(cpp_file);
    end
    if isOSX && SDK_version==1
        % need to fix up version of dylib that will be loaded, else v2
        % gets loaded and trouble ensues
        system(['install_name_tool -change @rpath/libtobii_research.dylib @rpath/libtobii_research.1.dylib ' fullfile(outDir,sprintf('%s.%s',out_stem,mexext))])
    end
end
