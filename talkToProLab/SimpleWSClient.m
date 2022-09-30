classdef SimpleWSClient < WebSocketClient
    properties (SetAccess = protected)
        lastRespText    = '';
        lastRespBinary  = [];
    end
    
    methods
        function this = SimpleWSClient(varargin)
            % get name of websocket jar file
            myDir = fileparts(mfilename('fullpath'));
            file  = dir(fullfile(myDir,'**','matlab-websocket-*.jar'));
            % add jar to static class path if needed, so the websocket java
            % library can be found
            mustRestart = setupJavaStaticClassPath(file.name);
            if mustRestart
                error('You need to <a href="matlab:quit;">restart matlab now</a> to finish installing WebSocket''s java backing library')
            end
            
            % Constructor
            this@WebSocketClient(varargin{:});
        end
        
        function resp = get.lastRespText(this)
            resp = matlab.internal.webservices.fromJSON(this.lastRespText);
            this.lastRespText = '';
        end
        function resp = get.lastRespBinary(this)
            resp = this.lastRespBinary;
            this.lastRespBinary = [];
        end
        function send(this,message)
            if isstruct(message)
                message = matlab.internal.webservices.toJSON(message);
            end
            send@WebSocketClient(this,message);
        end
    end
    
    methods (Access = protected)
        function onOpen(~,message) %#ok<INUSD>
            % This function simply displays the message received
            %fprintf('%s\n',message);
        end
        
        function onTextMessage(this,message)
            % This function simply displays the message received
            this.lastRespText = message;
        end
        
        function onBinaryMessage(this,bytearray)
            % This function simply displays the message received
            this.lastRespBinary = bytearray;
        end
        
        function onError(this,message)
            % This function simply displays the message received
            error('%s (%s)',message,this.URI);
        end
        
        function onClose(~,message) %#ok<INUSD>
            % This function simply displays the message received
            %fprintf('%s\n',message);
        end
    end
end


function mustRestart = setupJavaStaticClassPath(jarName)

jarPath = which(jarName);
assert(~isempty(jarPath),'file ''%s'' could not be found. When cloning the Titta repository, make sure you initialize the git submodules as well. That should pull in this file',jarName);

mustRestart = false;

% this setup code is taken from PsychJavaTrouble.m
try
    % Matlab version 8.1 (R2013a) or later. classpath.txt can't be
    % used anymore. Now they want us to store static classpath
    % definitions in a file called javaclasspath.txt inside the
    % Matlab preference folder:
    
    % Try to find the file, if it already exists, e.g., inside the
    % Matlab startup folder:
    classpathFile = which('javaclasspath.txt');
    
    % Found it?
    if isempty(classpathFile)
        % Nope. So we try the preference folder.
        % Retrieve path to preference folder. Create the folder if it
        % doesn't already exist:
        prefFolder = prefdir(1);
        classpathFile = [prefFolder filesep 'javaclasspath.txt'];
        if ~exist(classpathFile, 'file')
            fid = fopen(classpathFile, 'w');
            fclose(fid);
        end
    end
    
    % Define name of backup file:
    bakclasspathFile = [classpathFile '.bak'];
    
    % read each line into separate cell
    txt = fileread(classpathFile);
    fileContents = strsplit(txt,'\n');
    fileContents = fileContents(:); % ensure column vector
    fileContents(cellfun(@isempty,fileContents)) = [];
    
    j = 1;
    newFileContents = {};
    pathInserted = 0;
    for i = 1:length(fileContents)
        % Look for the first instance of matlab-websocket in the classpath
        % and replace it with the new one.  All other instances will be
        % removed.
        if isempty(strfind(fileContents{i}, 'matlab-websocket'))
            newFileContents{j, 1} = fileContents{i}; %#ok<AGROW>
            j = j + 1;
        else
            if ~pathInserted
                newFileContents{j, 1} = jarPath; %#ok<AGROW>
                pathInserted = 1;
                j = j + 1;
            else
                % don't copy over
            end
        end
    end
    
    % If the matlab-websocket path wasn't inserted, then this must be a new
    % installation, so we append it to the classpath.
    if ~pathInserted
        newFileContents{end + 1, 1} = jarPath;
    end
    
    % Now compare to see if the new and old classpath are the same.  If
    % they are, then there's no need to do anything.
    updateClasspath = 1;
    if length(fileContents) == length(newFileContents)
        if all(strcmp(fileContents, newFileContents))
            updateClasspath = 0;
        end
    end
    
    if updateClasspath
        % Make a backup of the old classpath.
        clear madeBackup;
        
        [s, w] = copyfile(classpathFile, bakclasspathFile, 'f');
        
        if s==0
            error(['Could not make a backup copy of Matlab''s JAVA path definition file. The system reports: ', w]);
        end
        madeBackup = 1; %#ok<NASGU>
        
        % Write out the new contents.
        fid = fopen(classpathFile, 'w');
        if fid == -1
            error('Could not open Matlab''s JAVA path definition file for write access.');
        end
        for i = 1:length(newFileContents)
            fprintf(fid, '%s\n', newFileContents{i});
        end
        fclose(fid);
        
        fprintf('\n\n');
        disp('*** Matlab''s Static Java classpath definition file modified. You will have to restart Matlab to enable use of the new Java components. ***');
        fprintf('\nPress RETURN or ENTER to confirm you read and understood the above message.\n');
        pause;
        mustRestart = true;
    else
        mustRestart = isempty(which('io.github.jebej.matlabwebsocket.MatlabWebSocketClient'));
    end
catch ME
    fprintf('Could not update the Matlab Java classpath file due to the following error:\n');
    fprintf('%s\n\n', ME.message);
    fprintf('You likely do not have sufficient access permissions for the Matlab application\n');
    fprintf('folder or file itself to change the file %s .\n', classpathFile);
    fprintf('Please ask the system administrator to enable write-access to that file and its\n');
    fprintf('containing folder and then repeat the update procedure.\n');
    fprintf('Alternatively, ask the administrator to add the following line:\n');
    fprintf('%s\n', jarPath);
    fprintf('to the file: %s\n\n', classpathFile);
    fprintf('TalkToProLab will <b><u>not work</b></u> if you skip this step, Titta will still\n');
    fprintf('be functional. \n');
    fprintf('\nPress RETURN or ENTER to confirm you read and understood the above message.\n');
    pause;
    
    % Restore the old classpath file if necessary.
    if exist('madeBackup', 'var')
        [s, w] = copyfile(bakclasspathFile, classpathFile, 'f'); %#ok<ASGLU>
    end
end
end
