% this demo code is part of Titta, a toolbox providing convenient access to
% eye tracking functionality using Tobii eye trackers
%
% Titta can be found at https://github.com/dcnieho/Titta. Check there for
% the latest version.
% When using Titta, please cite the following paper:
%
% Niehorster, D.C., Andersson, R. & Nystrom, M., (2020). Titta: A toolbox
% for creating Psychtoolbox and Psychopy experiments with Tobii eye
% trackers. Behavior Research Methods.
% doi: https://doi.org/10.3758/s13428-020-01358-8

clear variables; clear global; clear mex; close all; fclose('all'); clc

dbstop if error % for debugging: trigger a debug point when an error occurs

% setup directories
myDir = fileparts(mfilename('fullpath'));
cd(myDir);
cd data;                        dirs.data       = cd;
        cd mat;                 dirs.mat        = cd;
cd ..;
cd ..;  cd function_library;    dirs.funclib    = cd;
cd ..;  cd results;             dirs.out        = cd;
cd ..;
addpath(genpath(dirs.funclib));                 % add dirs to path


%%% get all trials, parse into subject and stimulus
[files,nfiles]  = FileFromFolder(dirs.mat,[],'mat');


fid = fopen(fullfile(dirs.out,'validation_accuracy.xls'),'wt');
fprintf(fid,'subject\tacc LX\tacc LY\tacc RX\tacc RY\n');

for p=1:nfiles
    fprintf('%s\n',files(p).fname);
    
    % load data file
    C = load(fullfile(dirs.mat,files(p).name),'calibration');
    if C.calibration{end}.wasSkipped
        acc = nan(1,4);
    elseif strcmp(C.calibration{end}.type,'standard')
        sel = C.calibration{end}.selectedCal;
        cal = C.calibration{end}.attempt{sel};
        if ~isfield(cal.val{end},'acc2D')
            % no validation done
            acc = nan(1,4);
        else
            acc = cal.val{end}.acc2D(:).'; % [LX LY RX RY]
        end
    elseif strcmp(C.calibration{end}.type,'advanced')
        sel = C.calibration{end}.selectedCal;
        cal = C.calibration{end}.attempt{sel(1)};
        if ~isfield(cal,'val')
            % no validation done
            acc = nan(1,4);
        else
            % find the active/last valid validation for this
            % calibration, if any
            whichCals = cellfun(@(x) x.whichCal, cal.val);
            idx     = find(whichCals==sel(2),1,'last');
            if isempty(idx) || ~isfield(cal.val{idx},'allPoints')
                % no validation done for this calibration, or all
                % validation data discarded again by operator
                acc = nan(1,4);
            else
                acc = cal.val{idx}.allPoints.acc2D(:).';
            end
        end
    end

    % print to file
    fprintf(fid,'%s\t%.3f\t%.3f\t%.3f\t%.3f\n',files(p).fname,acc);
end
fclose(fid);

rmpath(genpath(dirs.funclib));                  % cleanup path
