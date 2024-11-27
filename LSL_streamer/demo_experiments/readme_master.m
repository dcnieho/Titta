% this demo code is part of Titta, a toolbox providing convenient access to
% eye tracking functionality using Tobii eye trackers
%
% Titta can be found at https://github.com/dcnieho/Titta. Check there for
% the latest version.
% When using Titta, please cite the following paper:
%
% Niehorster, D.C., Andersson, R. & Nystrom, M., (2020). Titta: A toolbox
% for creating Psychtoolbox and Psychopy experiments with Tobii eye
% trackers. Behavior Research Methods.
% doi: https://doi.org/10.3758/s13428-020-01358-8
%
% To run this experiment, refer to the README here:
% https://github.com/dcnieho/Titta/blob/master/LSL_streamer/demo_experiments/README.md
%
% Note that a Python version of this demo is available here:
% https://github.com/marcus-nystrom/Titta/tree/master/playground These
% Python versions are interoperable with the MATLAB version. You can freely
% mix Python and MATLAB clients and masters.

clear all

% ensure LSL libraries and functions for this demo are on path
addpath(genpath('function_library'));
addpath(genpath('liblsl_Matlab'));
% load LSL
lslLib = lsl_loadlib();
fprintf('Using LSL v%d\n',lsl_library_version(lslLib));


% Open a communication channel for sending commands to clients
info = lsl_streaminfo(lslLib, 'Wally_finder', 'Wally_master', 1, 0, 'cf_string', 'Wally_finder_master');
to_clients = lsl_outlet(info,1);

% Find all clients
fprintf('Connecting to clients... Press q to start with the connected clients\n');
clients = cell(0,2);
while true
    found_streams = lsl_resolve_byprop(lslLib, 'type', 'Wally_client', 0, .1);
    for f=1:length(found_streams)
        h = lsl_get_hostname(found_streams{f}.LibHandle,found_streams{f}.InfoHandle);
        if ~any(strcmp(clients(:,1),h))
            clients(end+1,:) = {h, lsl_inlet(found_streams{f})};
            fprintf('client connected: %s (%s)\n',h,found_streams{f}.source_id);
            fprintf('connected clients: %s\n',strjoin(sort(clients(:,1)), ', '));
        end
    end
    
    if checkKeyDown('q')
        break
    end
    WaitSecs('YieldSecs', 0.1);
end
fprintf('running with clients: %s\n',strjoin(sort(clients(:,1)), ', '));

% ensure we're properly connected to each client
for c=1:size(clients,1)
    warm_up_bidirectional_comms(to_clients, clients{c,2});
end

% get information about the connected eye tracker from each client
to_clients.push_sample({'get_eye_tracker'})
remote_eye_trackers = wait_for_message('eye_tracker', clients);
for e=1:size(remote_eye_trackers,1)
    fprintf('%s (%s @ %s)\n',remote_eye_trackers{e,1},remote_eye_trackers{e,2}{:});
end

% Wait to receive information about calibration results
cal_results = wait_for_message('calibration_done', clients, 'c', [], true);
for c=1:size(cal_results,1)
    if isempty(cal_results{c,2})
        fprintf('%s: no calibration result received\n',cal_results{c,1});
    else
        fprintf('%s: %s, %s\n',cal_results{c,1},cal_results{c,2}{:});
    end
end

% remove clients who dropped out (didn't return a calibration result)
to_drop = cellfun(@isempty,cal_results(:,2));
clients(to_drop,:) = [];
to_drop = ~ismember(remote_eye_trackers(:,1),clients(:,1));
remote_eye_trackers(to_drop,:) = [];
fprintf('running with clients: %s\n',strjoin(sort(clients(:,1)), ', '));

% Tell clients which other clients they should connect to
for c=1:size(clients,1)
    client = clients{c,1};
    iToConnect = find(~strcmp(clients(:,1),client));
    to_connect = cell(1,length(iToConnect));
    for c2=1:length(iToConnect)
        qRemote = strcmp(remote_eye_trackers(:,1),clients{iToConnect(c2),1});
        to_connect{c2} = [remote_eye_trackers(qRemote,1),remote_eye_trackers{qRemote,2}];
    end
    msg = sprintf('connect_to,%s,%s',client,jsonencode(to_connect));
    to_clients.push_sample({msg})
end

% wait for all clients to be ready
wait_for_message('ready_to_go', clients, [], [], true);

% Start experiment
fprintf('Press ''g'' to start experiment\n');
while true
    if checkKeyDown('g')
        break
    end
    WaitSecs('YieldSecs',.01);
end
to_clients.push_sample({'start_exp'})

% Wait to receive information about search times
search_times = wait_for_message('search_time', clients, 'x', true, [], @(h) tell_to_disconnect(to_clients, h));

% Print reaction times and winners
fprintf('search times:\n')
qEmpty = cellfun(@isempty,search_times(:,2));
search_times(qEmpty,2) = {nan};
[~,i] = sort([search_times{:,2}]);
search_times = search_times(i,:);
for s=1:size(search_times,1)
    extra = '';
    if isfinite(search_times{s,2})
        extra = 's';
    end
    fprintf('%s: %.2f%s\n',search_times{s,:},extra);
end