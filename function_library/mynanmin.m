function y = mynanmin(varargin)
persistent isOctave;
if isempty(isOctave)
    isOctave = ismember(exist('OCTAVE_VERSION', 'builtin'), [102, 5]);
    if isOctave
        pkg load statistics
    end
end

if isOctave
    y = nanmin(varargin{:});
else
    y = min(varargin{:},'omitnan');
end