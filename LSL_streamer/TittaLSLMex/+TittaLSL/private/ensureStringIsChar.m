function str = ensureStringIsChar(str)
if isa(str,'string')
    str = char(str);        % matlab also has a string type, which shows up if user accidentally uses double quotes. convert to char
elseif iscell(str)
    str = cellfun(@ensureStringIsChar,str,'uni',false);
end