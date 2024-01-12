function [time_out, time_in, wall] = teGetSecs(varargin)
% this replaces the PTB implementation of GetSecs in order to return time
% in Posix format (seconds elapsed since 1st Jan 1970). The first time it
% is run, it will make a persistent variable recording the (less accurate)
% posix time at that moment. In any future calls, it will take this
% original timestamp and add the latest GetSecs to it. This ensures that
% timestamps returned by this function don't drift and aren't subject to
% clock adjustments (as would happen if we queried the OS Posix time on
% each call)
%
% If passed with an input argument, the function will convert times from
% GetSecs to posix format. This can be used for timestamps that come from
% internal PTB functions and need to be converted into the same units (e.g.
% timestamps from Screen('Flip')
%
% If a posix time is passed as an input argument, and a second argument
% 'reverse' is present, this instructs the function to convert the posix
% time back to GetSecs (CPU) time.

    persistent GETSECS_POSIX_ONSET 

    % if this is the first call, establish the varialbe
    if ~exist('GETSECS_POSIX_ONSET', 'var') || isempty(GETSECS_POSIX_ONSET)
        
        % check for PTB
        AssertOpenGL
        
        % get current time in both GetSecs (since boot) and posix time
        [time_gs, time_posix, ~] = GetSecs('AllClocks');
        
        % subtract GetSecs time to get the posix time at boot. Any
        % subsequent calls can then simply add the GetSecs time to
        % GETSECS_POSIX_ONSET to get the current time in Posix format
        GETSECS_POSIX_ONSET = time_posix - time_gs;
        
    end
   
    % process input arguments
    if nargin == 0
        % no input args, so set direction to be GetSecs -> Posix and call
        % GetSecs to get the current time. This is the standard
        % implemetation, and will return the current time in corrected
        % Posix format
        direction = 'gs2posix';
        [time_in, wall] = GetSecs('AllClocks');
        
    elseif any(cellfun(@(x) isequal('reverse', x), varargin))
        % a posix time was passed as an input argument, along with the
        % 'reverse' switch. Set the direction to Posix -> GetSecs, and make
        % the input time the posix time that was passed
        direction = 'posix2gs';
        time_in = varargin{1};
        wall = [];
        
    else
        % a GetSecs time was passed as an input argument. Set the direction
        % to GetSecs -> Posix. This converts the passed GetSecs time to a
        % corrected Posix time
        direction = 'gs2posix';
        time_in = varargin{1};
        wall = [];
        
    end
    
%     % if no input args, then use GetSecs to get the current time, otherwise
%     % use the input args
%     if nargin == 0
%         [time_in, wall] = GetSecs('AllClocks');
%     else
%         time_in = varargin{1};
%         wall = [];
%     end

    switch direction
        case 'gs2posix'    
            % Add time_in time to GETSECS_POSIX_ONSET to get the current
            % time in Posix format
            time_out = GETSECS_POSIX_ONSET + time_in;
            
        case 'posix2gs'
            % subtract GETSECS_POSIX_ONSET from time_in to convert from
            % posix to GetSecs format
            time_out = time_in - GETSECS_POSIX_ONSET;
            
        otherwise
            % unrecognised direction
            error('Direction unrecognised.')
            
    end
            
end