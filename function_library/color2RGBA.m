function cout = color2RGBA(cin,q255,qCheck)
% process input
qCell = iscell(cin);
if ~qCell
    cin = {cin};
end
cellfun(@(x) validateattributes(x,{'numeric'},{'nonempty'},mfilename,'cin',1),cin)
if nargin<=2
    qCheck = false;
end
% decide whether full is 255 (8 bit color) or 1 (for float buffers)
if nargin<2 || isempty(q255) || q255
    a = 255;
else
    a = 1;
end

% process colors
qOK = true(size(cin));
cout= cell(size(cin));
for p=1:numel(cin)
    switch length(cin{p})
        case 1
            % luminance (L L L 1)
            cout{p} = [cin{p}([1 1 1]) a];
        case 2
            % luminance + alpha (L L L A)
            cout{p} = cin{p}([1 1 1 2]);
        case 3
            % RGB, add alpha (R G B 1)
            cout{p} = [cin{p} a];
        case 4
            % nothing to do
            cout{p} = cin{p};
        otherwise
            qOK(p) = false;
            if ~qCheck
                error('color2RGBA: color has wrong number of elements (%d), should be between 1--4\n',length(cin));
            end
    end
end

% if just checking, return whether ok instead of converted colors
if qCheck
    cout = qOK;
elseif ~qCell
    cout = cout{1};
end