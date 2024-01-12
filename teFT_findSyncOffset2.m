function [val, sync, reason] = teFT_findSyncOffset2(data_te, data_ft, varargin)

%% setup

    % default tolerance is 10ms
    if ~exist('tolerance', 'var') || isempty(tolerance)
        tolerance = 10;
    end
    
    % process optional switches
    removeEnobio255 = ismember('-removeEnobio255', varargin);
    
    val = false;
    sync = struct;
    reason = 'unknown error';
    
    % if fieldtrip data is not passed as a second argument, attempt to
    % extract it form the teData instance
    if ~exist('data_ft', 'var') || isempty(data_ft)
        
        % look for fieldtrip data in ExternalData collection
        ext = data_te.ExternalData('fieldtrip');
        if isempty(ext)
            error('No fieldtrip data was passed. Attempting to extract it from the teData/teSession instance failed (no fieldtrip external data).')
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

    % Enobio puts 255 event codes into the data when it drops a wireless
    % data packet. Optionally (via the -removeEnobio255 switch) remove
    % these
    if removeEnobio255
        
        % convert event struct to table (for easier editing)
        tab_ev = struct2table(ft_events);
        
        % find and remove 255s form the table
        idx_255 = tab_ev.value == 255;
        tab_ev(idx_255, :) = [];
        
        % convert back from table to struct
        ft_events = table2struct(tab_ev);
        
    end
        
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
    
    % put all details of EEG events into a table
    tab_eeg = table;
    tab_eeg.code = codes_eeg;
    tab_eeg.sample = samps_eeg;
    tab_eeg.timestamp = time_eeg;
    tab_eeg.label = lab_eeg;
    
    teEcho('Found %d EEG events.\n', numEEG);
    
