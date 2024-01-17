% TalkToProLab is part of Titta, a toolbox providing convenient access to
% eye tracking functionality using Tobii eye trackers 
%
% Titta can be found at https://github.com/dcnieho/Titta. Check there for
% the latest version.
% When using Titta or this class, please cite the following paper:
%
% Niehorster, D.C., Andersson, R. & Nystrom, M., (2020). Titta: A toolbox
% for creating Psychtoolbox and Psychopy experiments with Tobii eye
% trackers. Behavior Research Methods.
% doi: https://doi.org/10.3758/s13428-020-01358-8

classdef TalkToProLab < handle
    properties (Access = protected, Hidden = true)
        stimTimeStamps;
    end
    
    properties (SetAccess=protected)
        % websocket connections we need
        clientClock;
        clientProject;
        clientEP;
        
        projectID;
        participantID;
        recordingID;
    end
    
    methods
        function this = TalkToProLab(expectedProject,doCheckSync,IPorFQDN)
            % doCheckSync: set to false to skip checking sync between Pro
            % Lab clock and system clock. The sync routine is the only part
            % of this toolbox that uses PsychToolbox functionality
            % (GetSecs), so you may wish to skip it if using without
            % PsychToolbox. The sync routine also checks that Pro Lab and
            % TalkToProLab are running on the same machine. That is not a
            % strict requirement for running this code, but if you use it
            % with Pro Lab running on another machine, you are responsible
            % yourself for presenting TalkToProLab with timestamps in Pro
            % Lab's time, not that of the local machine. If you want to use
            % this class with Pro Lab running elsewhere, use the third
            % input argument to provide the IP or FQDN where Pro Lab can be
            % contacted. After running this constructor, you can use
            % TalkToProLab.clientClock to directly talk to the clock
            % service and figure out (and monitor every now and then!) the
            % clock offset between the two systems.
            if nargin<2
                doCheckSync = true;
            end
            if nargin<3
                IPorFQDN = 'localhost';
            end
            
            % check WebSocketClient java class required for SimpleWSClient
            % is available
            p   = fileparts(mfilename('fullpath'));
            file= dir(fullfile(p,'**','matlab-websocket-*.jar'));
            if isempty(file)
                error('The WebSocketClient required for TalkToProLab to function cannot be found. The folder ''%s'' is likely empty. If so, follow the install instructions provided here: https://github.com/dcnieho/Titta/#how-to-acquire to ensure that the right files are in the right place.',fullfile(p,'MatlabWebSocket'))
            end
            
            % connect to needed Lab services
            this.clientClock    = SimpleWSClient(['ws://' IPorFQDN ':8080/clock?client_id=TittaMATLAB']);
            assert(this.clientClock.Status==1,'TalkToProLab: Could not connect to clock service, did you start Tobii Pro Lab and open a project?');
            this.clientProject  = SimpleWSClient(['ws://' IPorFQDN ':8080/project?client_id=TittaMATLAB']);
            assert(this.clientProject.Status==1,'TalkToProLab: Could not connect to project service, did you start Tobii Pro Lab and open an external presenter project?');
            this.clientEP       = SimpleWSClient(['ws://' IPorFQDN ':8080/record/externalpresenter?client_id=TittaMATLAB']);
            assert(this.clientEP.Status==1,'TalkToProLab: Could not connect to external presenter service, did you start Tobii Pro Lab and open an external presenter project?');
            
            % for each, check API semver major version
            % 1. clock service
            this.clientClock.send(struct('operation','GetApiVersion'));
            resp    = waitForResponse(this.clientClock,'GetApiVersion');
            fprintf('TalkToProLab: using clock API version %s\n',resp.version);
            vers    = sscanf(resp.version,'%d.%d').';
            expected= 1;
            if vers(1)~=expected
                warning('TalkToProLab is compatible with Tobii Pro Lab''s clock API version 1.0, your Lab software provides version %s. If the code does not crash, check carefully that it works correctly',resp.version);
            end
            % 2. project service
            this.clientProject.send(struct('operation','GetApiVersion'));
            resp    = waitForResponse(this.clientProject,'GetApiVersion');
            fprintf('TalkToProLab: using project API version %s\n',resp.version);
            vers    = sscanf(resp.version,'%d.%d').';
            expected= 1;
            if vers(1)~=expected
                warning('TalkToProLab is compatible with Tobii Pro Lab''s project API version 1.0, your Lab software provides version %s. If the code does not crash, check carefully that it works correctly',resp.version);
            end
            % 3. external presenter service
            this.clientEP.send(struct('operation','GetApiVersion'));
            resp    = waitForResponse(this.clientEP,'GetApiVersion');
            fprintf('TalkToProLab: using external presenter API version %s\n',resp.version);
            vers    = sscanf(resp.version,'%d.%d').';
            expected= 1;
            if vers(1)~=expected
                warning('TalkToProLab is compatible with Tobii Pro Lab''s external presenter API version 1.0, your Lab software provides version %s. If the code does not crash, check carefully that it works correctly',resp.version);
            end
            
            % check our local clock is the same as the ProLabClock. for now
            % we do not support it when they aren't (e.g. running lab on a
            % different machine than the stimulus presentation machine)
            if doCheckSync
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
                assert(mean(timesLab-timesPTB)<2500,'TalkToProLab: Clock offset between PsychToolbox and Tobii Pro Lab is more than 2.5 ms: either the two are not using the same clock (unsupported) or you are running PsychToolbox and Tobii Pro Lab on different computers (also unsupported)')
            end
            
            % get info about opened project
            this.clientProject.send(struct('operation','GetProjectInfo'));
            resp = waitForResponse(this.clientProject,'GetProjectInfo');
            assert(strcmp(resp.project_name,expectedProject),'TalkToProLab: You indicated that project ''%s'' should be open in Tobii Pro Lab, but instead project ''%s'' seems to be open',expectedProject,resp.project_name)
            this.projectID = resp.project_id;
            fprintf('TalkToProLab: Connected to Tobii Pro Lab, currently opened project is ''%s'' (%s)\n',resp.project_name,resp.project_id);
            
            % prep list of timestamps sent through stimulus messages
            this.stimTimeStamps = simpleVec(int64([0 0]),1024);     % (re)initialize with space for 1024 stimulus intervals
        end
        
        function delete(this)
            % clean up connections
            this.disconnect();
            this.projectID      = '';
            this.participantID  = '';
            this.recordingID    = '';
            this.stimTimeStamps = simpleVec(int64([0 0]),1024);     % (re)initialize with space for 1024 stimulus intervals
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
            names   = {};
            if ~isempty(resp.participant_list)
                names   = {resp.participant_list.participant_name};
            end
            qPart   = strcmp(names,name);
            assert(~any(qPart)||allowExisting,'TalkToProLab: createParticipant: Participant with name ''%s'' already exists',name)
            
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
        
        function [mediaID,mediaInfo] = findMedia(this,name,throwWhenNotFound)
            if nargin<3 || isempty(throwWhenNotFound)
                throwWhenNotFound = false;
            end
            mediaID     = '';   % empty means no media with that name was found
            mediaInfo   = [];
            this.clientProject.send(struct('operation','ListMedia'));
            resp = waitForResponse(this.clientProject,'ListMedia');
            if ~isempty(resp.media_list)
                if ~iscell(resp.media_list)
                    resp.media_list = num2cell(resp.media_list);
                end
                names   = cellfun(@(x) x.media_name,resp.media_list,'uni',false);
                qMedia  = strcmp(names,name);
                if any(qMedia)
                    mediaID     = resp.media_list{qMedia}.media_id; % for convenience, provide direct mediaID output
                    mediaInfo   = resp.media_list{qMedia};
                elseif throwWhenNotFound
                    error('TalkToProLab: findMedia: Media with the name ''%s'' was not found in the project that is open in Pro Lab. Use TalkToProLab.uploadMedia to upload media with that name.',name)
                end
            elseif throwWhenNotFound
                error('TalkToProLab: findMedia: Media with the name ''%s'' was not found in the project that is open in Pro Lab. Use TalkToProLab.uploadMedia to upload media with that name.',name)
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
                assert(exist(fileNameOrArray,'file')==2,'TalkToProLab: uploadMedia: provided file ''%s'' cannot be found. If you did not provide a full path, consider doing that',fileNameOrArray);
            end
            
            % get mime type based on extension
            [~,~,ext] = fileparts(fileNameOrArray); if ext(1)=='.', ext(1) = []; end
            assert(~isempty(ext),'TalkToProLab: uploadMedia: file ''%s'' does not have extension, cannot deduce mime type',fileNameOrArray);
            switch lower(ext)
                case 'bmp'
                    mimeType = 'image/bmp';
                case {'jpg','jpeg'}
                    mimeType = 'image/jpeg';
                case 'png'
                    mimeType = 'image/png';
                case 'gif'
                    mimeType = 'image/gif';
                case {'mp4','mov'}
                    mimeType = 'video/mp4';
                case 'avi'
                    mimeType = 'video/x-msvideo';
                otherwise
                    error('TalkToProLab: uploadMedia: cannot deduce mime type from unknown extension ''%s''',ext);
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
        
        function attachAOIToImage(this,mediaName,aoiName,aoiColor,vertices,tags)
            % vertices should be 2xN
            [mediaID,mediaInfo] = this.findMedia(mediaName);
            assert(~isempty(mediaID),'TalkToProLab: attachAOIToImage: no media with provided name, ''%s'' is known',mediaName)
            assert(~isempty(strfind(mediaInfo.mime_type,'image')),'TalkToProLab: attachAOIToImage: media with name ''%s'' is not an image, but a %s',mediaName,mediaInfo.mime_type)
            
            request = struct('operation','AddAois',...
                'media_id',mediaID);
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
            assert(size(vertices,1)==2,'TalkToProLab: attachAOIToImage: AOI vertices should be a 2xN array')
            nVert = size(vertices,2);
            AOI.key_frames{1}.is_active = true;
            AOI.key_frames{1}.time      = int64(0);     % microseconds, appears to be ignored for image media, set to 0 anyway to be safe
            AOI.key_frames{1}.vertices  = repmat(struct('x',0,'y',0),1,nVert);
            vertices = num2cell(vertices);
            [AOI.key_frames{1}.vertices.x] = vertices{1,:};
            [AOI.key_frames{1}.vertices.y] = vertices{2,:};
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
            request.merge_mode = 'replace_aois';
            
            % send and wait till successfully processed
            this.clientProject.send(request);
            waitForResponse(this.clientProject,'AddAois');
        end
        
        function attachAOIToVideo(this,mediaName,request)
            % This function gives the user little help, and assumes that
            % they read the Tobii Pro Lab API and deliver a properly
            % formatted request. Request is the full struct to be converted
            % to json, except for the 'media_id', and 'operation', which
            % are added below
            [mediaID,mediaInfo] = this.findMedia(name);
            assert(~isempty(mediaID),'TalkToProLab: attachAOIToVideo: no media with provided name, ''%s'' is known',mediaName)
            assert(~isempty(strfind(mediaInfo.mime_type,'video')),'TalkToProLab: attachAOIToVideo: media with name ''%s'' is not an image, but a %s',mediaName,mediaInfo.mime_type)
            
            request.operation = 'AddAois';
            request.media_id  = mediaID;
            
            % send and wait till successfully processed
            this.clientProject.send(request);
            waitForResponse(this.clientProject,'AddAois');
        end
        
        function EPState = getExternalPresenterState(this)
            this.clientEP.send(struct('operation','GetState'));
            resp    = waitForResponse(this.clientEP,'GetState');
            EPState = resp.state;
        end
        
        function recordingID = startRecording(this,name,scrWidth,scrHeight,scrLatency,skipStateCheck)
            % first check if we're in the right state, unless requested
            % that we skip that
            if nargin<6 || isempty(skipStateCheck) || ~skipStateCheck
                state = this.getExternalPresenterState();
                assert(strcmpi(state,'ready'),'TalkToProLab: startRecording: Tobii Pro Lab is not in the expected state. Should be ''ready'', is ''%s''. Make sure Pro Lab is on the recording tab and that currently no recording is active',state);
            end
            % scrLatency is optional
            request = struct('operation','StartRecording',...
                'recording_name',name,...
                'participant_id',this.participantID,...
                'screen_width'  ,scrWidth,...
                'screen_height' ,scrHeight);
            if nargin>=5 && ~isempty(scrLatency)
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
            % Tobii Pro Lab requires there to be no gaps in the timeline
            % resolve gaps first based on record of timeStamps sent to
            % Tobii Pro Lab
            fillerName  = '!!emptyIntervalFiller!!';
            ts          = sortrows(this.stimTimeStamps.data,1);                     % events can be sent in any order, will be assembled by Tobii Pro Lab into correct order. Fix that up here
            iGap        = find(ts(2:end,1)-ts(1:end-1,2) > 0 & ts(1:end-1,2)~=-1);  % end time can also be -1, in which case its automatically set to start time of next event. Ignore those
            if ~isempty(iGap)
                mediaID = this.findMedia(fillerName);
                % see if we already have our fake filler media in this
                % Lab project.
                if isempty(mediaID)
                    % nope, upload one
                    mediaID = this.uploadMedia(zeros(10,10,'uint8'),fillerName);
                end
                % now plug the gaps
                for g=1:length(iGap)
                    st = ts(iGap(g)  ,2);   % start time of gap filler is end time of previous
                    et = ts(iGap(g)+1,1);   % end time of gap filler is start time of next
                    this.sendStimulusEvent(mediaID,[],st,et,[],false);
                end
            end
            
            % now send finalize
            this.clientEP.send(struct('operation','FinalizeRecording','recording_id',this.recordingID));
            waitForResponse(this.clientEP,'FinalizeRecording');
            this.recordingID= '';
        end
        
        function discardRecording(this)
            this.clientEP.send(struct('operation','DiscardRecording','recording_id',this.recordingID));
            waitForResponse(this.clientEP,'DiscardRecording');
            this.recordingID= '';
        end
        
        function sendStimulusEvent(this,mediaID,mediaPosition,startTimeStamp,endTimeStamp,background,qDoTimeConversion)
            % mediaPosition, endTimeStamp, background are optional, can be
            % left empty or not provided in call
            % NB: startTimeStamp and endTimeStamp are in Pro Lab time,
            % which is different from local/caller time when running a
            % two-computer setup. See notes in TalkToProLab constructor
            % qDoTimeConversion (from s to ms) is for internal use, do not
            % set it unless you know what you are doing.
            if nargin<7 || qDoTimeConversion
                qDoTimeConversion = true;
            end
            request = struct('operation','SendStimulusEvent',...
                'recording_id',this.recordingID,...
                'media_id',mediaID);
            
            % process input arguments
            % 1. media position
            if ~isempty(mediaPosition)
                % coordinate system is same as PTB, with (0,0) in top-left
                request.media_position = struct(...
                    'left'  , mediaPosition(1),...
                    'top'   , mediaPosition(2),...
                    'right' , mediaPosition(3),...
                    'bottom', mediaPosition(4)...
                    );
            end
            % 2. start time
            st = startTimeStamp;
            if qDoTimeConversion
                st = int64(st*1000*1000);
            end
            request.start_timestamp = st;           % convert timeStamps from PTB time to Tobii Pro Lab time
            % 3. end time
            if nargin>4 && ~isempty(endTimeStamp)
                et = endTimeStamp;
                if qDoTimeConversion
                    et = int64(et*1000*1000);
                end
                request.end_timestamp = et;         % convert timeStamps from PTB time to Tobii Pro Lab time
            else
                et = int64(-1);
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
            
            % store sent timestamps
            this.stimTimeStamps.append([st et]);
        end
        
        function sendCustomEvent(this,timestamp,eventType,value)
            % NB: timeStamp are in Pro Lab time, which is different from
            % local/caller time when running a two-computer setup. See
            % notes in TalkToProLab constructor
            request = struct('operation','SendCustomEvent',...
                'recording_id',this.recordingID);
            
            % proces inputs
            if isempty(timestamp)
                timestamp = GetSecs();
            end
            request.timestamp = int64(timestamp*1000*1000);
            request.event_type= eventType;
            if nargin>3 && ~isempty(value)
                value = regexprep(value,'[\n\r]','||'); % can't contain newlines/linefeeds
                value = regexprep(value,'\t','    ');   % can't contain tabs
                request.value = value;
            end
            
            % send
            this.clientEP.send(request);
            waitForResponse(this.clientEP,'SendCustomEvent');
        end
    end
    
    methods (Static)
        function tag = makeAOITag(tagName,groupName)
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
    pause(pauseDur);    % gotta pause to allow other events to be processed in MATLAB
end

if resp.status_code
    reason = '';
    if isfield(resp,'reason')
        reason = sprintf(': %s',resp.reason);
    end
    error('TalkToProLab: Command ''%s'' returned an error: %d (%s)%s',operation,resp.status_code,statusToText(resp.status_code),reason);
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
