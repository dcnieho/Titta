classdef TalkToProLabDummyMode < handle
    
    properties (SetAccess=protected)
        projectID       = '';
        participantID   = '';
        recordingID     = '';
    end
    
    methods
        function obj = TalkToProLabDummyMode()
            % no-op, just check we have the same public interface as non
            % dummy-mode class
            % check we overwrite all public methods (for developer, to make
            % sure we override all accessible baseclass calls with no-ops)
            if 1
                thisInfo = ?TalkToProLabDummyMode;
                realInfo = ?TalkToProLab;
                realMethods = realInfo.MethodList;
                thisMethods = thisInfo.MethodList;
                % for both, remove their constructors from list and limit
                % to only public methods
                realMethods(~strcmp({realMethods.Access},'public') | ismember({realMethods.Name},{'TalkToProLab'})) = [];
                thisMethods(~strcmp({thisMethods.Access},'public') | ismember({thisMethods.Name},{'TalkToProLabDummyMode'})) = [];
                
                % now check for problems:
                % 1. any methods we define here that are not in superclass?
                notInSuper = ~ismember({thisMethods.Name},{realMethods.Name});
                if any(notInSuper)
                    fprintf('methods that are in %s but not in %s:\n',thisInfo.Name,realInfo.Name);
                    fprintf('  %s\n',thisMethods(notInSuper).Name);
                end
                
                % 2. methods from superclas that are not overridden.
                qNotOverridden = ~ismember({realMethods.Name},{thisMethods.Name});
                if any(qNotOverridden)
                    fprintf('methods that are in %s but not in %s:\n',realInfo.Name,thisInfo.Name);
                    fprintf('  %s\n',realMethods(qNotOverridden).Name);
                end
                
                % 3. right number of input arguments?
                qMatchingInput = false(size(thisMethods));
                for p=1:length(thisMethods)
                    realMethod = realMethods(strcmp({realMethods.Name},thisMethods(p).Name));
                    if isscalar(realMethod)
                        qMatchingInput(p) = (length(realMethod.InputNames) == length(thisMethods(p).InputNames)) || (length(realMethod.InputNames) < length(thisMethods(p).InputNames) && strcmp(realMethod.InputNames{end},'varargin')) || (length(thisMethods(p).InputNames) < length(realMethod.InputNames) && strcmp(thisMethods(p).InputNames{end},'varargin'));
                    else
                        qMatchingInput(p) = true;
                    end
                end
                if any(~qMatchingInput)
                    fprintf('methods in %s with wrong number of input arguments (mismatching %s):\n',thisInfo.Name,realInfo.Name);
                    fprintf('  %s\n',thisMethods(~qMatchingInput).Name);
                end
                
                % 4. right number of output arguments?
                qMatchingOutput = false(size(thisMethods));
                for p=1:length(thisMethods)
                    realMethod = realMethods(strcmp({realMethods.Name},thisMethods(p).Name));
                    if isscalar(realMethod)
                        qMatchingOutput(p) = length(realMethod.OutputNames) == length(thisMethods(p).OutputNames);
                    else
                        qMatchingOutput(p) = true;
                    end
                end
                if any(~qMatchingOutput)
                    fprintf('methods in %s with wrong number of output arguments (mismatching %s):\n',thisInfo.Name,realInfo.Name);
                    fprintf('  %s\n',thisMethods(~qMatchingOutput).Name);
                end
            end
        end
        
        function delete(~)
        end
        
        function disconnect(~)
        end
        
        function participantID = createParticipant(~,~,~)
            participantID = 'fake_participant_id';
        end
        
        function [mediaID,mediaInfo] = findMedia(~,~)
            mediaID     = '';
            mediaInfo   = struct();
        end
        
        function [mediaID,wasUploaded] = uploadMedia(~,~,~)
            mediaID = '';
            wasUploaded = false;
        end
        
        function numAOI = attachAOIToImage(~,~,~,~,~,~)
            numAOI = 0;
        end
        
        function numAOI = attachAOIToVideo(~,~,~)
            numAOI = 0;
        end
        
        function EPState = getExternalPresenterState(~)
            EPState = 'unmet';
        end
        
        function recordingID = startRecording(~,~,~,~,~)
            recordingID     = 'fake_recording_id';
        end
        
        function stopRecording(~)
        end
        
        function finalizeRecording(~)
        end
        
        function discardRecording(~)
        end
        
        function sendStimulusEvent(~,~,~,~,~,~,~)
        end
        
        function sendCustomEvent(~,~,~,~)
        end
    end
    
    methods (Static)
        function tag = makeTag(varargin)
            tag = TalkToProLab.makeTag(varargin{:});
        end
    end
end