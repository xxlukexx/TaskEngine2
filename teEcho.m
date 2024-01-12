function msg = teEcho(varargin)
    if nargin == 1
        msg = sprintf(varargin{1});
    elseif nargin > 1
        msg = sprintf(varargin{1}, varargin{2:end});
    end
    cprintf('Strings', msg)
end