function TobiiResearchEnumLister
cd(fileparts(mfilename('fullpath')))

file = fullfile(cd,'..','deps','include','tobii_research.h');
impl(file,'Status codes returned by the SDK.','TOBII_RESEARCH_STATUS_','TobiiResearchStatusInfo');
fprintf('#####\n');
impl(file,sprintf('\nSource of log message.'),'TOBII_RESEARCH_LOG_SOURCE_','TobiiResearchLogSourceInfo');
fprintf('#####\n');
impl(file,sprintf('\nLog level.'),'TOBII_RESEARCH_LOG_LEVEL_','TobiiResearchLogLevelInfo');
fprintf('#####\n');

file = fullfile(cd,'..','deps','include','tobii_research_streams.h');
impl(file,'Defines error types','TOBII_RESEARCH_STREAM_ERROR_','TobiiResearchStreamErrorInfo');
impl(file,'Defines error sources','TOBII_RESEARCH_STREAM_ERROR_SOURCE_','TobiiResearchStreamErrorSourceInfo');
impl(file,'Defines notification types','TOBII_RESEARCH_NOTIFICATION_','TobiiResearchNotificationTypeInfo');
impl(file,'Defines eye image type','TOBII_RESEARCH_EYE_IMAGE_TYPE_','TobiiResearchEyeImageTypeInfo');

file = fullfile(cd,'..','deps','include','tobii_research_eyetracker.h');
impl(file,'Specifies license validation result.','TOBII_RESEARCH_LICENSE_VALIDATION_RESULT_','TobiiResearchLicenseValidationResultInfo');

file = fullfile(cd,'..','deps','include','tobii_research_calibration.h');
impl(file,'Defines the validity of calibration eye data.','TOBII_RESEARCH_CALIBRATION_EYE_VALIDITY_','TobiiResearchCalibrationEyeValidity');

end



function impl(file,header,nameRoot,cppClassName)
fid = fopen(file,'rt');
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
