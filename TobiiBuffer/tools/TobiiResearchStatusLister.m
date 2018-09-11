file = '..\TobiiCSDK\64\include\tobii_research.h';
path = fileparts(mfilename('fullpath'));

fid = fopen(fullfile(path,file),'rt');
txt = fread(fid,'*char').';
fclose(fid);

idx = strfind(txt,'Status codes returned by the SDK.');
idxend = find(txt=='}'); idxend = idxend(find(idxend>idx,1));

constants = regexp(txt(idx:idxend),'TOBII_RESEARCH_STATUS_(\w+)','tokens');
constants = cat(1,constants{:});

errorMsgs = regexp(txt(idx:idxend),'/\*\*\n\s*([\w\s]+)','tokens');
errorMsgs = cat(1,errorMsgs{:});

assert(length(constants)==length(errorMsgs));

% now generate some C code to build the lookup map contents
str = [];
for p=1:size(constants,1)
    fullstr = sprintf('TOBII_RESEARCH_STATUS_%s',constants{p});
    str = [str sprintf('    case %1$s:\n        return TobiiResearchStatusInfo{"%1$s", static_cast<int>(%1$s), "%2$s"};\n',fullstr,errorMsgs{p})];
end