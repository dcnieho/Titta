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
                thisInfo    = ?TalkToProLabDummyMode;
                thisMethods = thisInfo.MethodList;
                superInfo   = ?TalkToProLab;
                superMethods= superInfo.MethodList;
                % for both, remove their constructors from list and limit
                % to only public methods
                superMethods(~strcmp({superMethods.Access},'public') | (~~[superMethods.Static]) | ismember({superMethods.Name},{'TalkToProLab'})) = [];
                thisMethods (~strcmp( {thisMethods.Access},'public') | (~~ [thisMethods.Static]) | ismember( {thisMethods.Name},{'TalkToProLabDummyMode'})) = [];
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
                qNotOverridden = ~ismember({superMethods.Name},{thisMethods.Name});
                if any(qNotOverridden)
                    fprintf('methods from %s not overridden in %s:\n',superInfo.Name,thisInfo.Name);
                    fprintf('  %s\n',superMethods(qNotOverridden).Name);
                end
                
                % 3. right number of input arguments?
                qMatchingInput = false(size(thisMethods));
                for p=1:length(thisMethods)
                    realMethod = superMethods(strcmp({superMethods.Name},thisMethods(p).Name));
                    if isscalar(realMethod)
                        qMatchingInput(p) = (length(realMethod.InputNames) == length(thisMethods(p).InputNames)) || (length(realMethod.InputNames) < length(thisMethods(p).InputNames) && strcmp(realMethod.InputNames{end},'varargin')) || (length(thisMethods(p).InputNames) < length(realMethod.InputNames) && strcmp(thisMethods(p).InputNames{end},'varargin'));
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
        end
        
        function delete(~)
        end
        
        function disconnect(~)
        end
        
        function participantID = createParticipant(~,~,~)
            participantID = 'fake_participant_id';
        end
        
        function [mediaID,mediaInfo] = findMedia(~,~,~)
            mediaID     = '';
            mediaInfo   = struct();
        end
        
        function [mediaID,wasUploaded] = uploadMedia(~,~,~)
            mediaID = '';
            wasUploaded = false;
        end
        
        function attachAOIToImage(~,~,~,~,~,~)
        end
        
        function attachAOIToVideo(~,~,~)
        end
        
        function EPState = getExternalPresenterState(~)
            EPState = 'ready';
        end
        
        function recordingID = startRecording(~,~,~,~,~,~)
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
        function tag = makeAOITag(varargin)
            tag = TalkToProLab.makeAOITag(varargin{:});
        end
    end
end
