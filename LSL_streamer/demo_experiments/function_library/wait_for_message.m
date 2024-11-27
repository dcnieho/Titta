function out = wait_for_message(prefix, inlets, exit_key, is_json, verbose, callback)
if nargin<3
    exit_key = '';
end
if nargin<4
    is_json = false;
end
if nargin<5
    verbose = false;
end
if nargin<6
    callback = [];
end
unpack_output = false;
if ~iscell(inlets)
    inlets = {'dummy', inlets};
    unpack_output = true;
end

extra = '';
if ~isempty(exit_key)
    extra = sprintf('. Press "%s" to continue', exit_key);
end
fprintf('waiting for "%s" messages%s\n', prefix, extra);

inlets_to_go = [1:size(inlets,1)];
out = [inlets(:,1) cell(size(inlets,1),1)];
while true
    for i=inlets_to_go
        msg = inlets{i,2}.pull_sample(0.0);

        if ~isempty(msg) && startsWith(msg{1},prefix)
            inlets_to_go(inlets_to_go==i) = [];
            the_msg = msg{1}(length(prefix)+1:end);
            if isempty(the_msg)
                out{i,2} = '';
            elseif is_json
                out{i,2} = jsondecode(the_msg(2:end));
            else
                out{i,2} = strsplit(the_msg(2:end),',');
            end
            if verbose
                if inlets_to_go
                    fprintf('still waiting for "%s" for: %s\n', prefix, strjoin(sort(inlets(inlets_to_go,1)), ', '));
                else
                    fprintf('received "%s" message from all clients\n', prefix);
                end
            end
            if ~isempty(callback)
                callback(inlets{i,1});
            end
        end
    end

    % Break if message has been received from all inlets
    if isempty(inlets_to_go)
        break
    end
    if ~isempty(exit_key)
        if checkKeyDown(exit_key)
            break
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

if unpack_output
    out = out{1,2};
end