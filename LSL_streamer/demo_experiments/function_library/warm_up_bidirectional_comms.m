function warm_up_bidirectional_comms(outlet, inlet)
% don't ask. need to try to send and receive back and forth
% some times for both channels to come online and start
% sending and receiving without samples being dropped...
remoteConnEst = false;
while ~outlet.have_consumers()
    outlet.push_sample({'warm up'})
    sample = inlet.pull_sample(0.1);
    if ~isempty(sample) && strcmp(sample{1},'connection established')
        remoteConnEst = true;
    end
end
outlet.push_sample({'connection established'})
if ~remoteConnEst
    inlet.pull_sample();
end