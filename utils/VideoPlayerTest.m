DEBUGlevel = 2;
bgClr      = 127;
videoFolder= fullfile(PsychtoolboxRoot,'PsychDemos/MovieDemos/');
videoExt   = 'mov';

try
    vids = FileFromFolder(videoFolder,[],videoExt);
    vids = arrayfun(@(x) fullfile(x.folder,x.name),vids,'uni',false);

    
    if DEBUGlevel>1
        % make screen partially transparent on OSX and windows vista or
        % higher, so we can debug.
        PsychDebugWindowConfiguration;
    end
    if DEBUGlevel
        % Be pretty verbose about information and hints to optimize your code and system.
        Screen('Preference', 'Verbosity', 4);
    else
        % Only output critical errors and warnings.
        Screen('Preference', 'Verbosity', 2);
    end
    Screen('Preference', 'SyncTestSettings', 0.002);    % the systems are a little noisy, give the test a little more leeway
    [wpnt,winRect] = PsychImaging('OpenWindow', 1, bgClr, [], [], [], [], 4);
    hz=Screen('NominalFrameRate', wpnt);
    Priority(1);
    Screen('BlendFunction', wpnt, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    Screen('Preference', 'TextAlphaBlending', 1);
    Screen('Preference', 'TextAntiAliasing', 2);
    % This preference setting selects the high quality text renderer on
    % each operating system: It is not really needed, as the high quality
    % renderer is the default on all operating systems, so this is more of
    % a "better safe than sorry" setting.
    Screen('Preference', 'TextRenderer', 1);
    KbName('UnifyKeyNames');    % for correct operation of the setup/calibration interface, calling this is required
    esc = KbName('ESCAPE');

    vp = VideoPlayer(wpnt,vids);
    vp.start();
    
    tex = 0;
    while true
        newTex = vp.getFrame();
        if newTex>0
            if tex>0
                Screen('Close', tex);
            end
            tex = newTex;
        end
        if tex>0
            Screen('DrawTexture', wpnt, tex);
        end
        Screen('Flip', wpnt);

        [keyIsDown,secs,keyCode]=KbCheck;
        if (keyIsDown==1 && keyCode(esc))
            % Set the abort-demo flag.
            break;
        end
    end
    vp.stop();
    delete(vp)

catch me
    sca
    try
        delete(vp)
    catch
    end
    rethrow(me)
end
sca