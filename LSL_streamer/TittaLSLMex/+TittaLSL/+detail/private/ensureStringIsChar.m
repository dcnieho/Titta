function str = ensureStringIsChar(str)
if isa(str,'string')
    str = char(str);        % seems matlab also has a string type, shows up if user accidentally uses double quotes, convert to char
elseif iscell(str)
    str = cellfun(@ensureStringIsChar,str,'uni',false);
end