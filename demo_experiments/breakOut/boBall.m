classdef boBall < handle
    properties (SetAccess = private)
        pos;
        r;
        vel = [0 0];
        dt;
    end
    properties
        bounce      = 1;    % bounce coefficient (<1 is damped)
        drag        = 0;    % acceleration against movement direction
        gravity     = 0;    % downward acceleration
        friction    = 0;    % acceleration against motion along surface collided with, applied upon collision
    end
    
    methods
        function this = boBall(pos,radius,vel,dt)
            this.pos    = pos;
            this.r      = radius;
            if ~isempty(vel)
                this.vel    = vel;
            end
            this.dt     = dt;
        end
        
        function [whichCollided,colPos] = update(this,collObjects,idxReportAndRemove)
            whichCollided = [];
            colPos        = [];
            dtUsed        = 0;
            while true
                % already update velocities for all of timestep left. this is
                % conservative, check if collision can occur in this interval
                
                % update velocities given drag
                this.vel = this.vel.*(1-this.drag*(this.dt-dtUsed));
                % add effect of gravity
                this.vel(2) = this.vel(2)+this.gravity*(this.dt-dtUsed);
                % store velocity before any collision
                oldvelocity = this.vel;
                
                % check if colliding with any object, and if so, which
                intDt   = inf;
                intPos  = [];
                obj     = nan;
                for o=1:length(collObjects)
                    % early out when collision with this object is not
                    % possible
                    b_oVec = this.pos-collObjects(o).AABBmid;
                    dist = norm(b_oVec);
                    qInside = dist<collObjects(o).AABBhalfSize-this.r;
                    if ~qInside && dist>collObjects(o).AABBhalfSize-dot(this.vel*(this.dt-dtUsed),b_oVec./dist)+this.r
                        continue;
                    end
                    for l=1:length(collObjects(o).edges)
                        [lintDt,lintPos] = WhenMovingCircleWillIntersectLineSegment(this.pos, this.r, this.vel, collObjects(o).edges(l), min(intDt,this.dt-dtUsed));
                        if ~isempty(lintDt) && lintDt>0 && lintDt<intDt
                            intDt = lintDt;
                            intPos= lintPos;
                            obj   = o;
                        end
                    end
                end
                hasCollision = intDt<=(this.dt-dtUsed);   % can of course optimize this because as soon as ball is in flight, we know how many frames ahead the next collision will be. so don't need to test every frame
                
                % plot speed vector
                if hasCollision
                    % remove object collided with from set if we should
                    qObj = obj==idxReportAndRemove;
                    if any(qObj)
                        whichCollided = [whichCollided obj]; %#ok<AGROW>
                        idxReportAndRemove(qObj) = [];
                        collObjects(qObj) = [];
                    end
                    
                    % note collision position
                    colPos = [colPos; intPos]; %#ok<AGROW>
                    
                    % collision normal is always from touching point to center of circle
                    % (this is always perpendicular to edge for edges, and also correct for
                    % corner cases)
                    n = intPos - (this.pos+intDt*this.vel);
                    n = -n/norm(n);
                    
                    % get more accurate estimate of velocity at time of impact
                    % first roll back velocity change for full timestemp, and update to
                    % time until intersection, for somewhat more accurate simulation.
                    % This all remains a little off, but at sufficiently small
                    % timestep, thats unimportant
                    this.vel(2) = this.vel(2)-this.gravity*(this.dt-dtUsed);
                    this.vel = this.vel./(1-this.drag*(this.dt-dtUsed));
                    
                    this.vel = this.vel.*(1-this.drag*intDt);
                    % add effect of gravity
                    this.vel(2) = this.vel(2)+this.gravity*intDt;
                    
                    oldvelocity = this.vel;
                    
                    % now bounce, get new velocity vector
                    if 0 % bounce only
                        this.vel = this.vel-(1+this.bounce)*dot(this.vel,n).*n;
                    else % bounce and friction
                        Vperp    = dot(this.vel,n)*n;
                        this.vel = (1-this.friction)*this.vel + Vperp*this.friction - (1+this.bounce)*Vperp;
                    end
                    thisDt   = intDt;
                else
                    thisDt   = this.dt-dtUsed;
                end
                
                % move simulation forward to moment of contact
                this.pos = this.pos+oldvelocity*thisDt;
                dtUsed   = dtUsed+thisDt;
                if abs(dtUsed-this.dt)<this.dt*0.000001 % check if timestep is over
                    break;
                end
            end
        end
    end
    
    methods (Access = private, Hidden = true)
        
    end
end


