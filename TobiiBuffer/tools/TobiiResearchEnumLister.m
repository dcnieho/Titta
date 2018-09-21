function TobiiResearchEnumLister

impl('Status codes returned by the SDK.','TOBII_RESEARCH_STATUS_','TobiiResearchStatusInfo');
fprintf('#####\n');
impl(sprintf('\nSource of log message.'),'TOBII_RESEARCH_LOG_SOURCE_','TobiiResearchLogSourceInfo');
fprintf('#####\n');
impl(sprintf('\nLog level.'),'TOBII_RESEARCH_LOG_LEVEL_','TobiiResearchLogLevelInfo');

end



function impl(header,nameRoot,cppClassName)
file = '..\TobiiCSDK\64\include\tobii_research.h';
path = fileparts(mfilename('fullpath'));

fid = fopen(fullfile(path,file),'rt');
txt = fread(fid,'*char').';
fclose(fid);

% TODO: ^is start of input not start of line
idx = regexp(txt,sprintf('%s',regexptranslate('escape',header)));
idxend = find(txt=='}'); idxend = idxend(find(idxend>idx,1));

constants = regexp(txt(idx:idxend),[nameRoot '(\w+)'],'tokens');
constants = cat(1,constants{:});

comments = regexp(txt(idx:idxend),'/\*\*\n\s*([\w\s]+)','tokens');
comments = cat(1,comments{:});

assert(length(constants)==length(comments));

% now generate some C code to build the lookup map contents
str = [];
for p=1:size(constants,1)
    fullstr = sprintf('%s%s',nameRoot,constants{p});
    str = [str sprintf('    case %1$s:\n        return %2$s{"%1$s", static_cast<int>(%1$s), "%3$s"};\n',fullstr,cppClassName,comments{p})];
end
str
end