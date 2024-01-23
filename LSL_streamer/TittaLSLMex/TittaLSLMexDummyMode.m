% TittaLSLMex is part of Titta, a toolbox providing convenient access to
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

classdef TittaLSLMexDummyMode < TittaLSLMex
    properties (Access = protected, Hidden = true)
        isRecordingGaze = false;
        isInCalMode     = false;
    end

    methods
        % Use the name of your MEX file here
        function this = TittaLSLMexDummyMode(~)
            % construct default base class, none of its properties are
            % relevant when in dummy mode
            this = this@TittaLSLMex();

            % check we overwrite all public methods (for developer, to make
            % sure we override all accessible baseclass calls with no-ops)
            thisInfo    = ?TittaLSLMexDummyMode;
            thisMethods = thisInfo.MethodList;
            superInfo   = ?TittaLSLMex;
            superMethods= superInfo.MethodList;
            % for both, remove their constructors from list and limit
            % to only public methods
            superMethods(~strcmp({superMethods.Access},'public') | (~~[superMethods.Static]) | ismember({superMethods.Name},{'TittaLSLMex'})) = [];
            thisMethods (~strcmp( {thisMethods.Access},'public') | (~~ [thisMethods.Static]) | ismember( {thisMethods.Name},{'TittaLSLMexDummyMode'})) = [];
            % for methods of this dummy mode class, also remove methods
            % defined by superclass. and for both remove all those from
            % handle class
            definingClass = [thisMethods.DefiningClass];
            thisMethods(~strcmp({definingClass.Name},thisInfo.Name)) = [];
            definingClass = [superMethods.DefiningClass];
            superMethods(~strcmp({definingClass.Name},superInfo.Name)) = [];

            % now check for problems:
            % 1. any methods we define here that are not in superclass?
            notInSuper = ~ismember({thisMethods.Name},{superMethods.Name});
            if any(notInSuper)
                fprintf('methods that are in %s but not in %s:\n',thisInfo.Name,superInfo.Name);
                fprintf('  %s\n',thisMethods(notInSuper).Name);
            end

            % 2. methods from superclass that are not overridden.
            % filter out those methods that we on purpose do not define
            % in this subclass, as the superclass methods work fine
            % (call static functions in the mex)
            qNotOverridden = ~ismember({superMethods.Name},{thisMethods.Name}) & ~ismember({superMethods.Name},{'getRemoteStreams','getAllBufferSidesString','getAllStreamsString'});
            if any(qNotOverridden)
                fprintf('methods from %s not overridden in %s:\n',superInfo.Name,thisInfo.Name);
                fprintf('  %s\n',superMethods(qNotOverridden).Name);
            end

            % 3. right number of input arguments?
            qMatchingInput = false(size(thisMethods));
            for p=1:length(thisMethods)
                superMethod = superMethods(strcmp({superMethods.Name},thisMethods(p).Name));
                if isscalar(superMethod)
                    qMatchingInput(p) = (length(superMethod.InputNames) == length(thisMethods(p).InputNames)) || (length(superMethod.InputNames) < length(thisMethods(p).InputNames) && strcmp(superMethod.InputNames{end},'varargin'));
                else
                    qMatchingInput(p) = true;
                end
            end
            if any(~qMatchingInput)
                fprintf('methods in %s with wrong number of input arguments (mismatching %s):\n',thisInfo.Name,superInfo.Name);
                fprintf('  %s\n',thisMethods(~qMatchingInput).Name);
            end

            % 4. right number of output arguments?
            qMatchingOutput = false(size(thisMethods));
            for p=1:length(thisMethods)
                superMethod = superMethods(strcmp({superMethods.Name},thisMethods(p).Name));
                if isscalar(superMethod)
                    qMatchingOutput(p) = length(superMethod.OutputNames) == length(thisMethods(p).OutputNames);
                else
                    qMatchingOutput(p) = true;
                end
            end
            if any(~qMatchingOutput)
                fprintf('methods in %s with wrong number of output arguments (mismatching %s):\n',thisInfo.Name,superInfo.Name);
                fprintf('  %s\n',thisMethods(~qMatchingOutput).Name);
            end
        end

        %% Matlab interface
        function delete(~)
        end

        %% global SDK functions
        % no need to override any

        %% outlets
        function connect(~,~)
        end
        function success = startOutlet(this,stream,~)
            if nargin<2
                error('TittaLSLMex::startOutlet: provide stream argument. \nSupported streams are: %s.',this.getAllStreamsString());
            end
            success = checkValidStream(this,stream);
        end
        function setIncludeEyeOpennessInGaze(~,~)
        end
        function status = isStreaming(this,stream)
            if nargin<2
                error('TittaLSLMex::isStreaming: provide stream argument. \nSupported streams are: %s.',this.getAllStreamsString());
            end
            checkValidStream(this,stream);
            status = false;
        end
        function stopOutlet(this,stream)
            if nargin<2
                error('TittaLSLMex::stopOutlet: provide stream argument. \nSupported streams are: %s.',this.getAllStreamsString());
            end
            checkValidStream(this,stream);
        end

        %% data streams
        %% inlets
        function id = createInlet(~,~,~,~)
            if nargin<2
                error('TittaLSLMex::createInlet: must provide an LSL stream source identifier string.');
            end
            id = uint32(1);
        end

        function streamInfo = getInletInfo(~,~)
            if nargin<2
                error('TittaLSLMex::getInletInfo: must provide an inlet id.');
            end
            streamInfo = [];
        end
        function stream = getInletType(~,~)
            if nargin<2
                error('TittaLSLMex::getInletType: must provide an inlet id.');
            end
            stream = '';
        end

        function startListening(~,~)
            if nargin<2
                error('TittaLSLMex::startListening: must provide an inlet id.');
            end
        end
        function status = isListening(~,~)
            if nargin<2
                error('TittaLSLMex::isListening: must provide an inlet id.');
            end
            status = false;
        end

        function data = consumeN(this,~,~,side)
            if nargin<2
                error('TittaLSLMex::consumeN: must provide an inlet id.');
            end
            if nargin>3
                checkValidBufferSide(this,side);
            end
            data = [];
        end
        function data = consumeTimeRange(~,~,~,~)
            if nargin<2
                error('TittaLSLMex::consumeTimeRange: must provide an inlet id.');
            end
            data = [];
        end
        function data = peekN(this,~,~,side)
            if nargin<2
                error('TittaLSLMex::peekN: must provide an inlet id.');
            end
            if nargin>3
                checkValidBufferSide(this,side);
            end
            data = [];
        end
        function data = peekTimeRange(~,~,~,~)
            if nargin<2
                error('TittaLSLMex::peekTimeRange: must provide an inlet id.');
            end
            data = [];
        end
        function clear(~,~)
            if nargin<2
                error('TittaLSLMex::clear: must provide an inlet id.');
            end
        end
        function clearTimeRange(~,~,~,~)
            if nargin<2
                error('TittaLSLMex::clearTimeRange: must provide an inlet id.');
            end
        end
        function stopListening(~,~,~)
            if nargin<2
                error('TittaLSLMex::stopListening: must provide an inlet id.');
            end
        end
        function deleteListener(~,~)
            if nargin<2
                error('TittaLSLMex::deleteListener: must provide an inlet id.');
            end
        end
    end
end


% helpers
function str = ensureStringIsChar(str)
if isa(str,'string')
    str = char(str);        % seems matlab also has a string type, shows up if user accidentally uses double quotes, convert to char
end
end

function isValid = checkValidStream(this,stream)
isValid = this.cppmethodGlobal('checkStream',ensureStringIsChar(stream));
end
function isValid = checkValidBufferSide(this,side)
isValid = this.cppmethodGlobal('checkBufferSide',ensureStringIsChar(side));
end
