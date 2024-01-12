function ts = teGetTrialStructure(data, task)
% Creates a table containing trial GUIDs, on/offset timestamps, and
% duration for each trial, for a particular task.

    % determine input format (teLog or teData)
    if isa(data, 'teLog')
        lg = data;
    elseif isa(data, 'teData')
        lg = data.Log;
    else
        error('Input must be teLog or teData instance.')
    end
    tab = teLogFilter(lg.LogArray, 'topic', 'trial_change',...
        'source', task);
    
% in order to understand the trial structure of the log, we query the trial
% GUIDs. This will yield two events per trial, an onset and an offset
% event. 
    
    % get unique guids
    [guid_u, ~, guid_s] = unique(tab.trialguid);
    numTrials = length(guid_u);

    % todo- check that on/offsets can be paired
    
% for each GUID, find an onset and offset marker, and extract their
% timestamps

    % loop through all trials
    suc = true(numTrials, 1);
    oc = repmat({''}, numTrials, 1);
    onset = nan(numTrials, 1);
    offset = nan(numTrials, 1);
    for t = 1:numTrials
        
    % filter log for just this trial, extract and check on/offset
    % timestamps
    
        % tmp table of just the current trial (GUID)
        tmp = tab(guid_s == t, :);
        
        % find on/offset events for this trial
        idx_on = find(strcmpi(tmp.data, 'trial_onset'));
        idx_off = find(strcmpi(tmp.data, 'trial_offset'));
        
        % check that onset and offset events were found (otherwise cannot
        % pair)
        if isempty(idx_on)
            suc(t) = false;
            oc{t} = 'onset event not found';
            
        elseif isempty(idx_off)
            suc(t) = false;
            oc{t} = 'offset event not found';
            
        elseif length(idx_on) > 1
            suc(t) = false;
            oc{t} = sprintf('mutiple onset events found for trial %s',...
                guid_u{t});
            
        elseif length(idx_off) > 1
            suc(t) = false;
            oc{t} = sprintf('mutiple offset events found for trial %s',...
                guid_u{t});
            
        else
            % retrive on/offsets
            onset(t)       = tmp.timestamp(idx_on);
            offset(t)      = tmp.timestamp(idx_off);     
            
        end    
        
    end
    
    ts = table;
    ts.valid = suc;
    ts.error = oc;
    ts.task = repmat({task}, numTrials, 1);
    ts.onset = onset;
    ts.offset = offset;
    ts.duration = offset - onset;
    ts.trialguid = guid_u;
    ts = sortrows(ts, 'onset');
    ts.trialno(1:numTrials, 1) = 1:numTrials;
    
end