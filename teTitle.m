function msg = teTitle(varargin)
    bar = sprintf('\n%s\n', char(repmat(9604, 1, 90)));
    if nargin == 1
        msg = sprintf(varargin{1});
    elseif nargin > 1
        msg = sprintf(varargin{1}, varargin{2:end});
    end
    cprintf('*Strings', bar)
    if ~isempty(varargin), cprintf('*Strings', msg), end
end