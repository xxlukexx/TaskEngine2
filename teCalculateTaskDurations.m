function tab = teCalculateTaskDurations(logArray)

    onsets = teLogFilter(logArray, 'topic', 'task_change', 'data', 'task_onset');
    offsets = teLogFilter(logArray, 'topic', 'task_change', 'data', 'task_offset');
    if ~isequal(size(onsets), size(offsets))
        tab = [];
        return
    end
    tab = onsets(:, {'source'});
    tab.duration = offsets.timestamp - onsets.timestamp;
    [u, ~, s] = unique(tab.source);
    m = accumarray(s, tab.duration, [], @sum);
    tab = table;
    tab.Task = u;
    tab.TotalDurationSecs = m;
    tab.TotalDurationMins = m / 60;
    
end