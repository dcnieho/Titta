function str = addToStruct(str,varargin)

fields= varargin(1:2:end);
vals  = varargin(2:2:end);
for p=1:length(vals)
    if ~iscell(vals{p})
        vals{p} = vals(p);
    end
end

% no error checking
for p=1:length(vals)
    [str.(fields{p})] = vals{p}{:};
end