% based on https://www.reddit.com/r/programming/comments/17wwv9/determining_exactly_ifwhenwhere_a_moving_line/c89o716
% Returns the first non-negative time, if any, where a moving circle will
% intersect a fixed line segment.
function [t,intPos] = WhenMovingCircleWillIntersectLineSegment(center, radius, velocity, line, maxDt)
% Point center, double radius, Vector velocity, LineSegment line
epsilon = 0.00001;
intPos  = [];

% use whatever's earliest and is actually touching
t1 = WhenMovingCircleWillIntersectExtendedLine(center, radius, velocity, line.p1, line.p2-line.p1);
t2 = WhenMovingCircleWillIntersectPoint(center, radius, velocity, line.p1);
t3 = WhenMovingCircleWillIntersectPoint(center, radius, velocity, line.p2);
t  = sort([t1 t2 t3]);
t  = t(t<=maxDt);

% of the touching ones, see which is first
while ~isempty(t)
    pos = center + velocity.*t(1);
    [d,intPos] = DistanceFrom(pos,line);
    if d > radius + epsilon
        % wrong result, remove
        t(1) = [];
    else
        t = t(1);
        break;
    end
end
end
    

% Returns the first non-negative time, if any, where a moving circle will
% intersect a fixed extended line.
function t = WhenMovingCircleWillIntersectExtendedLine(center, radius, velocity, pointOnLine, displacementAlongLine)
% Point center, double radius, Vector velocity, Point pointOnLine, Vector displacementAlongLine
a = PerpOnto(center-pointOnLine, displacementAlongLine);
if (dot(a,a) - radius^2 <= 0)
    % already touching at t=0
    t = 0;
    return;
else
    b = PerpOnto(velocity,displacementAlongLine);
    t = QuadraticRoots(dot(b,b), dot(a,b)*2, dot(a,a) - radius^2);
    t = min(t(t>=0)); % smallest that is equal to or larger than 0
end
end

% Returns the first non-negative time, if any, where a moving circle will
% intersect a fixed point.
function t = WhenMovingCircleWillIntersectPoint(center, radius, velocity, point)
% Point center, double radius, Vector velocity, Point point
a = center - point;
if (dot(a,a) - radius^2 <= 0)
    % already touching at t=0
    t = 0;
    return;
else
    b = velocity;
    t = QuadraticRoots(dot(b,b), dot(a,b)*2, dot(a,a) - radius^2);
    t = min(t(t>=0)); % smallest that is equal to or larger than 0
end
end

function vec = ProjectOnto(v, p)
% Vector v, Vector p
vec = p .* (dot(v,p) / dot(p,p));
end

function vec = PerpOnto(v, p)
% Vector v, Vector p
vec = v - ProjectOnto(v,p);
end

function [d,pos] = DistanceFrom(p, pointOrLine)
% 1: Point p,       Point pointOrLine, or
% 2: Point p, LineSegment pointOrLine
if isstruct(pointOrLine)
    % distance to line segment, also return the point on the line segment
    % that is closest
    s = LerpProjectOnto(p,pointOrLine);
    if (s < 0)
        pos = pointOrLine.p1;
    elseif (s > 1)
        pos = pointOrLine.p2;
    else
        pos = LerpAcross(pointOrLine,s);
    end
    d = DistanceFrom(p, pos);
else
    d = p - pointOrLine;
    d = hypot(d(1),d(2));
    pos = nan;
end
end

% The proportion that, when lerped across the given line, results in the
% given point. If the point is not on the line segment, the result is the
% closest point on the extended line (s<0 or s>1 in that case).
function s = LerpProjectOnto(point, line)
% Point point, LineSegment line
b = point   - line.p1;
d = line.p2 - line.p1;
s = dot(b, d) / dot(d, d);
end

function p = LerpAcross(line, proportion)
delta = line.p2-line.p1;
p = line.p1 + delta * proportion;
end

% Enumerates the real solutions to the formula a*x^2 + b*x + c = 0. Handles
% degenerate cases. If a=b=c=0 then only zero is enumerated, even though
% technically all real numbers are solutions.
function roots = QuadraticRoots(a, b, c)
roots = [];
% degenerate? (0x^2 + bx + c == 0)
if (a == 0)
    % double-degenerate? (0x^2 + 0x + c == 0)
    if (b == 0)
        % triple-degenerate? (0x^2 + 0x + 0 == 0)
        if (c == 0)
            % every other real number is also a solution, but hopefully one example will be fine
            roots = 0;
            return;
        end
        return;
    end
    
    roots = -c / b;
    return;
end

% ax^2 + bx + c == 0
% x = (-b +- sqrt(b^2 - 4ac)) / 2a

d = b^2 - 4 * a * c;
if (d < 0)
    return; % no real roots
end

s0 = -b / (2 * a);
sd = sqrt(d) / (2 * a);
roots(1) = s0 - sd;
if (sd == 0)
    % unique root
    return;
end
    
roots(2) = s0 + sd;
end