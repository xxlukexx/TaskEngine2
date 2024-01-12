function posix = teGetSecs2Posix(gs)
% converts between the output of GetSecs, which is in the format of the
% system CPU clock (counting from when the computer was switched on - aka
% an arbitrary zero point) and posix dates*.
%
%   * at least on macOS and Linux - on Windows these may not strictly be
%   posix dates in the sense that they are not relative to 19700101, but
%   the principle is the same

    % get current time in both GetSecs and Posix formats
    [nowGS, nowPosix, ~] = GetSecs('AllClocks');
    
    % calculate the offset between the two
    offset = nowPosix - nowGS;
    
    % apply the offset to the passed value
    posix = gs + offset;
    
end