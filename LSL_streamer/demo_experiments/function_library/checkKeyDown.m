function pressed = checkKeyDown(key)
pressed = false;
[~, ~, keyCode] = KbCheck();
keys = KbName(keyCode);
if ~isempty(keys)
    if ~iscell(keys)
        keys = {keys};
    end
    pressed = any(strcmpi(keys,key));
end