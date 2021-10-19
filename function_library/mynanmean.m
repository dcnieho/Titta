function y = mynanmean(varargin)
persistent isOctave;
if isempty(isOctave)
    isOctave = ismember(exist('OCTAVE_VERSION', 'builtin'), [102, 5]);
    if isOctave
        pkg load statistics
    end
end

if isOctave
    y = nanmean(varargin{:});
else
    y = mean(varargin{:},'omitnan');
end