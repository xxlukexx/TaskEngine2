function teRenameSession(path_ses, id_new)
    
    % check valid session
    [is, reason, file_tracker, tracker] = teIsSession(path_ses);
    if ~is
        error('Session path (%s) was not recognised as a valid Task Engine session. Reason was:\n\n\t%s',...
            path_ses, reason);
    end
    
    % load tracker
    id_old = tracker.ID;
    fprintf('<strong>[teRenameSession]</strong>: Loaded tracker from: %s\n',...
        file_tracker);
    fprintf('<strong>[teRenameSession]</strong>: Existing ID is: %s. Will be renamed to: %s\n',...
        id_old, id_new);
    
    % rename ID in tracker
    tracker.ID = id_new;
    fprintf('<strong>[teRenameSession]</strong>: Renamed tracker ID\n');

    % rename ID in log
    numLog = length(tracker.Log);
    numLogRenamed = 0;
    for li = 1:numLog
        if isfield(tracker.Log{li}, 'id')
            tracker.Log{li}.id = id_new;
            numLogRenamed = numLogRenamed + 1;
        end
    end
    fprintf('<strong>[teRenameSession]</strong>: Renamed %d occurrences of ''id'' in the log\n',...
        numLogRenamed);
    
    % save
    [suc, oc] = teBackupAndReplaceFile(tracker, 'tracker',...
        file_tracker, 'teRenameSession');
    if ~suc
        error('Error when renaming tracker: %s', oc);
    else
        fprintf('<strong>[teRenameSession]</strong>: Saved renamed tracker to: %s\n',...
            file_tracker);
    end
        
end