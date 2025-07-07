function [suc, oc, tracker] = teDeserialiseTracker(path_ses)

    suc = false;
    oc = 'unknown error';
      
    path_tracker = teFindFile(path_ses, 'tracker*.mat');
    if isempty(path_tracker)
        suc = false;
        oc = 'Tracker not found';
        return
    end
    
    % load tracker (for log) and deferred events
    tmp = load(path_tracker);
    tracker = tmp.tracker;

    % check for serialised
    if ~isa(tracker, 'uint8') 
        suc = false;
        oc = 'Tracker not serialised';
        return
    end
    
    % deserialise
    tracker = getArrayFromByteStream(tracker);
    
    if ~isa(tracker, 'teTracker')
        oc = sprintf('Deserialised object was not teTracker but %s',...
            class(tracker));
        return
    end
        
    % backup
    path_zip = strrep(path_tracker, '.mat', '_serialised.zip');
    zip(path_zip, path_tracker);
    if ~exist(path_zip, 'file')
        oc = sprintf('Failed to verify backup file: %s', path_zip);
        return
    end
    
    % save
    save(path_tracker, 'tracker')
    
    suc = true;
    oc = '';

end