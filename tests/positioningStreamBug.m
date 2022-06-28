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

% observed on a Tobii Pro Spectrum
switch 1
    case 1
        % this works fine
        tobii.start('gaze');
        tobii.start('positioning');
        pause(1);
        tobii.stop('positioning');
        tobii.stop('gaze');
        % correct 1: eye tracker switches off
        tobii.start('gaze');
        pause(1);
        tobii.stop('gaze');
        a=tobii.consumeN('gaze')    % correct 2: about one second worth of data, as expected
    case 2
        % this also works fine
        tobii.start('positioning');
        tobii.start('gaze');
        pause(1);
        tobii.stop('gaze');
        tobii.stop('positioning');
        % correct 1
        tobii.start('gaze');
        pause(1);
        tobii.stop('gaze');
        a=tobii.consumeN('gaze')    % correct 2
    case 3
        % this doesn't work
        tobii.start('gaze');
        tobii.start('positioning');
        pause(1);
        tobii.stop('gaze');
        tobii.stop('positioning');
        % symptom 1: eye tracker remains on
        pause(2);   % even pause here doesn't help
        tobii.start('gaze');
        pause(1);
        tobii.stop('gaze');
        % eye tracker is off here
        a=tobii.consumeN('gaze')    % symptom 2: only about half second worth of data?
    case 4
        % this also doesn't work, but even worse (see end of this switch)
        tobii.start('positioning');
        tobii.start('gaze');
        pause(1);
        tobii.stop('positioning');
        tobii.stop('gaze');
        % symptom 1: eye tracker remains on
        pause(2);   % even pause here doesn't help
        tobii.start('gaze');
        pause(1);
        tobii.stop('gaze');
        a=tobii.consumeN('gaze')    % symptom 2: only about half second worth of data?
        % - now eye tracker keeps running even here
        % - when running this code in mode 1 again, you get no data, and
        % eye tracker keeps running. When running in mode 2, you get only 
        % half of data first time, but at least eye tracker switches off.
        % running mode 2 (or 1) again then operator normal again.
end
