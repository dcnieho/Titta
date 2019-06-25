function drawfixpoint(wpnt,fp,eye)
% draws centered fixation cross on screen
%
% DRAWFIXCROSS(wpnt,xs,ys,lclr,lw,bgclr), with
% WPNT : PTB pointer produced by Screen('OpenWindow')
% TYPE : fixation cross '+' or dot '.'
% SZ   : point: diameter, cross: length of [horizontal vertical] legs,
%        Nonius square: square width, line length, square's line widht,
%        line's line width
% LCLR : cross color (scalar, [r g b] triplet or [r g b a] quadruple)
% LW   : cross legs' (line) width

type = fp.type;
sz   = fp.size;
lclr = fp.color;
fixPos = [fp.xPix fp.yPix];
  

% setup
switch type
    case '.'
        assert(isscalar(sz),'if drawing fixation type ''.'', size should be scalar')
    case '+'
        assert(isequal(sort(size(sz)),[1 3]),'if drawing fixation type ''+'', size should be 1x3')
        xs = sz(1);
        ys = sz(2); % sz(3) is line width
    case 'nsq'
        assert(isequal(sort(size(sz)),[1 4]),'if drawing fixation type ''nsq'', size should be 1x4')
    otherwise
        error('Fixation point type ''%s'' unknown',type);
end
sz = sz(:).';   % ensure row vector

% draw
switch type
    case '.'
        Screen('gluDisk', wpnt, lclr, fixPos(1), fixPos(2), sz/2);
    case '+'
        Screen('DrawLines', wpnt, [-xs/2 xs/2 0 0; 0 0 -ys/2 ys/2], sz(3), lclr, fixPos,2);
    case 'nsq'  % square with Nonius lines
        % sz = [square_width/height Nonius_line_length square_line_width Nonius_line_width] 
        % draw square (if you want dot in middle, just use the '.' type
        % above as well)
        Screen('DrawLines', wpnt, [-sz(1) sz([1 1 1 1]) -sz([1 1 1]); sz([1 1 1]) -sz([1 1 1 1]) sz(1)]./2, sz(3), lclr, fixPos,2);
        if eye==0 % left eye
            % draw left and lower Nonius lines
            Screen('DrawLines', wpnt, [-(sz(1)+sz(2))/2 -(sz(1)-sz(2))/2 0 0; 0 0  (sz(1)-sz(2))/2  (sz(1)+sz(2))/2], sz(4), lclr, fixPos,2);
        else % eye==1, right eye
            % draw right and upper Nonius lines
            Screen('DrawLines', wpnt, [ (sz(1)-sz(2))/2  (sz(1)+sz(2))/2 0 0; 0 0 -(sz(1)+sz(2))/2 -(sz(1)-sz(2))/2], sz(4), lclr, fixPos,2);
        end
end