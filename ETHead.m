% This class is part of Titta, a toolbox providing convenient access to
% eye tracking functionality using Tobii eye trackers
%
% Titta can be found at https://github.com/dcnieho/Titta. Check there for
% the latest version.
% When using Titta, please cite the following paper:
% Niehorster, D.C., Andersson, R. & Nyström, M., (in prep). Titta: A
% toolbox for creating Psychtoolbox and Psychopy experiments with Tobii eye
% trackers.
%
% To run demo, simply call ETHead() with no input arguments.

classdef ETHead < handle
    properties
        % setup head position visualization
        distGain            = 1.8;
        distGainGP          = 1;
        eyeSzFac            = .25;
        eyeMarginFac        = .25;
        pupilSzFac          = .50;
        pupilRefDiam        = 5;        % mm
        pupilSzGain         = 1.5;
        yawFac              = 1.25;     % exaggerate yaw head depth rotation a bit, looks more like the eye images and simply makes it more visible
        pitchFac            = 1;
        
        refSz;
        rectWH;
        
        headCircleFillClr   = [255 255 0 .3*255];
        headCircleEdgeClr   = [255 255 0];
        headCircleEdgeWidth = 5;
        
        crossEye            = 0;   % 0: none, 1: replace left eye with cross, 2: replace right eye with cross
        
        showEyes            = true;
        showPupils          = true;
        showYaw             = true;
        
        crossClr            = [255 0 0];
        eyeClr              = 255;
        pupilClr            = 0;
        
        referencePos;
        allPosOff           = [0 0];
    end
    
    properties (SetAccess=private)
        wpnt;
        eyeDist             = 6.2;
        nEyeDistMeasures    = 0;
        avgX
        avgY
        avgDist
        Rori                = [1 0; 0 1];
        yaw                 = 0;
        pitch               = 0;
        eyeDistGuidePos     = 0.1375;   % kinda arbitrary value to use when eyeDistGuidePos has not been measured yet
        RoriGP              = [1 0; 0 1];
        yawGP               = 0;
        dZ                  = 0;
        dZGP                = 0;
        headPos
        drawYaw             = 0;
    end
    
    properties (Access=private, Hidden=true)
        qFloatColorRange
        trackBoxHalfWidth
        trackBoxHalfHeight
        qHaveLeft
        qHaveRight
        lPup
        rPup
        headSz
        circVerts
    end
    
    methods
        function this = ETHead(wpnt,trackBoxHalfWidth,trackBoxHalfHeight)
            if nargin==0
                % run demo
                ETHead.showDemo();
            else
                this.wpnt                   = wpnt;
                this.qFloatColorRange       = Screen('ColorRange',this.wpnt)==1;
                this.trackBoxHalfWidth      = trackBoxHalfWidth;
                this.trackBoxHalfHeight     = trackBoxHalfHeight;
                
                this.circVerts              = genCircle(200);
            end
        end
        
        function update(this,...
                 leftOriginValid, leftGazeOriginUCS, leftGuidePos, leftPupilDiameter,...
                rightOriginValid,rightGazeOriginUCS,rightGuidePos, rightPupilDiameter, pitch)
            
            % pitch cannot be computed from these inputs, but can be
            % provided if known from another source. Pitch is in degrees,
            % and applied after yaw. Roll is applied last, by simply
            % rotating projection plane
            if nargin>=10
                this.pitch = pitch/180*pi;
            else
                this.pitch = 0;
            end
            
            [lEye,rEye] = deal(nan(3,1));
            if isempty(leftGuidePos)
                [leftGuidePos,rightGuidePos] = deal(nan(3,1));
            end
            this.qHaveLeft   = ~isempty(leftOriginValid) && ~~leftOriginValid;
            if this.qHaveLeft
                lEye        = leftGazeOriginUCS;
                this.lPup   = leftPupilDiameter;
            end
            this.qHaveRight  = ~isempty(rightOriginValid) && ~~rightOriginValid;
            if this.qHaveRight
                rEye        = rightGazeOriginUCS;
                this.rPup   = rightPupilDiameter;
            end
            
            % get average eye distance. use distance from one eye if only one eye
            % available
            dists   = [lEye(3) rEye(3)]./10;
            Xs      = [lEye(1) rEye(1)]./10;
            Ys      = [lEye(2) rEye(2)]./10;
            if all([this.qHaveLeft this.qHaveRight])
                % get orientation of eyes in X-Y plane
                dX          = diff(Xs);
                dY          = diff(Ys);
                this.dZ     = diff(dists);
                this.yaw    = atan2(this.dZ,dX);
                roll        = atan2(     dY,dX);
                this.Rori   = [cos(roll) sin(roll); -sin(roll) cos(roll)];
                
                % update eye distance measure (maintain running
                % average). NB: ignoring dY leads to a more stable
                % visualization, so we're doing that.
                this.nEyeDistMeasures = this.nEyeDistMeasures+1;
                this.eyeDist          = (this.eyeDist*(this.nEyeDistMeasures-1)+hypot(dX,this.dZ))/this.nEyeDistMeasures;
            end
            % if we have guide positions, also keep track of eye distance
            % in there. This is not perfect as distance between eyes scales
            % with physical distance to eye tracker in this coordinate
            % system (and later possibly in more complex ways), but for
            % head position visualization it is better to do this than to
            % not do it at all.
            if ~isnan(leftGuidePos(1)) && ~isnan(rightGuidePos(1))
                dXGP                    = diff([leftGuidePos(1) rightGuidePos(1)]);
                dYGP                    = diff([leftGuidePos(2) rightGuidePos(2)]);
                this.dZGP               = diff([leftGuidePos(3) rightGuidePos(3)]);
                this.eyeDistGuidePos    = this.eyeDistGuidePos/2 + hypot(dXGP,hypot(dYGP,this.dZGP))/2; % take equally weighted average of previous and current provides stable visualization
                this.yawGP              = atan2(this.dZGP,dXGP);
                rollGP                  = atan2(     dYGP,dXGP);
                this.RoriGP             = [cos(rollGP) sin(rollGP); -sin(rollGP) cos(rollGP)];
            end
            % if we have only one eye, make fake second eye
            % position so drawn head position doesn't jump so much.
            off   = this.Rori*[this.eyeDist; 0];
            if ~this.qHaveLeft
                Xs(1)   = Xs(2)   -off(1);
                Ys(1)   = Ys(2)   +off(2);
                dists(1)= dists(2)-this.dZ;
            elseif ~this.qHaveRight
                Xs(2)   = Xs(1)   +off(1);
                Ys(2)   = Ys(1)   -off(2);
                dists(2)= dists(1)+this.dZ;
            end
            % same for guidepos-based head position (see discussion above
            % in code block where this.eyeDistGuidePos is determined).
            offGP = this.RoriGP*[this.eyeDistGuidePos; 0];
            if isnan(leftGuidePos)
                leftGuidePos(1)     = rightGuidePos(1) -offGP(1);
                leftGuidePos(2)     = rightGuidePos(2) +offGP(2);
                leftGuidePos(3)     = rightGuidePos(3) -this.dZGP;
            elseif ~this.qHaveRight
                rightGuidePos(1)    = leftGuidePos(1)  +offGP(1);
                rightGuidePos(2)    = leftGuidePos(2)  -offGP(2);
                rightGuidePos(3)    = leftGuidePos(3)  +this.dZGP;
            end
            % determine head position in user coordinate system
            this.avgX    = mean(Xs(~isnan(Xs))); % on purpose isnan() instead of qHave, as we may have just repaired a missing Xs and Ys above
            this.avgY    = mean(Ys(~isnan(Xs)));
            this.avgDist = mean(dists(~isnan(Xs)));
            % determine visualized head position based on this
            % if reference position given, use it
            if ~any(isnan(this.referencePos))
                if isempty(this.trackBoxHalfWidth)
                    % We don't know size of the trackBox. Use trackbox
                    % dimension of Spectrum. Although probably not
                    % appropriate for the connected eye tracker, it doesn't
                    % matter: we just need to scale horizontal and vertical
                    % offset from reference position for illustration
                    % purposes. As long as offsets are clearly seen, we're
                    % ok.
                    avgXtb  = (this.avgX-this.referencePos(1))/14   /2+.5;
                    avgYtb  = (this.avgY-this.referencePos(2))/11.25/2+.5;
                else
                    avgXtb  = (this.avgX-this.referencePos(1))/this.trackBoxHalfWidth /2+.5;
                    avgYtb  = (this.avgY-this.referencePos(2))/this.trackBoxHalfHeight/2+.5;
                end
                avgYtb  = 1-avgYtb;    % 1-Y to flip direction (positive UCS is upward, should be downward for drawing on screen)
                fac     = this.avgDist/this.referencePos(3);
                dGain   = this.distGain;
                if this.showYaw
                    this.drawYaw = this.yaw;
                end
            else
                % if we don't have a reference position, that means we only
                % have the position guide to go on
                % this is not perfectly jump-proof when one eye is lost. So
                % be it
                avgXtb  = 1-mean([leftGuidePos(1) rightGuidePos(1)],'omitnan');
                avgYtb  =   mean([leftGuidePos(2) rightGuidePos(2)],'omitnan');
                avgZtb  =   mean([leftGuidePos(3) rightGuidePos(3)],'omitnan');
                fac     = avgZtb+.5;    % make 1 the ideal position, less than 1 too close, more too far
                dGain   = this.distGainGP;
                if this.showYaw
                    this.drawYaw = this.yawGP;
                end
            end
            
            % scale up size of oval. define size/rect at standard distance, have a
            % gain for how much to scale as distance changes
            if ~isnan(this.avgDist)
                pos             = [avgXtb avgYtb];
                % determine size of head, based on distance from reference distance
                this.headSz     = this.refSz - this.refSz*(fac-1)*dGain;
                % move
                this.headPos    = pos.*this.rectWH + this.allPosOff;
            else
                this.headPos    = [];
            end
        end
        
        function draw(this)
            if ~isempty(this.headPos)
                oris = [this.yaw this.pitch].*[this.yawFac this.pitchFac];
                % draw head
                drawOrientedPoly(this.wpnt,this.circVerts,1,oris,this.Rori,this.headSz,this.headPos,this.getColorForWindow(this.headCircleFillClr),this.getColorForWindow(this.headCircleEdgeClr),this.headCircleEdgeWidth);
                if this.showEyes
                    for e=1:2
                        eyeOff = [this.eyeMarginFac*2;0];               % *2 because all sizes are radii
                        if e==1
                            % left eye
                            pup     = this.lPup;
                            eyeOff  = -eyeOff;
                        else
                            % right eye
                            pup     = this.rPup;
                        end
                        if e==this.crossEye
                            % draw cross indicating not being calibrated
                            cross = [cosd(45) sind(45); -sind(45) cosd(45)]*[1 1 4 4 1 1 -1 -1 -4 -4 -1 -1; 4 1 1 -1 -1 -4 -4 -1 -1 1 1 4]/4*this.eyeSzFac + eyeOff;
                            drawOrientedPoly(this.wpnt,cross,0,oris,this.Rori,this.headSz,this.headPos,this.getColorForWindow(this.crossClr));
                        elseif (e==1 && this.qHaveLeft) || (e==2 && this.qHaveRight)
                            % draw eye
                            eye = bsxfun(@plus,this.eyeSzFac*this.circVerts,eyeOff);
                            drawOrientedPoly(this.wpnt,eye,1,oris,this.Rori,this.headSz,this.headPos,this.getColorForWindow(this.eyeClr));
                            % if wanted, draw pupil
                            if this.showPupils
                                pupilSz = (1+(pup/this.pupilRefDiam-1)*this.pupilSzGain)*this.pupilSzFac*this.eyeSzFac;
                                pup     = bsxfun(@plus,pupilSz*this.circVerts,eyeOff);
                                drawOrientedPoly(this.wpnt,pup,1,oris,this.Rori,this.headSz,this.headPos,this.getColorForWindow(this.pupilClr));
                            end
                        else
                            % draw line indicating closed/missing eye
                            line = bsxfun(@plus,[-1 1 1 -1; -1/5 -1/5 1/5 1/5]*this.eyeSzFac,eyeOff);
                            drawOrientedPoly(this.wpnt,line,1,oris,this.Rori,this.headSz,this.headPos,this.getColorForWindow(this.eyeClr));
                        end
                    end
                end
            end
        end
    end
    
    methods (Static)
        function showDemo()
            DEBUGlevel = 0;
            
            scr = max(Screen('Screens'));
            if DEBUGlevel>1
                % make screen partially transparent on OSX and windows vista or
                % higher, so we can debug.
                PsychDebugWindowConfiguration;
            end
            Screen('Preference', 'SyncTestSettings', 0.002);    % the systems are a little noisy, give the test a little more leeway
            [wpnt,winRect] = PsychImaging('OpenWindow', scr, 127, [], [], [], [], 4);
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
            Screen('TextSize',wpnt, 40);
            KbName('UnifyKeyNames');    % for correct operation of the setup/calibration interface, calling this is required
            
            % make ETHead
            head                = ETHead(wpnt,[],[]);
            head.rectWH         = winRect(3:4);
            head.refSz          = .1*winRect(3);
            head.referencePos   = [0 0 65]; % cm, note that position inputs to head.update are in mm, not cm
            
            % starting screen
            DrawFormattedText(wpnt,'This demo will show the below head animated in various ways. Press any key to continue to the next animation.','center',winRect(4)*.15,0,50);
            head.update(true, [0 0 650].', [], 5, true, [0 0 650].', [], 5);
            head.draw();
            Screen('Flip',wpnt);
            KbStrokeWait;
            
            % back and forth in depth, blinking eye
            range = [500 800];
            cps = 2/3;
            dphi= cps*2*pi;
            dt  = 1/hz;
            t   = 0;
            while true
                DrawFormattedText(wpnt,'Head moving back and forth in depth, eyes blinking.','center',winRect(4)*.15,0,50);
                normOff = sin(t*dphi);
                d = range(1) + diff(range)*(.5+normOff/2);
                head.update(normOff<=0, [0 0 d].', [], 5, normOff>0, [0 0 d].', [], 5);
                head.draw();
                Screen('Flip',wpnt);
                if KbCheck()
                    break;
                end
                t = t+dt;
            end
            KbWait([],1);
            
            % sideways around rotation point
            Rdist = 250;
            range = 15/180*pi;
            cps = 2/3;
            dphi= cps*2*pi;
            dt  = 1/hz;
            t   = 0;
            eyesPos = [-30 30;Rdist Rdist];
            while true
                DrawFormattedText(wpnt,'Head swinging left-to-right.','center',winRect(4)*.15,0,50);
                ori = range*sin(t*dphi);
                Rmat= [cos(ori) sin(ori); -sin(ori) cos(ori)];
                eyes= Rmat*eyesPos;
                eyes(2,:) = eyes(2,:)-Rdist;
                head.update(true, [eyes(:,1); 650], [], 5, true, [eyes(:,2); 650], [], 5);
                head.draw();
                Screen('Flip',wpnt);
                if KbCheck()
                    break;
                end
                t = t+dt;
            end
            KbWait([],1);
            
            % head yaw
            Rdist = 60;
            range = 35/180*pi;
            cps = 2/3;
            dphi= cps*2*pi;
            dt  = 1/hz;
            t   = 0;
            eyesPos = [-30 30;Rdist Rdist];
            while true
                DrawFormattedText(wpnt,'Head yaw.','center',winRect(4)*.15,0,50);
                ori = range*sin(t*dphi);
                Rmat= [cos(ori) sin(ori); -sin(ori) cos(ori)];
                eyes= Rmat*eyesPos;
                eyes(2,:) = eyes(2,:)-Rdist;
                head.update(true, [eyes(1,1) 0 650-eyes(2,1)].', [], 5, true, [eyes(1,2) 0 650-eyes(2,2)].', [], 5);
                head.draw();
                Screen('Flip',wpnt);
                if KbCheck()
                    break;
                end
                t = t+dt;
            end
            KbWait([],1);
            
            % head pitch
            Rdist   = 60;
            range   = 35/180*pi;
            cps     = 2/3;
            dphi    = cps*2*pi;
            dt      = 1/hz;
            t       = 0;
            while true
                DrawFormattedText(wpnt,'Head pitch.','center',winRect(4)*.15,0,50);
                ori = range*sin(t*dphi);
                Yoff= Rdist*sin(ori);
                Zoff= Rdist*cos(ori)-Rdist;
                head.update(true, [-30 Yoff 650+Zoff].', [], 5, true, [30 Yoff 650+Zoff].', [], 5, -ori*180/pi);
                head.draw();
                Screen('Flip',wpnt);
                if KbCheck()
                    break;
                end
                t = t+dt;
            end
            KbWait([],1);
            
            % pupils
            range = 2.5;
            cps = 2/3;
            dphi= cps*2*pi;
            dt  = 1/hz;
            t   = 0;  
            while true
                DrawFormattedText(wpnt,'Crazy pupils.','center',winRect(4)*.15,0,50);
                offset = range*sin(t*dphi);
                head.update(true, [0 0 650].', [], 5+offset, true, [0 0 650].', [], 5-offset);
                head.draw();
                Screen('Flip',wpnt);
                if KbCheck()
                    break;
                end
                t = t+dt;
            end
            KbWait([],1);
            
            % all together now
            Rdist1 = 250;
            range1 = 15/180*pi;
            Rdist2 = 60;
            range2 = 35/180*pi;
            rangep = 1.5;
            cps = 2/3;
            dphi= cps*2*pi;
            dt  = 1/hz;
            t   = 0;
            eyesPos1 = [-30 30;Rdist1 Rdist1];
            eyesPos2 = [-30 30;Rdist2 Rdist2];
            mode = 0;
            while true
                DrawFormattedText(wpnt,'All together now.','center',winRect(4)*.15,0,50);
                normOff = sin(t*dphi);
                Rmat1= [cos(range1*normOff) sin(range1*normOff); -sin(range1*normOff) cos(range1*normOff)];
                eyes1= Rmat1*eyesPos1;
                eyes1(2,:) = eyes1(2,:)-Rdist1;
                Rmat2= [cos(range2*normOff) sin(range2*normOff); -sin(range2*normOff) cos(range2*normOff)];
                if mode
                    Rmat2 = Rmat2';
                end
                eyes2= Rmat2*eyesPos2;
                eyes2(2,:) = eyes2(2,:)-Rdist2;
                
                head.update(true, [(eyes1(1,1)+eyes2(1,1))/2 eyes1(2,1) 650-eyes2(2,1)].', [], 5+rangep*normOff, true, [(eyes1(1,2)+eyes2(1,2))/2 eyes1(2,2) 650-eyes2(2,2)].', [], 5-rangep*normOff);
                head.draw();
                Screen('Flip',wpnt);
                if KbCheck()
                    mode=mode+1;
                    head.crossEye = 1;
                    KbWait([],1);
                    if mode==2
                        break;
                    end
                end
                t = t+dt;
            end
            
            sca
        end
    end
    
    methods (Access=private, Hidden=true)
        function clr = getColorForWindow(this,clr)
            if this.qFloatColorRange
                clr = double(clr)/255;
            end
        end
    end
end



% helpers
function verts = genCircle(nStep)
alpha = linspace(0,2*pi,nStep);
verts = [cos(alpha); sin(alpha)];
end