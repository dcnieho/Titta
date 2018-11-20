sca
clear variables

addpath(genpath(fullfile(cd,'..')));

qDEBUG = 0;

% look
bgclr               = 255/2;
blockFillClr        = [112 146 190];
blockEdgeClr        = [ 81 121 176];
paddleFillClr       = [208   0   0];

% setup eye tracker
settings = Titta.getDefaults('Tobii Pro Spectrum');
settings.cal.bgColor    = bgclr;
% custom calibration drawer
calViz = AnimatedCalibrationDisplay();
settings.cal.drawFunction = @calViz.doDraw;

% setup world
scr                 = max(Screen('Screens'));
scrRect             = Screen('Rect',scr);
fRate               = Screen('NominalFrameRate',scr);
XMIN                = scrRect(1);
YMIN                = scrRect(2);
XMAX                = scrRect(3);
YMAX                = scrRect(4);
width               = XMAX-XMIN;
height              = YMAX-YMIN;

% block setup
nBlockInRow         = 15;
nRow                = 3;
blockHeight         = height/20;
blockMargin         = height/10;        % space above top row of blocks
pointsPerBlock      = 5;

% paddle setup
paddleWidth         = width/12;
paddleBaseHeight    = height/30;
paddleCornerSlope   = 10;               % deg, away from horizontal
paddleMargin        = height/100;       % space below paddle

% ball
ballVel             = [0 -height/2];
ballRadius          = height/60;
ballFillClr         = [255 255 255];
ballAccel           = 0.015;


