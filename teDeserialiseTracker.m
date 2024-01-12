function [suc, oc] = teDeserialiseTracker(path_ses)

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
        
    % save
    save(path_tracker, 'tracker')
    
    suc = true;
    oc = '';

end