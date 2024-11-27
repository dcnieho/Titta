function [x,y] = tobii_get_gaze(samples, ts_field, filters, client, scrRes)
[x,y] = deal(nan);
if isempty(samples.(ts_field))
    return;
end

qFilter = strcmp(filters(:,1),client);
if ~any(qFilter)
    [~,x,y] = get_sample(samples,-1,ts_field,scrRes);
    return
end

for i=1:length(samples.(ts_field))
    [ts,x,y] = get_sample(samples,i,ts_field,scrRes);
    [x,y] = filters{qFilter,2}.addSample(ts,x,y);
end


function [ts,x,y] = get_sample(samples,idx,ts_field,scrRes)
if idx==-1
    idx = length(samples.(ts_field));
end
lx = samples.left.gazePoint.onDisplayArea(1,idx);
ly = samples.left.gazePoint.onDisplayArea(2,idx);
rx = samples.right.gazePoint.onDisplayArea(1,idx);
ry = samples.right.gazePoint.onDisplayArea(2,idx);
x = mean([lx, rx], 'omitnan') * scrRes(1);
y = mean([ly, ry], 'omitnan') * scrRes(2);
ts= double(samples.(ts_field)(idx))/1000;   % convert us->ms