% extract te event data

    tab_te = data_te.Log.Events;
    lab_te = tab_te.data;
    time_te = tab_te.timestamp;
    numTE = length(lab_te);
    
    % if any te event labels are numeric, convert to string
    idx_isnum = cellfun(@isnumeric, lab_te);
    lab_te(idx_isnum) = cellfun(@num2str, lab_te(idx_isnum),...
        'uniform', false);
    
    % keep only wanted vars from te events, rename some columns
    tab_te.Properties.VariableNames{'data'} = 'label';
    
    wantedVars = {...
        'label',...
        'task',...
        'timestamp',...
        'trialguid',...
        'logIdx',...
        };
    
    % reduce wanted vars to those that exist in the table (e.g. trialguid
    % was implemented later, so won't be in earlier datasets)
    idx_varIsPresent = ismember(wantedVars, tab_te.Properties.VariableNames);
    wantedVars = wantedVars(idx_varIsPresent);
    
    tab_te = tab_te(:, wantedVars);
    
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
    syncFound_eeg = ~isempty(idx_sync_eeg);
%     if isempty(idx_sync_eeg)
%         reason = 'No sync markers found in EEG';
%         return
%     end


% find SYNC markers in log

    % get log data from tracker
    idx_sync_te = find(strcmpi(lab_te, 'SYNC'));
    syncFound_te = ~isempty(idx_sync_te);
%     if isempty(idx_sync_te)
%         reason = 'No sync markers found in Task Engine data.';
%         return
%     end
    

    
% if no sync markers found, look for other markers that could serve

    if ~syncFound_te || ~syncFound_eeg
        
        teEcho('Searching for candidate events to use as sync markers...');
        [suc, oc, idx_sync_te, idx_sync_eeg] =...
            findSyncMarkerCandidates(lab_te, lab_eeg);
        
        if ~suc
            val = false;
            reason = sprintf('No sync markers found (%s)', oc);
            return
        end
    
    end

% find SYNC marker pairs to test

    numSync_eeg = length(idx_sync_eeg);
    teEcho('Found %d EEG sync markers.\n', numSync_eeg);
    numSync_te = length(idx_sync_te);
    teEcho('Found %d Task Engine sync markers.\n', numSync_te);   
    
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
    
    % for each pair, make a copy of the EEG table. These will be anotated
    % as pairs are tested, the winner will be retained and the others
    % discarded. Do the same for the te table, so we can store EEG indices
    % in these (allowing two-way translation between event tables)
    tab_eeg_tmp = repmat({tab_eeg}, numPairs, 1);
    tab_te_tmp = repmat({tab_te}, numPairs, 1);
    
    % we will calculate correlation between eeg and te timestamps in this
    % var
    r = zeros(numPairs, 1);
    err_mu = nan(numPairs, 1);
    
    parfor p = 1:numPairs
        
        % get the indices of the currently-being-tested sync events
        idx_curSync_eeg = pairs(p, 2);
        idx_curSync_te = pairs(p, 1);
        
        % calculate sync-event delta for each event (for both EEG and te)
        eeg_delta = tab_eeg.timestamp - tab_eeg.timestamp(idx_curSync_eeg);
        te_delta = tab_te.timestamp - tab_te.timestamp(idx_curSync_te);
        
        % loop through EEG events. For each EEG event, find any matching te
        % events that are within tolerance. Filter for events with matching
        % labels. To narrow down multiple matches take a) the event with
        % the closet sync delta, and b) the first te event BEFORE the
        % current EEG event (on that basis that te should precede EEG)
        for e = 1:numEEG
            
            % find te events with sync-event deltas within tolerance
            deltaMatch = abs(te_delta - eeg_delta(e));
            idx_te_tol = deltaMatch < tolerance;
            
            % find te events within tolerance that also match the eeg event
            % label. Here we also filter the vector of delta matches to
            % remove the entries that correspond to non-matchd labels. We
            % do this by setting those values to NaN
            idx_labelMatch = strcmpi(lab_te, lab_eeg{e});
            idx_te_tol = idx_te_tol & idx_labelMatch;
            deltaMatch(~idx_labelMatch) = nan;
            
            % if multiple events match, remove all but the closest matched
            % delta
            if sum(idx_te_tol) > 1
                
                % find minimum delta match, which is the closest match out
                % of all candidates
                idx_te_tol = idx_te_tol & deltaMatch == min(deltaMatch);
                
                % if there are still multiple matches, this is likely
                % because two events exist equidistant on either side of
                % the EEG event. In this case, take the event that PRECEDES
                % the EEG event, on the assumption that EEG events are
                % delayed relative to te events:
                %
                %   [te] <-delta-> [eeg] <-delta-> [te]
                %     | take this one
                
                if sum(idx_te_tol) > 1
                    
                    % find event that precedes the EEG event. This is by
                    % definition the first event in the logical vector
                    % idx_te_tol. Find that event's index in the vector,
                    % then blank the vector, then rewrite just that one
                    % event
                    idx_firstEvent = find(idx_te_tol, 1, 'first');
                    idx_te_tol = false(size(idx_te_tol));
                    idx_te_tol(idx_firstEvent) = true;
                    
                end

            end

            % final check to ensure that only one event was found. The
            % code above should ensure that we don't ever get to this
            % point, so if we do it's an error
            if sum(idx_te_tol) > 1
                error('More than one TE event was matched. This should not happen - debug.')
            end            
                
            % store outcome in temp EEG table for this pair
            matched = logical(sum(idx_te_tol));
            tab_eeg_tmp{p}.te_matched(e) = matched;
            
            if matched
                
                % get index of found event
                idx_found = find(idx_te_tol);

                % store results
                tab_eeg_tmp{p}.te_event_idx(e) = idx_found;
                tab_eeg_tmp{p}.te_err(e) = deltaMatch(idx_found);
                tab_eeg_tmp{p}.te_timestamp(e) = tab_te.timestamp(idx_found);
                
                tab_te_tmp{p}.eeg_matched(idx_found) = matched;
                tab_te_tmp{p}.eeg_event_idx(idx_found) = e;
                tab_te_tmp{p}.eeg_err(idx_found) = deltaMatch(idx_found);
                tab_te_tmp{p}.eeg_timestamp(idx_found) = tab_eeg.timestamp(e);
                tab_te_tmp{p}.eeg_sample(idx_found) = tab_eeg.sample(e);
            
            else
                
                tab_eeg_tmp{p}.te_reason{e} = 'no TE events within tolerance';
                
            end
            
        end
        
        % calculate correlation between eeg and te timestamps for
        % matched events
        idx_matched = tab_eeg_tmp{p}.te_matched;
        if any(idx_matched)

            r(p) = corr(tab_eeg_tmp{p}.te_timestamp(idx_matched),...
                tab_eeg_tmp{p}.timestamp(idx_matched));
            err_mu(p) = mean(tab_eeg_tmp{p}.te_err);

        end        

    end
    
    % assess pair match by correlating eeg and te timestamps for matched
    % events. If more than one match has identical rho then filter further
    % by minimising error
    idx_best = r == max(r);
    if sum(idx_best) > 1
        % minimum candidate error is the lowest error amongst the best rho
        % values. It is what we use to filter rho values by lowest error
        minCandErr = min(err_mu(idx_best));
        idx_best = idx_best & err_mu == minCandErr;
    end
    
    sync.eeg_table = tab_eeg_tmp{idx_best};
    sync.te_table = tab_te_tmp{idx_best};
    sync.r = r(idx_best);
    sync.num_events_matched = sum(sync.eeg_table.te_matched);
    sync.eeg_prop_events_matched = prop(sync.eeg_table.te_matched);
    sync.te_prop_events_matched = prop(sync.te_table.eeg_matched);
    sync.err_mean = mean(sync.eeg_table.te_err(sync.eeg_table.te_matched));
    sync.err_sd = std(sync.eeg_table.te_err(sync.eeg_table.te_matched));
    
    suc = true;
    oc = '';

