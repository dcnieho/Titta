classdef TalkToProLab < handle
    properties (Access = protected, Hidden = true)
        % websocket connections we need
        clientClock;
        clientProject;
        clientEP;
    end
    
    properties (SetAccess=protected)
        projectID;
        participantID;
        recordingID;
    end
    
    % computed properties (so not actual properties)
    properties (Dependent, SetAccess = private)
    end
    
    methods
        function this = TalkToProLab()
            % connect to needed Pro Lab Services
            this.clientClock    = SimpleWSClient('ws://localhost:8080/clock?client_id=TittaMATLAB');
            this.clientProject  = SimpleWSClient('ws://localhost:8080/project?client_id=TittaMATLAB');
            this.clientEP       = SimpleWSClient('ws://localhost:8080/record/externalpresenter?client_id=TittaMATLAB');
            
            % for each, check API semver major version
            % TODO: put current version numbers in the below warnings, 1.0
            % is placeholder
            % 1. clock service
            this.clientClock.send(struct('operation','GetApiVersion'));
            resp    = waitForResponse(this.clientClock,'GetApiVersion');
            fprintf('TalkToProLab: using clock API version %s\n',resp.version);
            vers    = sscanf(resp.version,'%d.%d').';
            expected= 1;
            if vers(1)~=expected
                warning('TalkToProLab is compatible with Tobii Pro Lab''s clock API version 1.0, your Pro Lab provides version %s. If the code does not crash, check carefully that it works correctly',resp.version);
            end
            % 2. project service
            this.clientProject.send(struct('operation','GetApiVersion'));
            resp    = waitForResponse(this.clientProject,'GetApiVersion');
            fprintf('TalkToProLab: using project API version %s\n',resp.version);
            vers    = sscanf(resp.version,'%d.%d').';
            expected= 1;
            if vers(1)~=expected
                warning('TalkToProLab is compatible with Tobii Pro Lab''s project API version 1.0, your Pro Lab provides version %s. If the code does not crash, check carefully that it works correctly',resp.version);
            end
            % 3. external presenter service
            this.clientEP.send(struct('operation','GetApiVersion'));
            resp    = waitForResponse(this.clientEP,'GetApiVersion');
            fprintf('TalkToProLab: using external presenter API version %s\n',resp.version);
            vers    = sscanf(resp.version,'%d.%d').';
            expected= 1;
            if vers(1)~=expected
                warning('TalkToProLab is compatible with Tobii Pro Lab''s external presenter API version 1.0, your Pro Lab provides version %s. If the code does not crash, check carefully that it works correctly',resp.version);
            end
            
            % check our local clock is the same as the ProLabClock. for now
            % we do not support it when they aren't (e.g. running lab on a
            % different machine than the stimulus presentation machine)
            nTimeStamp = 40;
            [timesPTB,timesLab] = deal(zeros(nTimeStamp,1,'int64'));
            request = matlab.internal.webservices.toJSON(struct('operation','GetTimestamp'));   % save conversion-to-JSON overhead so below requests are fired asap
            % ensure response is cleared
            [~] = this.clientClock.lastRespText;
            for p=1:nTimeStamp
                if mod(p-1,10)<5
                    PTBtime = GetSecs;
                    this.clientClock.send(request);
                else
                    this.clientClock.send(request);
                    PTBtime = GetSecs;
                end
                % prep PTB timestamp
                timesPTB(p) = int64(PTBtime*1000*1000);
                % wait for response
                resp = waitForResponse(this.clientClock,'GetTimestamp');
                timesLab(p) = sscanf(resp.timestamp,'%ld');
            end
            % get rough estimate of clock offset (note this is includes
            % half RTT which is not taken into account, thats ok for our
            % purposes)
            assert(mean(timesLab-timesPTB)<2500,'clock offset between PsychToolbox and Pro Lab is more than 2.5 ms: either the two are not using the same clock (unsupported) or you are running PsychToolbox and Pro Lab on different computers (also unsupported)')
            
            % get info about opened project
            this.clientProject.send(struct('operation','GetProjectInfo'));
            resp = waitForResponse(this.clientProject,'GetProjectInfo');
            this.projectID = resp.project_id;
            fprintf('Connected to Tobii Pro Lab, currently opened project is ''%s'' (%s)\n',resp.project_name,resp.project_id);
        end
        
        function participantID = createParticipant(this,name,allowExisting)
            if nargin<3 || isempty(allowExisting)
                allowExisting = false;
            end
            % get list of existing participants, see if one with name
            % already exists
            this.clientProject.send(struct('operation','ListParticipants'));
            resp = waitForResponse(this.clientProject,'ListParticipants');
            names = {resp.participant_list.participant_name};
            qPart = strcmp(names,name);
            assert(~any(qPart)||allowExisting,'Participant with name ''%s'' already exists',name)
            
            if any(qPart)
                % use existing
                participantID = resp.participant_list(qPart).participant_id;
            else
                % make new
                this.clientProject.send(struct('operation','AddParticipant','participant_name',name));
                resp = waitForResponse(this.clientProject,'AddParticipant');
                participantID = resp.participant_id;
            end
            this.participantID = participantID;
        end
        
        function ID = uploadStimulus(this,fileNameOrArray,name)
        end
        
        function ID = findStimulus(this,name)
            this.clientProject.send(struct('operation','ListMedia'));
            resp = waitForResponse(this.clientProject,'ListMedia');
            names = {resp.media_list.media_name};
            qPart = strcmp(names,name);
        end
    end
    
    methods (Access=private, Hidden=true)
    end
end

% for complicated messages, perhaps provide users with an empty template.
% like AOI:
% fid=fopen('C:\Users\Administrator\Desktop\json.txt','rt');
% str=fread(fid,inf,'*char').'
% fclose(fid);
% matlab.internal.webservices.fromJSON(str)


%%% helpers
function resp = waitForResponse(connection, operation, pauseDur)
if nargin<3 || isempty(pauseDur)
    pauseDur = 0.001;
end
% wait for response
resp = connection.lastRespText;
while isempty(resp) || ~(resp.status_code~=0 || strcmp(resp.operation,operation))
    resp = connection.lastRespText;
    pause(pauseDur);
end

if resp.status_code
    reason = '';
    if isfield(resp,'reason')
        reason = sprintf(': %s',resp.reason);
    end
    error('Command ''%s'' returned an error: %d (%s)%s',operation,resp.status_code,statusToText(resp.status_code),reason);
end
end

function str = statusToText(status)
switch status
    case 0
        str = 'Operation successful';
    case 100
        str = 'Bad request';
    case 101
        str = 'Invalid parameter';
    case 102
        str = 'Operation was unsuccessful';
    case 103
        str = 'Operation cannot be executed in current state';
    case 104
        str = 'Access to the service is forbidden';
    case 105
        str = 'Authorization during connection to a service has not been provided';
    case 201
        str = 'Recording finalization failed';
    otherwise
        str = '!!unknown status code';
end
end