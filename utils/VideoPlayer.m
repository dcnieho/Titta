classdef VideoPlayer < handle
    properties (Access = protected, Hidden = true)
        wpnt;

        % state
        nextVids = [];

        playingVid = [];
        playingVidDur;
        loopSingleVid;

        nextVidIndex = nan;
        nextVid;
        nextVidDur;
        nextVidPrefetch = 0;

        doShuffle = true;
    end
    
    properties (SetAccess=protected)
        % List of videos enqueud for playing
        videos;

        % Index of currently playing video
        vidIndex = nan;

        % frame number of last-displayed video
        frameIndex = nan;

        % indicates if a video is currently playing
        isPlaying = false;
    end

    properties (Dependent)
        % play in randomized order?
        shuffle;
    end
    
    methods
        function obj = VideoPlayer(wpnt,videos)
            % Construct VideoPlayer instance
            %
            %    EThndl = VideoPlayer(WPNT,VIDEOS)
            
            obj.wpnt = wpnt;
            
            % deal with videos input: normalize to string array
            if ischar(videos) || iscellstr(videos) %#ok<ISCLSTR> 
                videos = string(videos);
            end

            % check all video files exist
            assert(isstring(videos),'VideoPlayer: videos input should be a string array (paths to videos)')
            for v=1:length(videos)
                assert(exist(videos(v),'file')==2,'Video file "%s" not found',videos(v))
            end
            obj.videos = videos(:).';
        end
        
        function delete(obj)
            obj.cleanup();
        end

        function set.shuffle(obj,val)
            assert(isempty(obj.nextVids),'cannot set shuffle if playback has previously been started')
            obj.doShuffle = ~~val;
        end
        function val = get.shuffle(obj)
            val = obj.doShuffle;
        end

        function start(obj)
            if isempty(obj.nextVids)
                % first call to start
                [obj.playingVid, obj.playingVidDur, obj.vidIndex] = obj.openNextVid(false);
            end
            Screen('PlayMovie', obj.playingVid, 1, double(obj.loopSingleVid), 0);
            if obj.nextVidPrefetch == 2
                Screen('PlayMovie', obj.nextVid, 1, 0, 0);
            end
        end

        function tex = getFrame(obj)
            % NB: must close returned texture yourself
            [tex, pts] = Screen('GetMovieImage', obj.wpnt, obj.playingVid, 0);

            if tex<0
                % current video finished. Switch over. Never get here when
                % looping a single video, so don't have to check for that
                Screen('PlayMovie', obj.playingVid, 0);
                Screen('CloseMovie', obj.playingVid);
                [obj.playingVid, obj.playingVidDur, obj.vidIndex] = deal(obj.nextVid, obj.nextVidDur, obj.nextVidIndex);
                tex = Screen('GetMovieImage', obj.wpnt, obj.playingVid, 0);
                obj.nextVidPrefetch = 0;
            elseif ~obj.loopSingleVid
                % We start background loading of the next movie 0.5 seconds
                % after start of playback of the current movie:
                if obj.nextVidPrefetch==0 && pts > 0.5
                    % Initiate background async load operation:
                    % We simply set the async flag to 1 and don't query any
                    % return values:
                    [~,~, obj.nextVidIndex] = obj.openNextVid(true);
                    obj.nextVidPrefetch = 1;
                end

                % If asynchronous load of next movie has been started already
                % and we are less than 0.5 seconds from the end of the current
                % movie, then we try to finish the async load operation and
                % start playback of the new movie in order to give processing a
                % headstart:
                if obj.nextVidPrefetch==1 && obj.playingVidDur - pts < 0.5
                    % Less than 0.5 seconds until end of current movie. Try to
                    % start playback for next movie:

                    [obj.nextVid, obj.nextVidDur] = obj.openNextVid(false, obj.nextVidIndex);
                    obj.nextVidPrefetch = 2;

                    % Start it:
                    Screen('PlayMovie', obj.nextVid, 1, 0, 0);
                end
            end
        end

        function stop(obj)
             Screen('PlayMovie', obj.playingVid, 0);
             if obj.nextVidPrefetch == 2
                 Screen('PlayMovie', obj.nextVid, 0);
            end
        end

        function cleanup(obj)
            if isempty(obj.playingVid)
                % never started, no state to clean up
                return
            end
            try
                Screen('PlayMovie', obj.playingVid, 0);
                Screen('CloseMovie', obj.playingVid);

                if obj.nextVidPrefetch == 1
                    % A prefetch operation for a movie is still in progress. We
                    % need to finalize this cleanly by waiting for the movie to
                    % open and then closing it
                    obj.nextVid = obj.openNextVid(false, obj.nextVidIndex);
                    obj.nextVidPrefetch = 2;
                end

                if obj.nextVidPrefetch == 2
                    % New prefetch movie was finished. We need to stop and
                    % close it
                    Screen('PlayMovie', obj.nextVid, 0);
                    Screen('CloseMovie', obj.nextVid);
                end
            catch
                % the above may fail if window was closed already since
                % we're cleaning up from a previous run
            end
            Screen('CloseMovie');

            obj.nextVidPrefetch = 0;
            obj.nextVids = [];
            obj.playingVid = [];
            obj.nextVidIndex = nan;
            obj.nextVid = [];
        end
    end

    methods (Access = private, Hidden)
        function determineNextVids(obj)
            if obj.shuffle
                while true
                    obj.nextVids = randperm(length(obj.videos));
                    if obj.nextVids(1)~=obj.vidIndex
                        % ensure we don't have the same video twice in
                        % a row
                        break;
                    end
                end
            else
                obj.nextVids = [1:length(obj.videos)]; %#ok<NBRAK2>
            end
            obj.loopSingleVid = isscalar(obj.videos);
        end

        function [vpnt,vdur,id] = openNextVid(obj, async, id)
            if nargin<3
                if isempty(obj.nextVids)
                    obj.determineNextVids();
                end
                id = obj.nextVids(1);
                obj.nextVids(1) = [];
            end
            if async
                Screen('OpenMovie', obj.wpnt, char(obj.videos(id)), 1, 1, 2);
                [vpnt,vdur] = deal(nan);
            else
                [vpnt,vdur] = Screen('OpenMovie', obj.wpnt, char(obj.videos(id)), 0, 1, 2);
            end
        end
    end
end