% % calculate sync offsets for each pair. Offsets are eeg - te, so we arrive
% % at a value that, when ADDED to the te markers, gives the eeg marker
% % value
% 
%     % look up timestamps 
%     pairs_t(:, 1) = time_te(pairs(:, 1));
%     pairs_t(:, 2) = time_eeg(pairs(:, 2));
%     
%     % calculate offsets
%     pairs_off = pairs_t(:, 2) - pairs_t(:, 1);
%     
% % test each sync marker pair
% 
%     val_match = false(numEEG, numPairs);
%     reason_match = repmat({'unknown error'}, numEEG, numPairs);
%     t_err = nan(numEEG, numPairs);
%     t_te = nan(numEEG, numPairs);
%     matched_event_te = cell(numEEG, numPairs);
%     idx_te = nan(numEEG, numPairs);
% 
%     tab = cell(1, numPairs);
%     sync_r2 = nan(1, numPairs);
%     mdl = cell(1, numPairs);
%     
%     for p = 1:numPairs
%         
%         s1 = 1;
%         for e = 1:numEEG
%             
%             reason_match{e} = 'unknown error';
%                         
%             % find eeg timestamps, add tolerance window, and shift by
%             % offset to convert to te time
% %             t1 = time_eeg(e) - tolerance - pairs_off(p);
% %             t2 = time_eeg(e) + tolerance - pairs_off(p);
%             t_cent = time_eeg(e);
%             
%             % check t1 is within bounds of te timestamps
%             if t_cent > time_te(end)
%                 reason_match{e} = 'EEG timestamp beyond bounds of Task Engine events';
%                 continue
%             end
%             
% %             % find te timestamp that is closest to the centre of the search
% %             % window
% %             t_cent = t1 + ((t2 - t1) / 2);
%             
%             % find distance of each te sample to the centre of the EEG
%             % search window
%             dis_te = abs(time_te(s1:end) - t_cent);
%             
%             % find the closest sample (relative to start of all te markers)
%             idx_cand = find(dis_te <= tolerance);
%             
% %             % convert timestamps to samples
% %             s1 = s1 - 1 + find(time_te(s1:end) >= t1, 1, 'first');
% %             s2 = s1 - 1 + find(time_te(s1:end) >= t2, 1, 'first') - 1;
% %             
% %             % if s2 not found, set it to s1
% %             if isempty(s2), s2 = s1; end
%             
%             % get event and timestamp for candidate te events (within
%             % tolerance window)
%             event_te = tab_te.data(idx_cand);
%             eventTime_te = tab_te.timestamp(idx_cand);
% %             event_te = lg.data(s1:s2);
% %             eventTime_te = lg.timestamp(s1:s2);
%             
%             if isempty(event_te)
%                 reason_match{e} = 'no te events within tolerance';
%                 continue
%             end
%             
%             % do any te events match the EEG event?
%             match = cellfun(@(x) isequal(lab_eeg{e}, x), event_te);
%             
%             % filter for matched events
%             event_te = event_te(match);
%             eventTime_te = eventTime_te(match);
%             
%             % calculate timing error between this EEG event and all
%             % candidate te events
%             terr = time_eeg(e) - eventTime_te - pairs_off(p);
%             
%             % determine number of matches
%             if ~any(match) 
%                 
%                 % no match
%                 reason_match{e} = 'no te event labels matched';
%                 continue
%                 
%             elseif sum(match) ~= 1
%                 
%                 % multiple matches, select by timing error
%                 idx_closest = abs(terr) == min(abs(terr));
%                 terr = terr(idx_closest);
%                 event_te = event_te(idx_closest);
%                 eventTime_te = eventTime_te(idx_closest);
%                 idx_te(e, p) = idx_closest;
%                 
%             end
%             
%             reason_match{e} = '';
%             val_match(e) = true;
%             t_err(e, p) = terr';
%             t_te(e, p) = eventTime_te;
%             matched_event_te(e) = event_te;
%             
%         end
%         
%         tab{p} = table;
%         tab{p}.eeg_code = codes_eeg;
%         tab{p}.eeg_label = lab_eeg;
%         tab{p}.eeg_idx = (1:numEEG)';
%         tab{p}.event_matched = val_match(:, p);
%         tab{p}.failure_reason = reason_match(:, p);
%         tab{p}.matched_te_event = matched_event_te(:, p);
%         tab{p}.eeg_time = time_eeg;
%         tab{p}.te_time = t_te(:, p);
%         tab{p}.timing_error = t_err(:, p);
%         tab{p}.event_time_matched = abs(t_err(:, p)) < tolerance;
%         
%         % linear regression to test fit of sync
%         x = t_te(val_match(:, p), p);
%         y = time_eeg(val_match(:, p));
%         if ~isempty(x) && ~isempty(y)
%             mdl{p} = fitlm(x, y);
%             sync_r2(p) = mdl{p}.Rsquared.Ordinary;
%         else
%             mdl{p} = [];
%             sync_r2(p) = -inf;
%         end
%        
%     end
%     
% % assess fit of each sync pair
% 
%     best_idx = sync_r2 == max(sync_r2);
%     best_pair = pairs(best_idx, :);
%     sync.offset = pairs_off(best_idx);
%     sync.best_r2 = sync_r2(best_idx);
%     sync.event_te_idx = best_pair(1);
%     sync.event_eeg_idx = best_pair(2);
%     sync.match_table = tab{best_idx};
%     if ~isempty(mdl{p})
%         sync.intercept = mdl{best_idx}.Coefficients{1, 1};
%         sync.B1 = mdl{best_idx}.Coefficients{2, 1};
%     end
%     
    val = true;
    reason = {''};

