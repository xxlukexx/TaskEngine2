function [val, sync, reason] = teFT_findSyncOffset(data_te, data_ft)

%% setup

    % default tolerance is 10ms
    if ~exist('tolerance', 'var') || isempty(tolerance)
        tolerance = 10;
    end
    
    val = false;
    sync = struct;
    reason = 'unknown error';
    
    % if fieldtrip data is not passed as a second argument, attempt to
    % extract it form the teData instance
    if ~exist('data_ft', 'var') || isempty(data_ft)
        
        % look for fieldtrip data in ExternalData collection
        ext = data_te.ExternalData('fieldtrip');
        if isempty(ext)
            error('No fieldtrip data was passed. Attempting to extract it from the teData/teSession instance failed.')
        end
        
        % attempt to load external data
        path_ft = ext.Paths('fieldtrip');
        if isempty(path_ft)
            error('No fieldtrip data was passed. Attempting to extract it from the teData/teSession was successful but the path does not exist:\n\n%s',...
                path_ft)
        end
        try
            tmp = load(path_ft);
            if isfield(tmp, 'ft_data')
                data_ft = tmp.ft_data;
            else
                error('No fieldtrip data was passed. Attempting to extract it from the teData/teSession was successful but the data format was incorrect (no ''ft_data'' variable):\n\n%s',...
                    path_ft)
            end
        catch ERR
            error('No fieldtrip data was passed. Attempting to extract it from the teData/teSession was successful but an error occurred when loading the data:\n\n%s',...
                ERR.message)
        end
    end
    
    % read ft events from ft data structure
    if isfield(data_ft, 'events')
        ft_events = data_ft.events;
    else
        error('No ft_events were passed, and failed to find .events field in ft_data.')
    end

    % check events format
    if ~isstruct(ft_events) || ~isfield(ft_events, 'value') ||...
            ~all(arrayfun(@(x) isnumeric(x.value), ft_events))
        reason = '''ft_events'' must be a Fieldtrip events struct';
    end
    
%% extract EEG event data
    
    % get codes and sample indices from fieldtrip data
    codes_eeg = [ft_events.value]';
    samps_eeg = [ft_events.sample]';
    numEEG = length(codes_eeg);
    
    % look for .abstime field in ft data (created by tep). Otherwise
    % create from sample numbers and sampling rate
    if isfield(data_ft, 'abstime')
        time_eeg = data_ft.abstime(samps_eeg);
    else
        time_eeg = samps_eeg / data_ft.fsample;
        warning('No .abstime in ft_data, creating values from sample indices/sampling rate.')
    end

    % convert eeg codes to labels
    lab_eeg = teCodes2RegisteredEvents(data_te.RegisteredEvents,...
        codes_eeg, 'eeg');    
    
    teEcho('Found %d EEG events.\n', numEEG);
    
% extract te event data

    lg = data_te.Log.Events;
    lab_te = lg.data;
    time_te = lg.timestamp;
    numTE = length(lab_te);
    
    teEcho('Found %d Task Engine events.\n', numTE);    
    
% find sync markers in EEG

    % look up reg event for sync
    ev_sync = data_te.RegisteredEvents('SYNC');
    if isempty(ev_sync)
        reason = 'No sync marker in registered events';
        return
    end
    
    % find in markers
    idx_sync_eeg = find(codes_eeg == ev_sync.eeg);
    if isempty(idx_sync_eeg)
        reason = 'No sync markers found in EEG';
        return
    end
    
    numSync_eeg = length(idx_sync_eeg);
    teEcho('Found %d EEG sync markers.\n', numSync_eeg);

    % find timestamps of sync event(s)
    
    
%     % if ~2 markers, return for now (in future will write code to still
%     % check sync with one marker)
%     if length(idx_sync_eeg) ~= 2
%         reason = 'More or less than two markers found in EEG data';
%         return
%     end
    
% find SYNC markers in log

    % get log data from tracker
    idx_sync_te = find(strcmpi(lab_te, 'SYNC'));
    if isempty(idx_sync_te)
        reason = 'No sync markers found in Task Engine data.';
        return
    end
    
    numSync_te = length(idx_sync_te);
    teEcho('Found %d Task Engine sync markers.\n', numSync_te);
    
%     % if ~2 markers, return for now (in future will write code to still
%     % check sync with one marker)
%     if length(idx_sync_te) ~= 2
%         reason = 'More or less than two markers found in Task Engine data';
%         return
%     end    

% find SYNC marker pairs to test

    numPairs = numSync_te * numSync_eeg;
    pairs = zeros(numPairs, 2);
    p = 1;
    for i_te = 1:numSync_te
        for i_eeg = 1:numSync_eeg
            pairs(p, 1) = idx_sync_te(i_te);
            pairs(p, 2) = idx_sync_eeg(i_eeg);
            p = p + 1;
        end
    end
    teEcho('Testing %d pairs of sync markers for accuracy.\n', numPairs);
    
% calculate sync offsets for each pair. Offsets are eeg - te, so we arrive
% at a value that, when ADDED to the te markers, gives the eeg marker
% value

    % look up timestamps 
    pairs_t(:, 1) = time_te(pairs(:, 1));
    pairs_t(:, 2) = time_eeg(pairs(:, 2));
    
    % calculate offsets
    pairs_off = pairs_t(:, 2) - pairs_t(:, 1);
    
% test each sync marker pair

    val_match = false(numEEG, numPairs);
    reason_match = repmat({'unknown error'}, numEEG, numPairs);
    t_err = nan(numEEG, numPairs);
    t_te = nan(numEEG, numPairs);
    matched_event_te = cell(numEEG, numPairs);
    idx_te = nan(numEEG, numPairs);

    tab = cell(1, numPairs);
    sync_r2 = nan(1, numPairs);
    mdl = cell(1, numPairs);
    
    for p = 1:numPairs
        
        s1 = 1;
        for e = 1:numEEG
            
            reason_match{e} = 'unknown error';
                        
            % find eeg timestamps, add tolerance window, and shift by
            % offset to convert to te time
%             t1 = time_eeg(e) - tolerance - pairs_off(p);
%             t2 = time_eeg(e) + tolerance - pairs_off(p);
            t_cent = time_eeg(e);
            
            % check t1 is within bounds of te timestamps
            if t_cent > time_te(end)
                reason_match{e} = 'EEG timestamp beyond bounds of Task Engine events';
                continue
            end
            
%             % find te timestamp that is closest to the centre of the search
%             % window
%             t_cent = t1 + ((t2 - t1) / 2);
            
            % find distance of each te sample to the centre of the EEG
            % search window
            dis_te = abs(time_te(s1:end) - t_cent);
            
            % find the closest sample (relative to start of all te markers)
            idx_cand = find(dis_te <= tolerance);
            
%             % convert timestamps to samples
%             s1 = s1 - 1 + find(time_te(s1:end) >= t1, 1, 'first');
%             s2 = s1 - 1 + find(time_te(s1:end) >= t2, 1, 'first') - 1;
%             
%             % if s2 not found, set it to s1
%             if isempty(s2), s2 = s1; end
            
            % get event and timestamp for candidate te events (within
            % tolerance window)
            event_te = lg.data(idx_cand);
            eventTime_te = lg.timestamp(idx_cand);
%             event_te = lg.data(s1:s2);
%             eventTime_te = lg.timestamp(s1:s2);
            
            if isempty(event_te)
                reason_match{e} = 'no te events within tolerance';
                continue
            end
            
            % do any te events match the EEG event?
            match = cellfun(@(x) isequal(lab_eeg{e}, x), event_te);
            
            % filter for matched events
            event_te = event_te(match);
            eventTime_te = eventTime_te(match);
            
            % calculate timing error between this EEG event and all
            % candidate te events
            terr = time_eeg(e) - eventTime_te - pairs_off(p);
            
            % determine number of matches
            if ~any(match) 
                
                % no match
                reason_match{e} = 'no te event labels matched';
                continue
                
            elseif sum(match) ~= 1
                
                % multiple matches, select by timing error
                idx_closest = abs(terr) == min(abs(terr));
                terr = terr(idx_closest);
                event_te = event_te(idx_closest);
                eventTime_te = eventTime_te(idx_closest);
                idx_te(e, p) = idx_closest;
                
            end
            
            reason_match{e} = '';
            val_match(e) = true;
            t_err(e, p) = terr';
            t_te(e, p) = eventTime_te;
            matched_event_te(e) = event_te;
            
        end
        
        tab{p} = table;
        tab{p}.eeg_code = codes_eeg;
        tab{p}.eeg_label = lab_eeg;
        tab{p}.eeg_idx = (1:numEEG)';
        tab{p}.event_matched = val_match(:, p);
        tab{p}.failure_reason = reason_match(:, p);
        tab{p}.matched_te_event = matched_event_te(:, p);
        tab{p}.eeg_time = time_eeg;
        tab{p}.te_time = t_te(:, p);
        tab{p}.timing_error = t_err(:, p);
        tab{p}.event_time_matched = abs(t_err(:, p)) < tolerance;
        
        % linear regression to test fit of sync
        x = t_te(val_match(:, p), p);
        y = time_eeg(val_match(:, p));
        if ~isempty(x) && ~isempty(y)
            mdl{p} = fitlm(x, y);
            sync_r2(p) = mdl{p}.Rsquared.Ordinary;
        else
            mdl{p} = [];
            sync_r2(p) = -inf;
        end
       
    end
    
% assess fit of each sync pair

    best_idx = sync_r2 == max(sync_r2);
    best_pair = pairs(best_idx, :);
    sync.offset = pairs_off(best_idx);
    sync.best_r2 = sync_r2(best_idx);
    sync.event_te_idx = best_pair(1);
    sync.event_eeg_idx = best_pair(2);
    sync.match_table = tab{best_idx};
    if ~isempty(mdl{p})
        sync.intercept = mdl{best_idx}.Coefficients{1, 1};
        sync.B1 = mdl{best_idx}.Coefficients{2, 1};
    end
    
    val = true;
    reason = {''};

end