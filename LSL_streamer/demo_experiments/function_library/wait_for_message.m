function out = wait_for_message(prefix, inlets, exit_key, is_json)
if nargin<3
    exit_key = '';
end
if nargin<4
    is_json = false;
end
if ~iscell(inlets)
    inlets = {inlets};
end
inlets_to_go = [1:length(inlets)];
out = cell(size(inlets_to_go));
while true
    for i=inlets_to_go
        msg = inlets{i}.pull_sample(0.0);

        if ~isempty(msg) && startsWith(msg{1},prefix)
            inlets_to_go(inlets_to_go==i) = [];
            the_msg = msg{1}(length(prefix)+1:end);
            if isempty(the_msg)
                out{i} = '';
            elseif is_json
                out{i} = jsondecode(the_msg(2:end));
            else
                out{i} = strsplit(the_msg(2:end),',');
            end
        end
    end

    % Break if message has been received from all inlets
    if isempty(inlets_to_go)
        break
    end
    if ~isempty(exit_key)
        [~, ~, keyCode] = KbCheck();
        keys = KbName(keyCode);
        if ~isempty(keys)
            if ~iscell(keys)
                keys = {keys};
            end
            if any(strcmpi(keys,exit_key))
                break
            end
        end
    end
    
    WaitSecs('YieldSecs',0.01);
    % A tribute to Windows: A useless call to GetMouse to trigger
    % Screen()'s Windows application event queue processing to avoid
    % white-death due to hitting the "Application not responding" timeout:
    if IsWin
        GetMouse;
    end
end

if isscalar(inlets)
    out = out{1};
end