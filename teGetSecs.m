function t = teGetSecs(varargin)
% Returns time in OS realtime (posix) format, and converts between this
% format and CPU time (PTB GetSecs). 
%
% t = TEGETSECS returns the current time in the OS realtime clock (on OSX
% and Linux this means in Posix format). 
%
% t = TEGETSECS(val) converts val, a timestamp in CPU timebase (as provided
% by PTB GetSecs), to OS realtime (posix) format.
%
% t = TEGETSECS(val, 'reverse') converts val, a timestamp in OS realtime
% format, to GetSecs format. 

    % get current time in both formats
    if ~IsLinux
        [gs, posix, ~] = GetSecs('AllClocks');
    else
        gs = GetSecs;
        posix = GetSecs;
    end

    % process input args
    if nargin == 0
        % no input args, just return current time on OS clock format
        t = posix;
        return
        
    elseif nargin == 1
        % assume input argument is a CPU time value, and convert it to
        % posix
        time_cpu = varargin{1};
        if ~isnumeric(time_cpu)
            error('Value must be numeric.')
        end
        
        % calculate offset between current CPU time, and passed CPU time
        offset = gs - time_cpu;
        
        % return posix
        t = posix - offset;         
        
    elseif nargin == 2
        % check that the 'reverse' switch was used
        sw = varargin{2};
        if ~isequal(sw, 'reverse')
            error('Only allowable switch if ''reverse''.')
        end
 
        % assume input argument is a CPU time value, and convert it to
        % posix
        time_os = varargin{1};
        if ~isnumeric(time_os)
            error('Value must be numeric.')
        end
        
        % calculate offset between current CPU time, and passed CPU time
        offset = posix - time_os;
        
        % return posix
        t = gs - offset; 
        
    end
    
end