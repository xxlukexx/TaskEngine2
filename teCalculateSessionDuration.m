function dur = teCalculateSessionDuration(tracker)
% calculates the duration of a session by interrogating the tracker start
% and end time. If either is empty, or NaN, returns NaN

    if isempty(tracker.SessionStartTime) ||...
            isempty(tracker.SessionEndTime)
        dur = nan;
    else
        dur = tracker.SessionEndTime - tracker.SessionStartTime;
    end
    
end