function deplaat = tekenAOIsinplaat(deplaat,q,klr,t)
% deplaat = tekenAOIsinplaat(deplaat,q,klr,t)
%
% Neemt een AOI boolean matrix (een matrix met dezelfde resolutie als het
% trackscherm die true is waar zich een AOI bevindt en false waar geen AOI
% is) en plot deze in de plaat. Daar waar zich een AOI bevindt wordt de
% opgegeven kleur met een bepaalde transparatie waarde over het plaatje
% gelegd, de rest van het plaatje blijft ongemoeid. De rand wordt met t(2)
% geschreven, en de rest van de AOI met t(1)

assert(all(AltSize(deplaat,[1 2])==size(q)),'plaat and mask do not match in size')
if size(deplaat,3)==1
    deplaat = repmat(deplaat,[1 1 3]);
end
if isa(deplaat,'uint16')
    deplaat = uint8(deplaat ./ 256);
end

if ~isscalar(t) && exist('bwperim','file')==2
    % get perimeter
    perim = bwperim(q,8);
    inner = q & ~perim;

    deplaat = transBoolean(deplaat,inner,klr,t(1));
    deplaat = transBoolean(deplaat,perim,klr,t(2));
else
    deplaat = transBoolean(deplaat,q,klr,t(1));
end



function deplaat = transBoolean(deplaat,q,klr,t)
temp            = zeros(size(deplaat,1),size(deplaat,2),3);
blank           = temp(:,:,1);

for p=1:3
    temp2       = blank;
    temp2(q)    = klr(p);
    temp(:,:,p) = temp2;
end

% maak een 3D boolean
q               = cat(3,q,q,q);


% tel de platen op
plaat           = uint8(round((1-t)*deplaat)) + uint8(round((t)*temp));     % let op het moet een 8-bitter blijven (vandaat uint8)

% vervang in de plaat alleen de pixels die boolean bevatten
deplaat(q)      = plaat(q);
