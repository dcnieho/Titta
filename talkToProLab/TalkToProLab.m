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
        function this = TalkToProLab(expectedProject)
            % connect to needed Pro Lab Services
            this.clientClock    = SimpleWSClient('ws://localhost:8080/clock?client_id=TittaMATLAB');
            assert(this.clientClock.Status==1,'Could not connect to clock service, did you start Pro Lab and open a project?');
            this.clientProject  = SimpleWSClient('ws://localhost:8080/project?client_id=TittaMATLAB');
            assert(this.clientProject.Status==1,'Could not connect to project service, did you start Pro Lab and open an external presenter project?');
            this.clientEP       = SimpleWSClient('ws://localhost:8080/record/externalpresenter?client_id=TittaMATLAB');
            assert(this.clientEP.Status==1,'Could not connect to external presenter service, did you start Pro Lab and open a project?');
            
            % for each, check API semver major version
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
            assert(strcmp(resp.project_name,expectedProject),'You indicated that project ''%s'' should be open in Pro Lab, but instead project ''%s'' seems to be open',expectedProject,resp.project_name)
            this.projectID = resp.project_id;
            fprintf('Connected to Tobii Pro Lab, currently opened project is ''%s'' (%s)\n',resp.project_name,resp.project_id);
        end
        
        function delete(this)
            % clean up connections
            if ~isempty(this.clientClock) && this.clientClock.Status
                this.clientClock.close();
            end
            if ~isempty(this.clientProject) && this.clientProject.Status
                this.clientProject.close();
            end
            if ~isempty(this.clientEP) && this.clientEP.Status
                this.clientEP.close();
            end
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
        
        function mediaID = uploadMedia(this,fileNameOrArray,name)
            assert(ischar(fileNameOrArray),'uploadMedia: currently it is only supported to provide the filename (full path) to media to be uploaded, cannot upload raw image data');
            assert(exist(fileNameOrArray,'file')==2,'uploadMedia: provided file ''%s'' cannot be found. If you did not provide a full path, consider doing that',fileNameOrArray);
            
            % get mime type based on extension
            [~,~,ext] = fileparts(fileNameOrArray); if ext(1)=='.', ext(1) = []; end
            assert(~isempty(ext),'uploadMedia: file ''%s'' does not have extension, cannot deduce mime type',fileNameOrArray);
            switch lower(ext)
                case 'bmp'
                    mimeType = 'image/bmp';
                case {'jpg','jpeg'}
                    mimeType = 'image/jpeg';
                case 'png'
                    mimeType = 'image/png';
                case 'gif'
                    mimeType = 'image/gif';
                case 'mp4'
                    mimeType = 'video/mp4';
                case 'avi'
                    mimeType = 'video/x-msvideo';
                otherwise
                    error('uploadMedia: cannot deduce mime type from unknown extension ''%s''',ext);
            end
            
            % open file and get filesize
            fid = fopen(fileNameOrArray, 'rb');
            fseek(fid,0,'eof');
            sz = ftell(fid);
            % inform pro lab of what we're up to
            request = struct('operation','UploadMedia',...
                'mime_type', mimeType,...
                'media_name', name,...
                'media_size', sz...
                );
            this.clientProject.send(request);
            
            % now rewind and read in file
            fseek(fid,0,'bof');
            media = fread(fid,inf,'*uint8');
            fclose(fid);
            assert(sz==length(media));
            
            % wait till ready for upload to start
            waitForResponse(this.clientProject,'UploadMedia');
            
            % upload file in chunks
            chunkSz = 2^16;
            i = 1;
            while i<sz
                this.clientProject.send(media(i:min(i+chunkSz-1,end)));
                i = i+chunkSz;
            end
            
            % wait for successfully received message
            resp = waitForResponse(this.clientProject,'UploadMedia');
            mediaID = resp.media_id;
        end
        
        function mediaID = findMedia(this,name)
            this.clientProject.send(struct('operation','ListMedia'));
            resp = waitForResponse(this.clientProject,'ListMedia');
            if ~isempty(resp.media_list)
                names   = {resp.media_list.media_name};
                qMedia  = strcmp(names,name);
            end
        end
        
        function numAOI = attachAOI(this,stimID)
            % for complicated messages, perhaps provide users with an empty template.
            % like AOI:
            % fid=fopen('C:\Users\Administrator\Desktop\json.txt','rt');
            % str=fread(fid,inf,'*char').'
            % fclose(fid);
            % matlab.internal.webservices.fromJSON(str)
            resp = waitForResponse(this.clientProject,'AddAois');
        end
        
        function EPState = getExternalPresenterState(this)
            this.clientEP.send(struct('operation','GetState'));
            resp = waitForResponse(this.clientEP,'GetState');
            EPState = resp.state;
        end
        
        function recordingID = startRecording(this,name,scrWidth,scrHeight,scrLatency)
            request = struct('operation','StartRecording',...
                'recording_name',name,...
                'participant_id',this.participantID,...
                'screen_width',scrWidth,...
                'screen_height',scrHeight);
            if nargin>5 && ~isempty(scrLatency)
                request.screen_latency = scrLatency;
            end
            this.clientEP.send(request);
            resp            = waitForResponse(this.clientEP,'StartRecording');
            recordingID     = resp.recording_id;
            this.recordingID= recordingID;
        end
        
        function stopRecording(this)
            this.clientEP.send(struct('operation','StopRecording'));
            waitForResponse(this.clientEP,'StopRecording');
        end
        
        function finalizeRecording(this)
            this.clientEP.send(struct('operation','FinalizeRecording'));
            waitForResponse(this.clientEP,'FinalizeRecording');
            this.recordingID= '';
        end
        
        function discardRecording(this)
            this.clientEP.send(struct('operation','DiscardRecording'));
            waitForResponse(this.clientEP,'DiscardRecording');
            this.recordingID= '';
        end
        
        function sendStimulusEvent(this,mediaID,mediaPosition,startTimeStamp,endTimeStamp,background)
            % mediaPosition, endTimeStamp, background are optional
            if isnumeric(background)
                assert(numel(background)==3)
                background = reshape(dec2hex(background).',1,[]);
            end
        end
        
        function sendCustomEvent(this,timestamp,eventType,value)
        end
    end
    
    methods (Access=private, Hidden=true)
    end
end


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