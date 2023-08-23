function qOk = checkTime(time,extraval,timestr,framerate)
% checks
validateattributes(time,{'numeric'},[{'nonempty'} extraval],'',timestr)

for p=1:length(time)
    if exist('iptnum2ordinal','file') && ~isscalar(time)
        ord = iptnum2ordinal(p);
        head = sprintf('The %s element of ',ord);
        tail = timestr;
    else
        head = upper(timestr(1));
        tail = timestr(2:end);
    end
    assert(isinf(time(p)) || mod(time(p),1000./framerate)==0, '%s%s (%2.2f ms) is not a multiple of frame duration (%2.2f ms, framerate: %d Hz).',head,tail,time(p),1000./framerate,framerate);
end

qOk = true;