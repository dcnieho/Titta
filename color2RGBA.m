function cout = color2RGBA(cin,q255,qCheck)
validateattributes(cin,{'numeric'},{'nonempty'},mfilename,'cin',1)

% decide whether full is 255 (8 bit color) or 1 (for float buffers)
if nargin<2 || isempty(q255) || q255
    a = 255;
else
    a = 1;
end

switch length(cin)
    case 1
        % luminance (L L L 1)
        cout = [cin([1 1 1]) a];
    case 2
        % luminance + alpha (L L L A)
        cout = cin([1 1 1 2]);
    case 3
        % RGB, add alpha (R G B 1)
        cout = [cin a];
    case 4
        % nothing to do
        cout = cin;
    otherwise
        error('color2RGBA: color has wrong number of elements (%d), should be between 1--4\n',length(cin));
end

if nargin>2 && qCheck
    % called just to check input is convertible to color, return true when
    % we're here, as we've succeeded
    cout = true;
end