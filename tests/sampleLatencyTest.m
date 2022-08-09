clear all, close all
theDir = fileparts(mfilename('fullpath'));
cd(theDir);
cd ..;
addTittaToPath;
cd(theDir);

tobii = TittaMex();
trackers = tobii.findAllEyeTrackers();
tracker = trackers(1);
tobii.init(tracker.address)
hasEyeOpenness = tobii.hasStream('eyeOpenness');
tobii.setIncludeEyeOpennessInGaze(false);
if false
    tobii.frequency = 1200;
else
    tobii.frequency =  600;
end

% warm up systemTimestamp
for p=1:10
    tobii.systemTimestamp;
end

nSamp = 5000;

a = zeros(4,nSamp,'int64');
i=1;
tobii.start('gaze');
tic
while i<=length(a)
    samp = tobii.consumeN('gaze');
    if ~isempty(samp.deviceTimeStamp)
        a(1,i) = tobii.systemTimestamp;
        a(2,i) = samp.systemTimeStamp(end);
        a(3,i) = samp.deviceTimeStamp(end);
        a(4,i) = length(samp.systemTimeStamp);
        i=i+1;
    end
    if i==2000 && hasEyeOpenness
        tobii.start('eyeOpenness');
    end
    if i==3000 && hasEyeOpenness
        tobii.stop('gaze');
    end
    if i==4000 && hasEyeOpenness
        tobii.start('gaze');
        tobii.stop('eyeOpenness');
    end
    if KbCheck
        break 
    end
end
toc
tobii.stop('gaze');

if i<length(a) 
    a(:,i:end) = [];
end

fhndl = figure;
ax1 = subplot(3,1,1);
plot(double(diff(a(1,:)))/1000), hold on
plot(double(diff(a(2,:)))/1000)
plot(double(diff(a(3,:)))/1000)
ylabel('intersample interval (ms)')
legend('GetSecs','system timestamp','device timestamp','Location','NorthEast')
ax2 = subplot(3,1,2);
plot(double(a(1,:)-a(2,:))/1000)
ylabel('latency (ms)')
ax3 = subplot(3,1,3);
plot(a(4,2:end))
ylabel('number of samples received')
xlabel('sample #')
linkaxes([ax1 ax2 ax3],'x')
if isprop(fhndl,'WindowState')
    fhndl.WindowState = 'maximized';
end

tic
% just a check on how long tobii.systemTimestamp takes, to be sure that
% doesn't dominate our results
for p=1:nSamp
    tobii.systemTimestamp;
end
toc