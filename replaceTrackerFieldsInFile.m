function replaceTrackerFieldsInFile(path_tracker, oldVal, newVal, path_newTracker)

    % load a tracker file, deserialise if necessary, replace any
    % occurrences of oldVal with newVal, then save to path_newTracker
    
    % load
    try
        tmp = load(path_tracker);
    catch ERR
        error('Error loading %s\n\n\t%s', path_tracker, ERR.message);
    end
    fprintf('[replaceTrackerFieldsInFile]: loaded from %s\n', path_tracker);
    
    if isfield(tmp, 'tracker')
        tracker = tmp.tracker;
    else
        error('File %s did not contain a variable named ''tracker''')
    end
    fprintf('[replaceTrackerFieldsInFile]: found tracker variable\n');    

    % the .Log property of the teTracker class has a private SetAccess
    % attribute. To get around this we extract the log array to a variable,
    % edit it, then use teTracker.ReplaceLog method to put it back in. 
    
    % task engine serialises the tracker for fast saving between trials. At
    % the end of the session, it deserialises the object and saves it
    % properly. If the session is interrupted this won't happen, and this
    % function will get passed the serialised version. Check for this and
    % deserialise
    
        if isvector(tracker) && isa(tracker, 'uint8')
            tracker = getArrayFromByteStream(tracker);
            fprintf('[replaceTrackerFieldsInFile]: deserialised tracker object.\n');
        end

    % make sure that we have a valid teTracker object, otherwise throw an
    % error
    
        if ~isa(tracker, 'teTracker')
            error('The tracker variable passed to this function is not a teTracker object, nor one that has been serialised. The data may be corrupted or not saved correctly.')
        else
            fprintf('[replaceTrackerFieldsInFile]: verified tracker class\n')
        end
          
    % replace fields in the log

        lg = tracker.Log;

        numRows = length(lg);
        numLogReplaced = 0;
        for r = 1:numRows

            % get fieldnames for all fields in this row
            fnames = fieldnames(lg{r});
            numFields = length(fnames);

            % loop through fieldnames, looking for old value
            for f = 1:numFields

                % if the value of this field matches old value, replace with
                % new value (note we use isequal not strcmp because the value
                % may not be a string)
                if isequal(lg{r}.(fnames{f}), oldVal)
                    lg{r}.(fnames{f}) = newVal;
                    numLogReplaced = numLogReplaced + 1;
                end

            end

        end

        tracker.ReplaceLog(lg);
        fprintf('[replaceTrackerFieldsInFile]: replaced %d occurrences of %s with %s in log\n',...
            numLogReplaced, oldVal, newVal);
        
    % replace object properties
    
        numPropReplaced = 0;
        pnames = properties(tracker);
        for p = 1:length(pnames)
            
            % only replace property values where the current class of the
            % value matches the class of sought value
            classMatch = isequal(class(tracker.(pnames{p})), class(oldVal));
            
            % only replace if the current property values matches the
            % sought value
            if classMatch
                valMatch = isequal(tracker.(pnames{p}), oldVal);
            else
                valMatch = false;
            end
            
            if classMatch && valMatch
                tracker.(pnames{p}) = newVal;
                numPropReplaced = numPropReplaced + 1;
            end
            
        end
        
        fprintf('[replaceTrackerFieldsInFile]: replaced %d occurrences of %s with %s in class properties\n',...
            numPropReplaced, oldVal, newVal);
               
        
    % save
    try
        save(path_newTracker, 'tracker');
        fprintf('[replaceTrackerFieldsInFile]: saved new tracker to %s\n', path_newTracker);
    catch ERR
        error('Error while attempting to save to %s\n\n\t%s',...
            path_newTracker, ERR.message);
    end
          
end