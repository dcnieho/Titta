function demoCalCompletionFun(titta_instance,currentPoint,posNorm,posPix,stage,calState)
% NB: calState only provided if stage=='cal'
if strcmp(stage,'cal')
    if calState.status==0
        status = 'ok';
    else
        status = sprintf('failed (%s)',calState.statusString);
    end
    titta_instance.sendMessage(sprintf('Calibration data collection status result for point %d, positioned at (%.2f,%.2f): %s',currentPoint,posNorm,status));
else
    titta_instance.sendMessage(sprintf('Validation data collection collected for point %d, positioned at (%.2f,%.2f)',currentPoint,posNorm));
end