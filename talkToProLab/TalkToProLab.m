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
            this.disconnect();
            this.projectID = '';
            this.participantID = '';
            this.recordingID = '';
        end
        
        function disconnect(this)
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
            resp    = waitForResponse(this.clientProject,'ListParticipants');
            names   = {resp.participant_list.participant_name};
            qPart   = strcmp(names,name);
            assert(~any(qPart)||allowExisting,'Participant with name ''%s'' already exists',name)
            
            if any(qPart)
                % use existing
                participantID   = resp.participant_list(qPart).participant_id;
            else
                % make new
                this.clientProject.send(struct('operation','AddParticipant','participant_name',name));
                resp            = waitForResponse(this.clientProject,'AddParticipant');
                participantID   = resp.participant_id;
            end
            this.participantID  = participantID;
        end
        
        function [mediaID,mediaInfo] = findMedia(this,name)
            mediaID     = '';   % empty means no media with that name was found
            mediaInfo   = [];
            this.clientProject.send(struct('operation','ListMedia'));
            resp = waitForResponse(this.clientProject,'ListMedia');
            if ~isempty(resp.media_list)
                names   = {resp.media_list.media_name};
                qMedia  = strcmp(names,name);
                if qMedia
                    mediaID     = resp.media_list(qMedia).media_id; % for convenience, provide direct mediaID output
                    mediaInfo   = resp.media_list(qMedia);
                end
            end
        end
        
        function [mediaID,wasUploaded] = uploadMedia(this,fileNameOrArray,name)
            % name must be unique, check, and return ID if already exists
            mediaID = this.findMedia(name);
            if ~isempty(mediaID)
                wasUploaded = false;
                return
            end
            
            qIsRawImage = ~ischar(fileNameOrArray);
            if qIsRawImage
                data            = fileNameOrArray;
                fileNameOrArray = [tempname() '.png'];
                imwrite(data,fileNameOrArray);
            else
                assert(exist(fileNameOrArray,'file')==2,'uploadMedia: provided file ''%s'' cannot be found. If you did not provide a full path, consider doing that',fileNameOrArray);
            end
            
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
                'mime_type' , mimeType,...
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
            
            % done sending all data, wait for message that media was
            % successfully received
            resp        = waitForResponse(this.clientProject,'UploadMedia');
            mediaID     = resp.media_id;
            wasUploaded = true;
            if qIsRawImage
                delete(fileNameOrArray);
            end
        end
        
        function success = attachAOIToImage(this,mediaName,aoiName,aoiColor,vertices,tags)
            % vertices should be 2xN
            [mediaID,mediaInfo] = this.findMedia(name);
            assert(~isempty(mediaID),'attachAOIToImage: no media with provided name, ''%s'' is known',mediaName)
            assert(~isempty(strfind(mediaInfo.mime_type,'image')),'attachAOIToImage: media with name ''%s'' is not an image, but a %s',mediaName,mediaInfo.mime_type)
            
            request = struct('operation','AddAois',...
                'media_id',mediaID,...
                'merge_mode','replace_aois');
            % build up AOI object
            AOI = struct('name',aoiName);
            % color
            if isnumeric(aoiColor)    % else we assume its a hexadecimal string already
                % turn into RGBA so that user can provide also single gray
                % value, etc
                aoiColor = round(color2RGBA(aoiColor));
                aoiColor = reshape(dec2hex(aoiColor(1:3)).',1,[]);
            end
            AOI.color = aoiColor;
            % vertices
            assert(size(vertices,1)==2,'attachAOIToImage: AOI vertices should be a 2xN array')
            nVert = size(vertices,2);
            AOI.keyframes{1}.is_active = true;
            AOI.keyframes{1}.seconds   = 0;
            AOI.keyframes{1}.vertices  = repmat(struct('x',0,'y',0),1,nVert);
            vertices = num2cell(vertices);
            [AOI.keyframes{1}.vertices.x] = vertices{1,:};
            [AOI.keyframes{1}.vertices.y] = vertices{2,:};
            % tags
            if nargin>5 && ~isempty(tags)
                if ~iscell(tags)
                    tags = num2cell(tags);
                end
                for t=1:length(tags)
                    if isempty(tags{t}.group_name)
                        tags{t} = rmfield(tags{t},'group_name');
                    end
                end
                AOI.tags = tags;
            else
                AOI.tags = {};
            end
            request.aois = {AOI};       % enclose in cell so it becomes a json array
            
            % send
            this.clientProject.send(request);
            resp    = waitForResponse(this.clientProject,'AddAois');
            success = resp.imported_aoi_count==1;
        end
        
        function numAOI = attachAOIToVideo(this,mediaName,request)
            % This function gives the user little help, and assumes that
            % they read the Tobii Pro Lab API and deliver a properly
            % formatted request. Request is the full struct to be converted
            % to json, except for the 'media_id', and 'operation', which
            % are added below
            [mediaID,mediaInfo] = this.findMedia(name);
            assert(~isempty(mediaID),'attachAOIToVideo: no media with provided name, ''%s'' is known',mediaName)
            assert(~isempty(strfind(mediaInfo.mime_type,'video')),'attachAOIToVideo: media with name ''%s'' is not an image, but a %s',mediaName,mediaInfo.mime_type)
            
            request.operation = 'AddAois';
            request.media_id  = mediaID;
            
            % send
            this.clientProject.send(request);
            resp    = waitForResponse(this.clientProject,'AddAois');
            numAOI  = resp.imported_aoi_count;
        end
        
        function EPState = getExternalPresenterState(this)
            this.clientEP.send(struct('operation','GetState'));
            resp    = waitForResponse(this.clientEP,'GetState');
            EPState = resp.state;
        end
        
        function recordingID = startRecording(this,name,scrWidth,scrHeight,scrLatency)
            % scrLatency is optional
            request = struct('operation','StartRecording',...
                'recording_name',name,...
                'participant_id',this.participantID,...
                'screen_width'  ,scrWidth,...
                'screen_height' ,scrHeight);
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
            this.clientEP.send(struct('operation','FinalizeRecording','recording_id',this.recordingID));
            waitForResponse(this.clientEP,'FinalizeRecording');
            this.recordingID= '';
        end
        
        function discardRecording(this)
            this.clientEP.send(struct('operation','DiscardRecording','recording_id',this.recordingID));
            waitForResponse(this.clientEP,'DiscardRecording');
            this.recordingID= '';
        end
        
        function sendStimulusEvent(this,mediaID,mediaPosition,startTimeStamp,endTimeStamp,background)
            % mediaPosition, endTimeStamp, background are optional, can be
            % left empty or not provided in call
            request = struct('operation','SendStimulusEvent',...
                'recording_id',this.recordingID,...
                'media_id',mediaID);
            
            % process input arguments
            if ~isempty(mediaPosition)
                % coordinate system is same as PTB, with (0,0) in top-left
                request.media_position = struct(...
                    'left'  , mediaPosition(1),...
                    'top'   , mediaPosition(2),...
                    'right' , mediaPosition(3),...
                    'bottom', mediaPosition(4)...
                    );
            end
            if isempty(startTimeStamp)
                startTimeStamp = GetSecs();
            end
            request.start_timestamp = int64(startTimeStamp*1000*1000);      % convert timeStamps from PTB time to Pro Lab time
            if nargin>4 && ~isempty(endTimeStamp)
                request.end_timestamp = int64(endTimeStamp*1000*1000);      % convert timeStamps from PTB time to Pro Lab time
            end
            if nargin>5 && ~isempty(background)
                if isnumeric(background)    % else we assume its a hexadecimal string already
                    % turn into RGBA so that user can provide also single gray
                    % value, etc
                    background = round(color2RGBA(background));
                    background = reshape(dec2hex(background(1:3)).',1,[]);
                end
                request.background = background;
            end
            
            % send
            this.clientEP.send(request);
            waitForResponse(this.clientEP,'SendStimulusEvent');
        end
        
        function sendCustomEvent(this,timestamp,eventType,value)
            request = struct('operation','SendCustomEvent',...
                'recording_id',this.recordingID);
            
            % proces inputs
            request.timestamp = int64(timestamp*1000*1000);
            request.event_type= eventType;
            if nargin>3 && ~isempty(value)
                request.value = value;
            end
            
            % send
            this.clientEP.send(request);
            waitForResponse(this.clientEP,'SendCustomEvent');
        end
    end
    
    methods (Static)
        function tag = makeTag(tagName,groupName)
            tag.tag_name    = tagName;
            tag.group_name  = '';
            if nargin>1 && ~isempty(groupName)
                tag.group_name  = groupName;
            end
        end
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