end

function [suc, oc, idx_te, idx_eeg] = findSyncMarkerCandidates(lab_te, lab_eeg)
% when no specific SYNC markers are present in either the te or EEG events,
% we attempt to find other events that could be used as sync points. Since
% we will have to test each combination of paired sync events, we want as
% few as possible. This function finds events that are a) in both the te
% data and the EEG data, and b) have the minimum number of occurrences.

    suc = false;
    oc = 'unknown error';
    
    % find EEG events that are present in te
    idx_presentInTe = ismember(lab_eeg, lab_te);
    idx_presentInEEG = ismember(lab_te, lab_eeg);
    if ~any(idx_presentInTe)
        oc = 'no EEG events present in te data';
        return
    end
    
    % count each unique event and find the one with fewest occurrences
    tbl8 = tabulate([lab_eeg(idx_presentInTe); lab_te(idx_presentInEEG)]);
    cnt = cell2mat(tbl8(:, 2));
    idx_fewest = find(cnt == min(cnt), 1);
    lab_fewest = tbl8{idx_fewest, 1};
    
    % get indices of each occurrence of this event in both the EEG and te
    % data
    idx_eeg = find(strcmpi(lab_eeg, lab_fewest));
    idx_te = find(strcmpi(lab_te, lab_fewest));
    
    suc = true;
    oc = '';
    
end
    
    

