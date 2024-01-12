function [suc, oc] = teIntegrateDeferredEvents(path_ses)

    suc = false;
    oc = 'unknown error';
    
    path_def = teFindFile(path_ses, '*deferred.mat');
    if isempty(path_def)
        suc = false;
        oc = 'Deferred events file not found';
        return
    end
    
    path_tracker = teFindFile(path_ses, 'tracker*.mat');
    if isempty(path_tracker)
        suc = false;
        oc = 'Tracker not found';
        return
    end
    
    % load tracker (for log) and deferred events
    try
        tmp = load(path_tracker);
        tracker = tmp.tracker;
    catch ERR
        suc = false;
        oc = ERR.message;
        return
    end
    
    try
        tmp = load(path_def);
        dfr = tmp.deferred;
    catch ERR
        suc = false;
        oc = ERR.message;
        return
    end
    
    % convert both to table
    ts_tracker = cellfun(@(x) x.timestamp, tracker.Log);
    ts_dfr = cellfun(@(x) x.timestamp, dfr);
    
    % find deferred events not in log
    idx_dfr = ~ismember(ts_dfr, ts_tracker);
    
    % add to tracker log
    if any(idx_dfr)
        tracker.AppendLog(dfr(idx_dfr));
    end
    
    % backup old tracker and save new one
    file_zip = sprintf('%s.zip', path_tracker);
    zip(file_zip, {path_tracker, path_def})
%     delete(path_tracker)
    delete(path_def)
    save(path_tracker, 'tracker')
    
    suc = true;
    oc = '';

end