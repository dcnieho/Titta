clc

% ensure in right directory
myDir = fileparts(mfilename('fullpath'));
cd(myDir);

isWin    = strcmp(computer,'PCWIN')                             || strcmp(computer,'PCWIN64') || ~isempty(strfind(computer, 'mingw32')); %#ok<STREMP>
isLinux  = strcmp(computer,'GLNX86')                            || strcmp(computer,'GLNXA64') || ~isempty(strfind(computer, 'linux-gnu')); %#ok<STREMP>
isOSX    = strcmp(computer,'MAC')    || strcmp(computer,'MACI') || strcmp(computer, 'MACI64') || strcmp(computer, 'MACA64') || ~isempty(strfind(computer, 'apple-darwin')); %#ok<STREMP>
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

    out_stem = sprintf('TittaMex_v%d',SDK_version);

    % prep output location
    outDir = fullfile(myDir,'TittaMex','mex');

    if isOctave
        if isWin
            linkTobiiResearchLib = sprintf('-ltobii_research_v%d',SDK_version);
        elseif isLinux
            linkTobiiResearchLib = sprintf('-l:libtobii_research.so.%d',SDK_version);
        else
            linkTobiiResearchLib = sprintf('-ltobii_research.%d',SDK_version);
        end
        outFile = fullfile(outDir,sprintf('%s.%s',out_stem,mexext));
        inpArgs = {'-v'
            '-O3'
            '-ffunction-sections'
            '-fdata-sections'
            '-flto'
            '--output'
            outFile
            sprintf('-DTOBII_SDK_MAJOR_VERSION=%d',SDK_version)
            '-DBUILD_FROM_SCRIPT'
            '-DIS_OCTAVE'
            sprintf('-I%s',fullfile(myDir,'deps','include'))
            sprintf('-I%s',fullfile(myDir,'deps','include',sprintf('SDKv%d',SDK_version)))
            sprintf('-I%s',myDir)
            sprintf('-I%s',fullfile(myDir,'TittaMex'))
            fullfile(myDir,'TittaMex','TittaMex.cpp')
            fullfile(myDir,'src','Titta.cpp')
            fullfile(myDir,'src','types.cpp')
            fullfile(myDir,'src','utils.cpp')
            linkTobiiResearchLib}.';

        if isLinux
            inpArgs = [inpArgs {
                sprintf('-L%s',outDir)
                '-lc'
                '-lrt'
                '-ldl'}.'];
        elseif isOSX
            inpArgs = [inpArgs {
                sprintf('-L%s',outDir)
                '-mmacosx-version-min=''11'''}.'];
        elseif isWin
            inpArgs = [inpArgs {
                sprintf('-L%s',fullfile(myDir,'deps','lib'))}];

            % i need to switch path to bindir or mex/mkoctfile fails because
            % gcc not found. Find proper solution for that later.
            tdir=eval('__octave_config_info__("bindir")');  % eval because invalid syntax for matlab, would cause whole file not to run
            cd(tdir);
        end

        % get cppflags, add to it what we need
        flags = regexprep(mkoctfile('-p','CXXFLAGS'),'\r|\n','');   % strip newlines
        if isempty(strfind(flags,'-std=c++2a')) %#ok<STREMP>
            setenv('CXXFLAGS',[flags ' -std=c++2a']);
        end
        % get linker flags, add to it what we need
        flags = regexprep(mkoctfile('-p','LDFLAGS'),'\r|\n','');   % strip newlines
        flags = [flags ' -flto'];
        if isLinux
            flags = [flags ' -Wl,-rpath,''$ORIGIN'' -Wl,--gc-sections'];
        elseif isOSX
            flags = [flags ' -Wl,-rpath,''@loader_path'' -dead_strip -mmacosx-version-min=''11'''];
        elseif isWin
            flags = [flags ' -Wl,--gc-sections'];
        end
        setenv('LDFLAGS',flags);

        mex(inpArgs{:});
        cd(myDir);
        if isLinux
            % PTB does it, so we use their code to do this too
            striplibsfrommexfile(outFile);
        end
    else
        % prep input file
        cpp_file = fullfile(myDir,'TittaMex',sprintf('%s.cpp',out_stem));
        copyfile(fullfile(myDir,'TittaMex','TittaMex.cpp'), cpp_file);

        inpArgs = {'-R2017b'    % needed on R2019a and later to make sure we build a lib that runs on MATLABs as old as at least R2015b
            '-v'
            '-outdir'
            outDir
            sprintf('-DTOBII_SDK_MAJOR_VERSION=%d',SDK_version)
            '-DBUILD_FROM_SCRIPT'
            sprintf('-I%s',fullfile(myDir,'deps','include'))
            sprintf('-I%s',fullfile(myDir,'deps','include',sprintf('SDKv%d',SDK_version)))
            sprintf('-I%s',myDir)
            sprintf('-I%s',fullfile(myDir,'Titta'))
            cpp_file
            fullfile('src','*.cpp')}.';

        if isWin
            inpArgs = [inpArgs {
                'COMPFLAGS="$COMPFLAGS /std:c++latest /Gy /Oi /GL /permissive- /O2"'
                sprintf('-L%s',fullfile(myDir,'deps','lib'))
                'LINKFLAGS="$LINKFLAGS /LTCG /OPT:REF /OPT:ICF"'}.'];
        elseif isLinux
            inpArgs = [inpArgs {
                'CXXFLAGS="$CXXFLAGS -std=c++2a -ffunction-sections -fdata-sections -flto -fvisibility=hidden -O3"'
                'LDFLAGS="$LDFLAGS -Wl,-rpath,''$ORIGIN'' -Wl,--gc-sections -flto"'
                sprintf('-L%s',outDir)
                sprintf('-l:libtobii_research.so.%d',SDK_version)}.'];
        elseif isOSX
            inpArgs = [inpArgs {
                'CXXFLAGS="\$CXXFLAGS -std=c++2a -ffunction-sections -fdata-sections -flto -fvisibility=hidden -mmacosx-version-min=''11'' -O3"'
                'LDFLAGS="\$LDFLAGS -Wl,-rpath,''@loader_path'' -dead_strip -flto -mmacosx-version-min=''11''"'
                sprintf('-L%s',outDir)
                sprintf('-ltobii_research.%d',SDK_version)}.'];
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
