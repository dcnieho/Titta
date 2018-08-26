file = '..\TobiiCSDK\64\include\tobii_research.h';

fid = fopen(file,'r');
txt = fread(fid,'*char').';
fclose(fid);

idx = strfind(txt,'Status codes returned by the SDK.');
idxend = find(txt=='}'); idxend = idxend(find(idxend>idx,1));

constants = regexp(txt(idx:idxend),'TOBII_RESEARCH_STATUS_(\w+)','tokens');
constants = cat(1,constants{:});

% now generate some C code to build the lookup map contents
str = [];
for p=1:size(constants,1)
    fullstr = sprintf('TOBII_RESEARCH_STATUS_%s',constants{p});
    str = [str sprintf('    case %1$s:\n        return TobiiResearchStatusInfo{"%1$s", static_cast<int>(%1$s)};\n',fullstr)];
end