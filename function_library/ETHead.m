% shut up all warnings about accessing other class properties in a class's
% setter or getter
classdef ETHead < handle
    properties
        % setup head position visualization
        distGain    = 1.5;
        eyeSzFac    = .25;
        eyeMarginFac= .25;
        pupilSzFac  = .50;
        pupilRefDiam= 5;    % mm
        pupilSzGain = 1.5;
        
        refSz;
        rectWH;
        
        headCircleFillClr
        headCircleEdgeClr
        headCircleEdgeWidth = 5;
        
        crossEye = 0;   % 0: none, 1: replace left eye with cross, 2: replace right eye with cross
        
        showEyes
        showPupils
        
        crossClr
        eyeClr
        pupilClr
        
        referencePos;
        allPosOff = [0 0];
    end
    
    properties (SetAccess=private)
        wpnt;
        eyeDist             = 6.2;
        avgX
        avgY
        avgDist
        nEyeDistMeasures    = 0;
        Rori                = [1 0; 0 1];
        yaw                 = 0;
        dZ                  = 0;
        headPos
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
            this.wpnt                   = wpnt;
            this.qFloatColorRange       = Screen('ColorRange',this.wpnt)==1;
            this.trackBoxHalfWidth      = trackBoxHalfWidth;
            this.trackBoxHalfHeight     = trackBoxHalfHeight;
            
            this.circVerts              = genCircle(200);
        end
        
        function update(this,...
                 leftOriginValid, leftGazeOriginUCS, leftGuidePos, leftPupilDiameter,...
                rightOriginValid,rightGazeOriginUCS,rightGuidePos, rightPupilDiameter)
            
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
                % average)
                this.nEyeDistMeasures = this.nEyeDistMeasures+1;
                this.eyeDist          = (this.eyeDist*(this.nEyeDistMeasures-1)+hypot(dX,this.dZ))/this.nEyeDistMeasures;
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
            else
                % if we don't have a reference position, that means we only
                % have the position guide to go on
                % this is not jump-proof when one eye is lost. So be it
                avgXtb  = 1-mean([leftGuidePos(1) rightGuidePos(1)],'omitnan');
                avgYtb  =   mean([leftGuidePos(2) rightGuidePos(2)],'omitnan');
                avgZtb  =   mean([leftGuidePos(3) rightGuidePos(3)],'omitnan');
                fac     = avgZtb+.5;    % make 1 the ideal position, less than 1 too close, more too far
            end
            
            % scale up size of oval. define size/rect at standard distance, have a
            % gain for how much to scale as distance changes
            if ~isnan(this.avgDist)
                pos             = [avgXtb avgYtb];
                % determine size of head, based on distance from reference distance
                this.headSz     = this.refSz - this.refSz*(fac-1)*this.distGain;
                % move
                this.headPos    = pos.*this.rectWH + this.allPosOff;
            else
                this.headPos    = [];
            end
        end
        
        function draw(this)
            if ~isempty(this.headPos)
                % draw head
                drawOrientedPoly(this.wpnt,this.circVerts,1,this.yaw,this.Rori,this.headSz,this.headPos,this.getColorForWindow(this.headCircleFillClr),this.getColorForWindow(this.headCircleEdgeClr),this.headCircleEdgeWidth);
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
                            drawOrientedPoly(this.wpnt,cross,0,this.yaw,this.Rori,this.headSz,this.headPos,this.getColorForWindow(this.crossClr));
                        elseif (e==1 && this.qHaveLeft) || (e==2 && this.qHaveRight)
                            % draw eye
                            eye = bsxfun(@plus,this.eyeSzFac*this.circVerts,eyeOff);
                            drawOrientedPoly(this.wpnt,eye,1,this.yaw,this.Rori,this.headSz,this.headPos,this.getColorForWindow(this.eyeClr));
                            % if wanted, draw pupil
                            if this.showPupils
                                pupilSz = (1+(pup/this.pupilRefDiam-1)*this.pupilSzGain)*this.pupilSzFac*this.eyeSzFac;
                                pup     = bsxfun(@plus,pupilSz*this.circVerts,eyeOff);
                                drawOrientedPoly(this.wpnt,pup,1,this.yaw,this.Rori,this.headSz,this.headPos,this.getColorForWindow(this.pupilClr));
                            end
                        else
                            % draw line indicating closed/missing eye
                            line = bsxfun(@plus,[-1 1 1 -1; -1/5 -1/5 1/5 1/5]*this.eyeSzFac,eyeOff);
                            drawOrientedPoly(this.wpnt,line,1,this.yaw,this.Rori,this.headSz,this.headPos,this.getColorForWindow(this.eyeClr));
                        end
                    end
                end
            end
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