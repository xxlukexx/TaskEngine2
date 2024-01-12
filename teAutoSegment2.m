function [trials, suc, oc, smry_task, smry_trials] = teAutoSegment2(data)
% Queries a teData object and finds all trial_change events. Generates
% label pairs of trial_onset and trial_offset for each trial. 
% As such, this function will segment each and every trial from a session
% of data, and return the results. 

% defaults in case of early return
   
    trials = [];
    suc = false;
    oc = 'unknown error';
    smry_task = table;
    
% filter log for events with a trial GUID

    idx_hasGUID = ~cellfun(@isempty, data.Log.LogTable.trialguid);
    tab = data.Log.LogTable(idx_hasGUID, :);
    
% query the log for unique trial GUIDs. Each query will return a number of
% events. We want the index in the original log array of the first and last
% event corresponding to the trial GUID (aka the first and last event of
% that trial). 

    % save some time by extracting all trial GUIDs from the table to a cell
    % array
    trialGUID = tab.trialguid;
    logIdx = tab.logIdx;
    timestamps = tab.timestamp;
    
    % get unique guids
    [guid_u, ~, guid_s] = unique(trialGUID);
    numTrials = length(guid_u);
    
    % for each guid (trial), find the first and last log entry
    timestamps_seg = nan(numTrials, 2);
    for t = 1:numTrials
      
        % find the index (in the filtered table) of the first event with
        % the current trial GUID
        idx_tab_onset = find(guid_s == t, 1, 'first');
        idx_tab_offset = find(guid_s == t, 1, 'last');
        
        % query the logidx table variable to translate these to indices in
        % the original log array
        timestamps_seg(t, 1) = timestamps(idx_tab_onset);
        timestamps_seg(t, 2) = timestamps(idx_tab_offset);

    end
    
% pass to the cutter function to create teTrial instances for each pair of
% log indices

    [~, ~, trials] = teCutter(data, timestamps_seg);
    suc = true;
    oc = '';

end