%% gen world
% bounds
worldBounds = boPolygon([XMIN XMAX XMAX XMIN; YMIN YMIN YMAX YMAX].');
% blocks
[vertsx,vertsy] = meshgrid(linspace(XMIN,XMAX,nBlockInRow+1),[0:nRow]*blockHeight+blockMargin);
for r=nRow:-1:1
    for c=nBlockInRow:-1:1
        poly = cat(3,vertsx(r:r+1,c:c+1),vertsy(r:r+1,c:c+1));
        poly = [poly(1,1,:) poly(1,2,:) poly(2,2,:) poly(2,1,:)];
        poly = permute(poly,[3 2 1]);
        
        idx = sub2ind([nRow nBlockInRow],r,c);
        blocks(idx) = boPolygon(poly.');
    end
end
% paddle
stepSz  = 5;
nStep   = paddleWidth/2/stepSz;
angles  = linspace(paddleCornerSlope,0,nStep+1); angles(end) = [];
segments= [stepSz*ones(1,nStep); stepSz*tand(angles)];
segments= [[0;0] cumsum(segments,2)];
segments= bsxfun(@minus,segments,[paddleWidth/2; 0]);
segments= [segments fliplr([-segments(1,1:end-1);segments(2,1:end-1)])];
bottom  = YMAX-paddleMargin;
poly    = [segments(1,:) paddleWidth/2 -paddleWidth/2; -segments(2,:)+bottom-paddleBaseHeight bottom bottom];
paddle  = boPolygon(poly.');
% ball
ballPos = [width/2 min(poly(2,:))-height/15];
randAng = RandLim(1,-30,30);
ballVel = ([cosd(randAng) -sind(randAng); sind(randAng) cosd(randAng)]*ballVel.').';
ball    = boBall(ballPos,ballRadius,ballVel,1/fRate);
ball.drag   = -ballAccel;



%% run
% TODO this must be wrong
addpath(genpath(fullfile(cd,'theToolbox')));

try 
    % init
    EThndl          = Titta(settings);
    % EThndl          = EThndl.setDummyMode();
    EThndl.init();
    
    
    if qDEBUG>1
        % make screen partially transparent on OSX and windows vista or
        % higher, so we can debug.
        PsychDebugWindowConfiguration;
    end
    Screen('Preference', 'SyncTestSettings', 0.002);    % the systems are a little noisy, give the test a little more leeway
    wpnt = PsychImaging('OpenWindow', scr, bgclr);
    Priority(1);
    Screen('BlendFunction', wpnt, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    Screen('Preference', 'TextAlphaBlending', 1);
    Screen('Preference', 'TextAntiAliasing', 2);
    % This preference setting selects the high quality text renderer on
    % each operating system: It is not really needed, as the high quality
    % renderer is the default on all operating systems, so this is more of
    % a "better safe than sorry" setting.
    Screen('Preference', 'TextRenderer', 1);
    
    % do calibration, start recording
    calValInfo = EThndl.calibrate(wpnt);
    EThndl.startRecording('gaze');
    
    paddlePos = XMAX/2;     % start in center of screen horizontally
    paddle.translate([paddlePos 0]);
    qWin = false;
    flips = [];
    while true
        [~,~,keyCode] = KbCheck;
        if KbMapKey(27,keyCode) % 27 is escape
            qSave = false;
            break;
        end
        
        % draw objects
        % 1. blocks
        for b=1:length(blocks)
            verts = blocks(b).vertices;
            Screen('FillPoly' ,wpnt,blockFillClr,verts,1);
            verts = verts+[1 -1 -1 1; 1 1 -1 -1].'*2;
            Screen('FramePoly',wpnt,blockEdgeClr,verts,2);
        end
        % 2. paddle
        Screen('FillPoly' ,wpnt,paddleFillClr,paddle.vertices,1);
        % 3. ball
        ballPos  = ball.pos;
        ballRect = CenterRectOnPointd([0 0 [2 2]*ball.r],ballPos(1),ballPos(2));
        Screen('FillOval', wpnt, ballFillClr, ballRect);
        
        flips(end+1) = Screen('Flip',wpnt);
        
        % update paddle
        % 1. get eye data, determine how far to move
        samp    = EThndl.consumeN('gaze');
        i = 0;
        if ~isempty(samp)
            i = length(samp.left.gazePoint.valid);
            while i>=1
                if samp.left.gazePoint.valid(i) || samp.right.gazePoint.valid(i)
                    break;
                end
                i = i-1;
            end
        end
        if i>0
            gazeX   = [samp.left.gazePoint.onDisplayArea(1,i) samp.right.gazePoint.onDisplayArea(1,i)];
            gazeX   = mean(gazeX(~isnan(gazeX)))*width;
            trans   = gazeX-paddlePos;
            % 2. clamp paddle position to play area
            if paddlePos+trans-paddleWidth/2<XMIN
                add = XMIN-(paddlePos+trans-paddleWidth/2);
                trans = trans+add;
            elseif paddlePos+trans+paddleWidth/2>XMAX
                sub = paddlePos+trans+paddleWidth/2 - XMAX;
                trans = trans-sub;
            end
            % 3. update its position
            paddlePos = paddlePos+trans;
            paddle.translate([trans 0]);
        end
        
        % update ball
        [collided,colPos] = ball.update([blocks worldBounds paddle],1:length(blocks));
        blocks(collided) = [];
        if isempty(blocks)
            % all blocks gone, done
            qWin = true;
            break;
        end
        if ~isempty(colPos) && any(colPos(:,2)==YMAX)
            % ball went off bottom of screen, you lost
            break;
        end
    end
    
    % stopping
    EThndl.stopRecording('gaze');
    
    % show performance feedback
    if qWin
        str = 'You won!';
    else
        str = 'Game over';
    end
    str = sprintf('<size=26>%s\n%d points',str,(nBlockInRow*nRow-length(blocks))*pointsPerBlock);
    if exist('libptbdrawtext_ftgl64.dll','file')
        % DrawFormattedText2 is 64bit matlab only (on Windows)
        DrawFormattedText2(str,'win',wpnt,'sx','center', 'sy','center', 'xalign','center', 'yalign','center','xlayout','center','baseColor',0);
    else
        % fallback for 32bit matlab on Windows (TODO: what to support on
        % the other platforms here)?
        DrawFormattedText2GDI(wpnt,str,'center','center','center','center','center',0);
    end
    Screen('Flip',wpnt);
    WaitSecs(3);
catch me
    sca
    rethrow(me)
end
% shut down
EThndl.deInit();
sca