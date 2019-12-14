% Titta is a toolbox providing convenient access to eye tracking
% functionality using Tobii eye trackers 
%
% Titta can be found at https://github.com/dcnieho/Titta. Check there for
% the latest version.
% When using Titta, please cite the following paper:
% Niehorster, D.C., Andersson, R. & Nyström, M., (in prep). Titta: A
% toolbox for creating Psychtoolbox and Psychopy experiments with Tobii eye
% trackers.

classdef TittaDummyMode < Titta
    methods
        function obj = TittaDummyMode(TittaInstance)
            qPassedSuperClass = false;
            if ischar(TittaInstance)
                % direct construction, thats fine
                name = TittaInstance;
            elseif isa(TittaInstance,'Titta')
                qPassedSuperClass = true;
                name = TittaInstance.settings.tracker;
            end
            
            % construct default base class, below we overwrite some
            % settings, if a super class was passed in
            obj = obj@Titta(name);
            
            if qPassedSuperClass
                % passed the superclass. "cast" into subclass by copying
                % over all properties. This is what TMW recommends when you
                % want to downcast...
                C = metaclass(TittaInstance);
                P = C.Properties;
                for k = 1:length(P)
                    if ~P{k}.Dependent && ~strcmp(P{k}.SetAccess,'private')
                        obj.(P{k}.Name) = TittaInstance.(P{k}.Name);
                    end
                end
            end
            
            % check we overwrite all public methods (for developer, to make
            % sure we override all accessible baseclass calls with no-ops)
            if 1
                thisInfo    = ?TittaDummyMode;
                thisMethods = thisInfo.MethodList;
                superInfo   = ?Titta;
                superMethods= superInfo.MethodList;
                % for both, remove their constructors from list and limit
                % to only public methods
                superMethods(~strcmp({superMethods.Access},'public') | (~~[superMethods.Static]) | ismember({superMethods.Name},{'Titta'})) = [];
                thisMethods (~strcmp( {thisMethods.Access},'public') | (~~ [thisMethods.Static]) | ismember( {thisMethods.Name},{'TittaDummyMode'})) = [];
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
                
                % 2. methods from superclas that are not overridden.
                % filter out those methods that we on purpose do not define
                % in this subclass, as the superclass methods work fine
                qNotOverridden = ~ismember({superMethods.Name},{thisMethods.Name}) & ~ismember({superMethods.Name},{'getMessages','sendMessage','setOptions','getOptions','delete'});
                if any(qNotOverridden)
                    fprintf('methods from %s not overridden in %s:\n',superInfo.Name,thisInfo.Name);
                    fprintf('  %s\n',superMethods(qNotOverridden).Name);
                end
                
                % 3. right number of input arguments?
                qMatchingInput = false(size(thisMethods));
                for p=1:length(thisMethods)
                    superMethod = superMethods(strcmp({superMethods.Name},thisMethods(p).Name));
                    if isscalar(superMethod)
                        qMatchingInput(p) = (length(superMethod.InputNames) == length(thisMethods(p).InputNames)) || (length(superMethod.InputNames) < length(thisMethods(p).InputNames) && strcmp(superMethod.InputNames{end},'varargin')) || (length(thisMethods(p).InputNames) < length(superMethod.InputNames) && strcmp(thisMethods(p).InputNames{end},'varargin'));
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
                
                % next, also check properties
                thisProperties = thisInfo.PropertyList;
                superProperties= superInfo.PropertyList;
                % for both, limit to only properties that have public get
                % or a public set, and are not hidden
                superProperties(~(strcmp({superProperties.GetAccess},'public')|strcmp({superProperties.SetAccess},'public')) | (~~[superProperties.Hidden])) = [];
                thisProperties (~(strcmp({ thisProperties.GetAccess},'public')|strcmp({ thisProperties.SetAccess},'public')) | (~~[ thisProperties.Hidden])) = [];
                % for properties of this dummy mode class, also remove
                % properties
                definingClass = [thisProperties.DefiningClass];
                thisProperties(~strcmp({definingClass.Name},thisInfo.Name)) = [];
                definingClass = [superProperties.DefiningClass];
                superProperties(~strcmp({definingClass.Name},superInfo.Name)) = [];
                
                % now check for problems:
                % 1. any properties we define here that are not in superclass?
                notInSuper = ~ismember({thisProperties.Name},{superProperties.Name});
                if any(notInSuper)
                    fprintf('properties that are in %s but not in %s:\n',thisInfo.Name,superInfo.Name);
                    fprintf('  %s\n',thisMethods(notInSuper).Name);
                end
                
                % 2. properties from superclas that are not overridden.
                % filter out those methods that we on purpose do not define
                % in this subclass, as the superclass methods work fine
                qNotOverridden = ~ismember({superProperties.Name},{thisProperties.Name}) & ~ismember({superProperties.Name},{'geom','calibrateHistory','buffer'});
                if any(qNotOverridden)
                    fprintf('properties from %s not overridden in %s:\n',superInfo.Name,thisInfo.Name);
                    fprintf('  %s\n',superProperties(qNotOverridden).Name);
                end
            end
        end
        
        function out = setDummyMode(obj)
            % we're already in dummy mode, just pass out the same instance
            out = obj;
        end
        
        function out = init(obj)
            out = [];
            % make dummyMode buffer
            obj.buffer = TobiiMexDummyMode();
            % mark as inited
            obj.isInitialized = true;
        end
        
        function out = calibrate(~,~,~)
            out = [];
        end
        
        function dat = collectSessionData(~)
            dat = [];
        end
        
        function saveData(~,~,~)
        end
        
        function out = deInit(obj)
            out = [];
            % mark as deinited
            obj.isInitialized = false;
        end
    end
end
