function [trials, suc, oc, smry_task, smry_trials] = teAutoSegment(data)
% Queries a teData log array to find all events related to a trial
% change. Creates an array of teTrial instances and fills it with data from
% the log array for each trial (including the task that the trial belongs
% to). If eye tracking data is present in the teData instance, it is
% segmented and placed in the teTrial instance. 
% As such, this function will segment each and every trial from a session
% of data, and return the results. 

% defaults in case of early return
   
    trials = [];
    suc = false;
    oc = 'unknown error';
    smry_task = table;

% filter log for trial change events

    % filter the log and store the results in table
    tab = teLogFilter(data.Log.LogArray, 'topic', 'trial_change');
    
    % if the table is empty, return
    if isempty(tab)
        suc = false;
        oc = 'no trials found in log';
        return
    end
    
% in order to understand the trial structure of the log, we query the trial
% GUIDs. This will yield two events per trial, an onset and an offset
% event. 
    
    % get unique guids
    [guid_u, ~, guid_s] = unique(tab.trialguid);
    numTrials = length(guid_u);

    % todo- check that on/offsets can be paired
    
% for each GUID, find an onset and offset marker, and copy it's data into a
% teTrial instance. If eye tracking data is present, segment this using the
% on/offset timestamps from the log
    
    % preallocate teTrial array
    trials = cell(numTrials, 1);
    
    % get big log and events tables. These will be filtered by trial GUID
    % in the loop, but we don't want to process the entire session log in
    % every loop iteration as it will take forever
    uberLogTable = teLogExtract(data.Log.LogArray);
    bigLogTable = teLogFilter(data.Log.LogArray, 'topic', 'trial_log_data');
    bigEventTable = teLogFilter(data.Log.LogArray, 'source', 'teEventRelay_Log');
        
    % loop through all trials
    suc_trials = true(numTrials, 1);
    oc_trials = repmat({''}, numTrials, 1);
    hasET = false(numTrials, 1);
    for t = 1:numTrials
        
    % filter log for just this trial, extract and check on/offset
    % timestamps
    
        % tmp table of just the current trial (GUID)
        tmp = tab(guid_s == t, :);
        
        % store basic info
        date        = tmp.date(1);
        guid        = tmp.trialguid{1};
        task        = tmp.source{1};
        onset       = nan;
        offset      = nan;
        
        % find on/offset events for this trial
        idx_on = find(strcmpi(tmp.data, 'trial_onset'));
        idx_off = find(strcmpi(tmp.data, 'trial_offset'));
        
        % check that onset and offset events were found (otherwise cannot
        % pair)
        if isempty(idx_on)
            suc_trials(t) = false;
            oc_trials{t} = 'onset event not found';
%             continue
            
        elseif isempty(idx_off)
            suc_trials(t) = false;
            oc_trials{t} = 'offset event not found';
%             continue
            
        elseif length(idx_on) > 1
            suc_trials(t) = false;
            oc_trials{t} = sprintf('mutiple onset events found for trial %s',...
                guid_u{t});
%             continue
            
        elseif length(idx_off) > 1
            suc_trials(t) = false;
            oc_trials{t} = sprintf('mutiple offset events found for trial %s',...
                guid_u{t});
%             continue
            
        else
            % retrive on/offsets
            onset       = tmp.timestamp(idx_on);
            offset      = tmp.timestamp(idx_off);     
            
        end
        
    % filter the bigLogTable for trial log data for just this trials.
    % Renove empty columns that belong to other (irrelevant) trials/tasks
        
        % filter big log table for just this trial guid
        idx_log = strcmpi(uberLogTable.trialguid, guid);
        idx_logItems = uberLogTable.logIdx(idx_log);
        lg = teLog(data.Log.LogArray(idx_logItems));
        
        
%         idx_log = strcmpi(bigLogTable.trialguid, guid);
%         logTable = bigLogTable(idx_log, :);
%         li = structArray2cellArrayOfStructs(table2struct(logTable))';
%         lg = teLog(li);
        
%         % remove empty columns
%         colRemIdx = false(size(logTable, 2), 1);
%         for c = 1:size(logTable, 2)
%             if iscell(logTable{1, c})
%                 colRemIdx(c) = all(cellfun(@isempty, logTable{:, c}));
%             elseif isnumeric(logTable{1, c})
%                 colRemIdx(c) = all(arrayfun(@isempty, logTable{:, c}));
%             end
%         end
%         logTable(:, colRemIdx) = [];
        
    % filter bigEventTable for just this trial 
        
        % filter 
        idx_events = strcmpi(bigEventTable.trialguid, guid);
        events = bigEventTable(idx_events, :);

    % instantiate teTrial instance
    
%         trials{t}   = teTrial(date, onset, offset, task, guid, logTable,...
%                         events);        
        trials{t} = teTrial(lg, onset, offset);
        
    % look for eye tracking data. If found, segment for this trial
    
        et = data.ExternalData('eyetracking');
        hasET(t) = suc_trials(t) && ~isempty(et) && et.Valid;
%         hasET(t) = suc_trials(t) && isprop(data, 'EyeTracking') &&...
%             data.EyeTracking.Valid;
        if hasET(t)
            
            % find sample indices for on/offset times (within 10ms)
            s1 = teTimeToSample(et.Buffer, onset, 0.010);
            s2 = teTimeToSample(et.Buffer, offset, 0.010);
            
            % if no sample indices found, use start/end of buffer
            if isempty(s1)
                s1 = 1;
            end
            if isempty(s2)
                s2 = size(et.Buffer, 1);
            end
        
            % check indices
            if isempty(s1) || isempty(s2)
                suc_trials(t) = false;
                oc_trials{t} = sprintf('failed to convert eye tracking timestamps to sample indices for onset: %.4f | offset: %.4f',...
                    onset, offset);
                
            else
                % segment
                trials{t}.EyeTracking = et.Buffer(s1:s2, :);
                
                % make gaze data object
                trials{t}.Gaze = etGazeDataBino('te2', trials{t}.EyeTracking);
            
            end
        end 
        
    end
    
    % report success
    suc = true;
    oc = '';
    numSuccess = sum(suc_trials);
    
    % build task summary
    tasks = cellfun(@(x) x.Task, trials, 'uniform', false);
    [task_u, ~, task_s] = unique(tasks);
    trialNumbers = accumarray(task_s, suc_trials, [], @sum);
    smry_task = table;
    smry_task.Task = task_u;
    smry_task.NumTrials = trialNumbers;
    
    % build trial summary
    smry_trials = table;
    smry_trials.task = tasks;
    smry_trials.success = suc_trials;
    smry_trials.outcome = oc_trials;

end