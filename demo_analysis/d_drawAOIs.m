clear variables; clear global; clear mex; close all; fclose('all'); clc

dbstop if error % for debugging: trigger a debug point when an error occurs

% setup directories
myDir = fileparts(mfilename('fullpath'));
cd(myDir);
                                dirs.home       = cd;
cd function_library;            dirs.funclib    = cd;
cd ..;  cd stimuli;             dirs.stims      = cd;
cd ..;  cd AOIs;                dirs.AOIs       = cd;
cd ..;  cd results;             dirs.out        = cd;
cd ..;
addpath(genpath(dirs.funclib));                 % add dirs to path

%*****************************************************************
clr   = {[230 25 75],[245 130 49],[67 99 216],[255 225 25],[60 180 75],[128 0 0],[66 212 244],[240 50 230],[169 169 169]};
trans = [.35 .9];
qAlsoIndivAOIs  = false;    % if true, also save image for each individual AOI
%*****************************************************************

% make AOI masks output folder
dirs.out = fullfile(dirs.out,'AOImasks');
if ~isdir(dirs.out) %#ok<ISDIR> 
    mkdir(dirs.out);
end

% see for which stimuli we have AOIs
AOIs    = loadAllAOIFolders(dirs.AOIs,'png');

for f=1:length(AOIs)
    img     = imread(fullfile(dirs.stims, AOIs(f).name));
    allAOI  = img;
    fprintf(' %s\n',AOIs(f).name);
    
    if qAlsoIndivAOIs
        dirs.outf = fullfile(dirs.out,[AOIs(f).name '_AOIs']);
        if ~isdir(dirs.outf) %#ok<ISDIR> 
            mkdir(dirs.outf);
        end
    end
    
    % draw in individual AOIs
    for r=1:length(AOIs(f).AOIs)
        fprintf('  AOI: %s\n',AOIs(f).AOIs(r).name);
        
        allAOI  = drawAOIsOnImage(allAOI,AOIs(f).AOIs(r).bool,clr{r},trans);
        
        if qAlsoIndivAOIs
            AOIimage = drawAOIsOnImage(img ,AOIs(f).AOIs(r).bool,clr{r},trans);
            filenaam = [AOIs(f).AOIs(r).name '.jpg'];
            imwrite(AOIimage,fullfile(dirs.outf,filenaam),'jpg');
        end
    end
    
    imwrite(allAOI,fullfile(dirs.out,AOIs(f).name));
end
