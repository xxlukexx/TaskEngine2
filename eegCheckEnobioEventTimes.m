function tab = eegCheckEnobioEventTimes(path_raw)

    raw = load(path_raw);
    ev = raw(:, end - 1);
    % get indices of valid events
    val = ev > 0 & ev < 255;
    if ~any(val)
        fprintf('No events found.\n')
        tab = [];
        return
    end
    % get timestamps
    ts = raw(val, end);
    delta = [nan; diff(ts)];
    tab = array2table([ts, ts - ts(1), ev(val), delta], 'variablenames', {'Timestamp', 'Elapsed', 'Value', 'Delta'});

end