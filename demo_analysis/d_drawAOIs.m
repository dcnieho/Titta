%*****************************************************************
%*****************************************************************

clear variables; clear mex; close all; fclose('all'); clc

dbstop if error % for debugging: trigger a debug point when an error occurs

thuisdir = cd;
cd function_library;        dirs.funclib    = cd;
cd ..;  cd stimuli;
        cd AOIs;            dirs.AOI        = cd;
        cd ..;
        cd images;          dirs.stim       = cd;
        cd ..;
cd ..;  cd results;         dirs.out        = cd;

cd(thuisdir);

fs = filesep;
addpath(genpath(dirs.funclib));

%*****************************************************************
klr   = {[230 25 75],[245 130 49],[67 99 216],[255 225 25],[60 180 75],[128 0 0],[66 212 244],[240 50 230],[169 169 169]};
trans = [.35 .9];
qAlsoIndivAOIs  = false;

headSize    = 30;
lineWidth   = 10;

%*****************************************************************

% make AOI masks output folder
dirs.out = fullfile(dirs.out,'AOImasks');
if ~isdir(dirs.out)
    mkdir(dirs.out);
end

% kijk welke stimuli we hebben
AOI     = loadAllAOIFolders(dirs.AOI,'png');   % AOI is struct met alle gegevens van de AOI masks

for f=1:length(AOI)
    plaat       = imread(fullfile(dirs.stim, AOI(f).name));
    allAOI      = plaat;
    fprintf(' %s\n',AOI(f).name);
    
    if qAlsoIndivAOIs
        dirs.outf = fullfile(dirs.out,AOI(f).name);
        if ~isdir(dirs.outf)
            mkdir(dirs.outf);
        end
    end
    
    % draw in individual AOIs
    for r=1:length(AOI(f).AOIs)
        fprintf('  AOI: %s\n',AOI(f).AOIs(r).name);
        
        allAOI  = tekenAOIsinplaat(allAOI,AOI(f).AOIs(r).bool,klr{r},trans);
        
        if qAlsoIndivAOIs
            deplaat = tekenAOIsinplaat(plaat ,AOI(f).AOIs(r).bool,klr{r},trans);
            % schrijf weg
            filenaam = [AOI(f).AOIs(r).name '.jpg'];
            imwrite(deplaat,fullfile(dirs.outf,filenaam),'jpg');
        end
    end
    
    imwrite(allAOI,fullfile(dirs.out,AOI(f).name),'png');
end
