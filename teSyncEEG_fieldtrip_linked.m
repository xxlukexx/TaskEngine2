function [sync, tracker] = teSyncEEG_fieldtrip_linked(tracker, data_ft, varargin)

    sync = struct;
    sync.success = false;
    sync.outcome = 'unknown error';
    
% parse input args

    isPosNumScalar = @(x) isnumeric(x) && isscalar(x) && x > 0;
    parser      =   inputParser;
    addParameter(   parser, 'tolerance',            0.060,      isPosNumScalar  )
    parse(          parser, varargin{:});
    tolerance   =   parser.Results.tolerance;

% setup
    
    % if ft_events not passed, attempt to extract form ft_data. tep will
    % create this field in the standard ft data structure so it should be
    % there 
    if isfield(data_ft, 'events')
        ft_events = data_ft.events;
    else
        sync.outcome = 'No ft_events were passed, and failed to find .events field in ft_data.';
        return
    end
    
    % check events format
    if ~isstruct(ft_events) || ~isfield(ft_events, 'value') ||...
            ~all(arrayfun(@(x) isnumeric(x.value), ft_events))
        sync.outcome = '''ft_events'' must be a Fieldtrip events struct';
        return
    end
    
    % define ignored events
    eeg_lab_ignored = {...
        'ATTENTION_GETTER_AUDITORY',...
        };
    eeg_code_ignored = [...
        255,...
        ];
    
    
    
    
    
    
    
% extract te end of the linked events

    te = teLogFilter(tracker.Log, 'source', 'teEventRelay_Enobio_linked');
    
    ft = struct2table(ft_events);
    
    tab_ev = outerjoin(te, ft, 'LeftKeys', 'linked_event_idx',...
        'RightKeys', 'value', 'Type', 'left');
    x = tab_ev.timestamp;
    y = tab_ev.sample;
    idx_missing = isnan(x) | isnan(y);
    x(idx_missing) = [];
    y(idx_missing) = [];
    [f, gof] = fit(x, y, 'poly1');
    
    
% extract EEG event data

    [codes_eeg, samps_eeg, lab_eeg, time_eeg, numEEG] =...
        extractEEGEvents(tracker, data_ft, ft_events);
    
% extract te event data

    [lg, lab_te, time_te, numTE] = extractTaskEngineEvents(tracker);

% find sync markers in EEG

    [suc, oc, fail_code, pairs, numPairs, pairs_off] =...
        findAndPairSyncMarkers(syncMarker, tracker, codes_eeg, time_eeg, lab_te, time_te);
    
% find best fitting pairs of sync markers

    [best_idx, tab, mdl, sync_r2, idx_log] = testAllMarkerPairs(...
        numPairs, pairs_off, numEEG, time_eeg, samps_eeg, codes_eeg, lab_eeg,...
        eeg_code_ignored, eeg_lab_ignored, tracker, time_te, lg, tolerance);
    
% if <2 events were matched, look for alternative sync markers

    numMatched = cellfun(@(x) sum(x.event_matched), tab);
    if all(numMatched <= 1)
        
        [suc, ~, syncMarker] = searchForPossibleSyncMarker(lab_eeg, lab_te);
        if ~suc
            sync.oc = 'SYNC markers return <2 matched events and no other usable markers could be found';
            return
        end
        
        % attempt to pair again
        [suc, oc, fail_code, pairs, numPairs, pairs_off] = findAndPairSyncMarkers(...
            syncMarker, tracker, codes_eeg, time_eeg, lab_te, time_te);
    
        [best_idx, tab, mdl, sync_r2, idx_log] = testAllMarkerPairs(...
            numPairs, pairs_off, numEEG, time_eeg, samps_eeg, codes_eeg, lab_eeg,...
            eeg_code_ignored, eeg_lab_ignored, time_te, lg, tolerance);
        
        % evaluate
        numMatched_new = cellfun(@(x) sum(x.event_matched), tab);
        if all(numMatched_new <= 1)
            sync.outcome = 'SYNC markers return <2 matched events and no other usable markers could be found';
            return
        end
        
    end
    

%     % if no/insufficient sync markers are found, try to find markers that
%     % are present in EEG and TE data and use these instead. To reduce the
%     % number of pairs to check for sync, try to find the least frequently
%     % occuring event in both data streams
%     if ~suc
%         syncMarker = searchForPossibleSyncMarkers(lab_eeg, lab_te);
%         
%         
%     end
    
    
% test each sync marker pair

%     val_match = false(numEEG, numPairs);
%     reason_match = repmat({'unknown error'}, numEEG, numPairs);
%     t_err = nan(numEEG, numPairs);
%     t_te = nan(numEEG, numPairs);
%     matched_event_te = cell(numEEG, numPairs);


    
% store match table

    sync.match_table = tab{best_idx};

% remove events with timing error outliers. The logic here is that due to
% clock drift, samples may end up - say - 50ms out of sync, but they should
% only differ from their neighbours by a fraction of a ms, since the drift
% is gradual. Therefore an event with a sudden jump in timing error
% relative to it's neighbours is likely to be either 1) poor equipment
% timing, or 2) mismatch -- either way we don't want to analyse them. First
% convert to zscores (to normalise for varying drift/offset) and then find
% events with a z_timing_error delta > 1. 

    ol_t_err = sync.match_table.timing_error;
    idx_val = sync.match_table.event_matched;
    ol_t_err(idx_val) = detrend(ol_t_err(idx_val));
    ol_z = zeros(size(ol_t_err));
    ol_z(idx_val) = zscore(ol_t_err(idx_val));
    idx_crit = ol_z > 3;
    sync.match_table.event_matched(idx_crit) = false;
    sync.match_table.failure_reason(idx_crit) = repmat({'timing error too high'}, sum(idx_crit), 1);
    
% summarise

    best_pair = pairs(best_idx, :);
    sync.offset = pairs_off(best_idx);
    sync.best_r2 = sync_r2(best_idx);
    sync.event_te_idx = best_pair(1);
    sync.event_eeg_idx = best_pair(2);
    if ~isempty(mdl{best_idx})
        sync.intercept = mdl{best_idx}.Coefficients{1, 1};
        sync.b1 = mdl{best_idx}.Coefficients{2, 1};
    else
        sync.intercept = nan;
        sync.b1 = nan;
    end
    sync.num_matched = sum(sync.match_table.event_matched);
    sync.num_unmatched = sum(~sync.match_table.event_matched);
    sync.prop_matched = prop(sync.match_table.event_matched);
    t_err_val = sync.match_table.timing_error(sync.match_table.event_matched);
    sync.error_min = min(abs(t_err_val));
    sync.error_max = max(abs(t_err_val));
    sync.error_mean_abs = mean(abs(t_err_val));
    sync.match_table.sync_idx = [1:size(sync.match_table, 1)]';
    
% write sync GUIDs back to log

    idx_log = idx_log(:, best_idx);
    for e = 1:length(idx_log)
        if ~isnan(idx_log(e))
            idx_tracker = idx_log(e);
            tracker.Log{idx_tracker}.sync_eeg_sample = samps_eeg(e);
            tracker.Log{idx_tracker}.sync_eeg_time = time_eeg(e);
            tracker.Log{idx_tracker}.sync_eeg_code = codes_eeg(e);
        end
    end
    
% tidy up
    
%     % if numeric events were ignored at any point, warn of this
%     if flag_warnAboutIgnoredNumericEvents
%         warning('Some numeric events were found in the Task Engine data. Numeric events are not currently supported for syncing. These events were ignored.')
%     end
    
    sync.success = true;
    sync.outcome = '';

end

function [codes_eeg, samps_eeg, lab_eeg, time_eeg, numEEG] =...
    extractEEGEvents(tracker, data_ft, ft_events)

    % get codes and sample indices from fieldtrip data
    codes_eeg = [ft_events.value]';
    samps_eeg = [ft_events.sample]';
    numEEG = length(codes_eeg);
    teEcho('Found %d EEG events.\n', numEEG);

    % look for .abstime field in ft data (created by tep). Otherwise
    % create from sample numbers and sampling rate
    if isfield(data_ft, 'abstime')
        time_eeg = data_ft.abstime(samps_eeg);
    else
        time_eeg = samps_eeg / data_ft.fsample;
        warning('No .abstime in ft_data, creating sham values from sample indices/sampling rate.')
    end

    % convert eeg codes to labels
    lab_eeg = teCodes2RegisteredEvents(tracker.RegisteredEvents,...
        codes_eeg, 'eeg');
    
    % remove any EEG codes that don't have corresponding registered events
    idx_noRegEvent = cellfun(@isempty, lab_eeg);
    if any(idx_noRegEvent)
        codes_eeg(idx_noRegEvent) = [];
        samps_eeg(idx_noRegEvent) = [];
        lab_eeg(idx_noRegEvent) = [];
        time_eeg(idx_noRegEvent) = [];
        numEEG = length(codes_eeg);
        warning('%d EEG event(s) did not have corresponding Task Engine registered events and will be ignored.',...
            sum(idx_noRegEvent));
    end
    
end

function [lg, lab_te, time_te, numTE] = extractTaskEngineEvents(tracker)

    lg = teLogFilter(tracker.Log, 'source', 'teEventRelay_Log');
    lg = sortrows(lg, 'timestamp');
    lab_te = lg.data;
    time_te = lg.timestamp;
    numTE = length(lab_te);
    
    % check that the log has a trialguid column (earliest versions of te2
    % didn't have this) and if not, add blanks
    if ~ismember('trialguid', lg.Properties.VariableNames)
        lg.trialguid = repmat({'na'}, size(lg, 1), 1);
    end
    
    teEcho('Found %d Task Engine events.\n', numTE);    
    
end

function [suc, oc, syncMarker] = searchForPossibleSyncMarker(lab_eeg, lab_te)

    syncMarker = [];
    suc = false;
    oc = 'unknown error';
    
    [u, i_eeg, i_te] = intersect(lab_eeg, lab_te);
    if isempty(u)
        oc = 'no common eeg/task engine labels';
        return
    end
    
    % remove actual SYNC markers
    idx_isSyncMarker = strcmpi(u, 'SYNC');
    u(idx_isSyncMarker) = [];
    
    freq_eeg = cellfun(@(x) sum(strcmpi(lab_eeg, x)), u);
    freq_te = cellfun(@(x) sum(strcmpi(lab_te, x)), u);
    freq_tot = freq_eeg + freq_te;
    idx_least = find(freq_tot == min(freq_tot), 1, 'first');
    syncMarker = u{idx_least};
    
    fprintf('Found usable sync marker (%s) with %d EEG events and %d Task Engine events.\n',...
        syncMarker, freq_eeg(idx_least), freq_te(idx_least));
    
    suc = true;
    oc = '';

end

function [suc, oc, fail_code, pairs, numPairs, pairs_off] =...
    findAndPairSyncMarkers(syncMarker, tracker, codes_eeg, time_eeg, lab_te, time_te)

    suc = false;
    
    % look up reg event for sync
    ev_sync = tracker.RegisteredEvents(syncMarker);
    if isempty(ev_sync)
        oc =...
            sprintf('No sync marker (%s) in registered events', syncMarker);
        fail_code = 'nosync_re';
        return
    end
    
    % find in markers
    idx_sync_eeg = find(codes_eeg == ev_sync.eeg);
    if isempty(idx_sync_eeg)
        oc = sprintf('No sync markers (%s) found in EEG', syncMarker);
        fail_code = 'nosync_eeg';
        return
    end
    
    numSync_eeg = length(idx_sync_eeg);
    teEcho('Found %d EEG sync markers (%s).\n', numSync_eeg, syncMarker);
    
% find SYNC markers in log

    % get log data from tracker
    idx_sync_te = find(strcmpi(lab_te, syncMarker));
    if isempty(idx_sync_te)
        oc = sprintf('No sync markers (%s) found in Task Engine data.',...
            syncMarker);
        fail_code = 'nosync_te';
        return
    end
    
    numSync_te = length(idx_sync_te);
    teEcho('Found %d Task Engine sync markers.\n', numSync_te); 

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
    
    suc = true;
    oc = '';
    fail_code = '';

end

function [tab, numMatched, meanErr, mdl, sync_r2, idx_log] =...
    testOneMarkerPair(pairs_off, numEEG, time_eeg, samps_eeg, codes_eeg,...
    lab_eeg, eeg_code_ignored, eeg_lab_ignored, time_te, tracker, lg, tolerance)

    reason_match = cell(numEEG, 1);
    val_match = false(numEEG, 1);
    t_err = nan(numEEG, 1);
    t_te = nan(numEEG, 1);
    matched_event_te = cell(numEEG, 1);
    guid_eeg = cell(numEEG, 1);
    idx_log = nan(numEEG, 1);
    s1 = 1;
    for e = 1:numEEG

        reason_match{e} = 'unknown error';

        % check if this EEG event is to be ignored
        if ismember(codes_eeg(e), eeg_code_ignored)
            reason_match{e} = sprintf('ignored eeg code: %d', codes_eeg(e));
            continue
        elseif ismember(lab_eeg{e}, eeg_lab_ignored)
            reason_match{e} = sprintf('ignored event: %s', lab_eeg{e});
            continue
        end

        % find eeg timestamps, add tolerance window, and shift by
        % offset to convert to te time
        t1 = time_eeg(e) - tolerance - pairs_off;
        t2 = time_eeg(e) + tolerance - pairs_off;

        % check t1 is within bounds of te timestamps
        if t1 > time_te(end)
            reason_match{e} = 'EEG timestamp beyond bounds of Task Engine events';
            continue
        end

        % convert timestamps to log item indices. Here we convert
        % timestamps to indices within the log, in the next step we
        % will extract all log items (te events) within the window
        % defined by s1:s2
        s1 = s1 - 1 + find(time_te(s1:end) >= t1, 1, 'first');
        s2 = s1 - 1 + find(time_te(s1:end) >= t2, 1, 'first');

            % if s2 not found, set it to s1
            if isempty(s2), s2 = s1; end

        % get event and timestamp for candidate te events (within
        % tolerance window)
        event_te = lg.data(s1:s2);
        eventTime_te = lg.timestamp(s1:s2);
        trialGUID_te = lg.trialguid(s1:s2);
        matchedLogIdx_te = lg.logIdx(s1:s2);

        % currently we only operate on text labels, although this may
        % change in future. For now, numeric event labels in the te
        % data will cause problems for this code, so detect and fail on
        % them
        idx_numEvent = cellfun(@isnumeric, event_te);
        if any(idx_numEvent)
            flag_warnAboutIgnoredNumericEvents = true;
            event_te(idx_numEvent) = [];
            eventTime_te(idx_numEvent) = [];
            trialGUID_te(idx_numEvent) = [];
            matchedLogIdx_te(idx_numEvent) = [];
            if isempty(event_te)
                reason_match{e} = 'only numeric te events within tolerance';
                continue
            end
        end

        % if no events were returned, this means there were no log
        % items with a timestamp within tolerance of the EEG events. If
        % so, the current EEG event cannot be matched and we move on to
        % the next event 
        if isempty(event_te)
            reason_match{e} = 'no te events within tolerance';
            continue
        end

        % check if any TE events are to be ignored
        idx_ignore = ismember(event_te, eeg_lab_ignored);
        if any(idx_ignore)
            event_te(idx_ignore) = [];
            eventTime_te(idx_ignore) = [];
            trialGUID_te(idx_ignore) = [];
            matchedLogIdx_te(idx_ignore) = [];
        end

        % now we have n log items within tolerance of the current EEG
        % event; we need to know which is the correct one to match

            % the EEG event label and the te log item event label must
            % match
            match = cellfun(@(x) isequal(lab_eeg{e}, x), event_te);

            % calculate timing error between this EEG event and all
            % candidate te events. In the event of any ties (e.g.
            % muliple te event labels match the EEG event label, all
            % within tolerance) this will decide things. 
            terr = time_eeg(e) - eventTime_te - pairs_off;

        % inspect the number of matches, deal with none and multiple
        if ~any(match) 

            % no matches -- cannot match this EEG event so move on
            reason_match{e} = 'no te event labels matched';
            continue

        elseif sum(match) ~= 1

            % multiple te events matched the current EEG event within
            % the tolerance window, and had matching labels. Take the
            % one with the lowest timing error. 
            idx_lowestErr = match & abs(terr) == min(abs(terr(match)));

            % if multiple events have identical timing errors, take the
            % first one
            if sum(idx_lowestErr) > 1
                idx_firstLowestError = find(idx_lowestErr, 1, 'first');
                idx_lowestErr = false(size(idx_lowestErr));
                idx_lowestErr(idx_firstLowestError) = true;
            end

            match = match & idx_lowestErr;
            reason_match{e} = ''; 

        else

            reason_match{e} = '';                                        % blank reason for a successful match

        end

        % plot
% %             if e >= 1410 && e<= 1471
%             path_out = sprintf('%s%s%s', '/Users/luke/Desktop/bttmp/syncplots', filesep, tracker.GUID, filesep, num2str(pairs_off));
%             teSyncEEG_fieldtrip_plotMatch(e, s1, matchedLogIdx_te(match), lg, time_eeg, codes_eeg, lab_eeg, pairs_off, path_out, reason_match{e});
%             fprintf('Plotted %d of %d...\n', e, numEEG);
%             end

        % remove non-matching data from the working variables
        event_te = event_te(match);
        eventTime_te = eventTime_te(match);
        terr = terr(match);
        trialGUID_te = trialGUID_te(match);
        matchedLogIdx_te = matchedLogIdx_te(match);

        % store the results 
        val_match(e) = true;                                         % flag indicates successful match
        t_err(e) = terr';                                            % timing error btw events
        t_te(e) = eventTime_te;                                      % te timestamp
        matched_event_te(e) = event_te;                              % te event label that was matched
        if ~isequal(trialGUID_te, {[]})
            guid_eeg{e} = trialGUID_te;                              % trial GUID (if there is one) from te
        end

        % back-lookup the log index of the te event. We will use this
        % later to edit the te log, by appending EEG sample info for
        % later segementation
        idx_log(e) = matchedLogIdx_te;
           
    end
    
    tab = table;
    tab.eeg_code = codes_eeg;
    tab.eeg_label = lab_eeg;
    tab.event_matched = val_match;
    tab.failure_reason = reason_match;
    tab.matched_te_event = matched_event_te;
    tab.eeg_time = time_eeg;
    tab.eeg_sample = samps_eeg;
    tab.te_time = t_te;
    tab.timing_error = t_err;
    tab.event_time_matched = abs(t_err) < tolerance;
    tab.trialguid = cell(size(tab, 1), 1);

    % where trial GUIDs are available, store these 
    idx_hasGUID = ~cellfun(@isempty, guid_eeg);
    tab.trialguid(idx_hasGUID) = guid_eeg(idx_hasGUID);

    % where a te log index is available, store this
    tab.te_log_idx = idx_log;

    % linear regression to test fit of sync
    x = t_te(val_match);
    y = time_eeg(val_match);
    if length(x) > 1 && length(y) > 1
        mdl = fitlm(x, y);
        sync_r2 = mdl.Rsquared.Ordinary;
    else
        mdl = [];
        sync_r2 = -inf;
    end

    % record number matched events
    numMatched = sum(tab.event_matched);
    meanErr = mean(tab.timing_error(tab.event_matched));
        
end

function [best_idx, tab, mdl, sync_r2, idx_log] = testAllMarkerPairs(...
    numPairs, pairs_off, numEEG, time_eeg, samps_eeg, codes_eeg, lab_eeg,...
    eeg_code_ignored, eeg_lab_ignored, tracker, time_te, lg, tolerance)

    tab = cell(1, numPairs);
    sync_r2 = nan(1, numPairs);
    numMatched = zeros(1, numPairs);
    meanErr = zeros(1, numPairs);
    mdl = cell(1, numPairs);
    idx_log = nan(numEEG, numPairs);
    
    % flag to warn about ignored numeric events
    flag_warnAboutIgnoredNumericEvents = false;
    
    for p = 1:numPairs
        [tab{p}, numMatched(p), meanErr(p), mdl{p}, sync_r2(p), idx_log(:, p)] =...
            testOneMarkerPair(...
                pairs_off(p), numEEG, time_eeg, samps_eeg,...
                codes_eeg, lab_eeg, eeg_code_ignored, eeg_lab_ignored,...
                time_te, tracker, lg, tolerance);
    end
    
% assess fit of each sync pair

    % first use number matched
    best_numMatched = numMatched == max(numMatched);
    
    % if more than one pair matches equally well, use best fit
    if sum(best_numMatched) > 1
        
        best_r2 = best_numMatched & sync_r2 == max(sync_r2(best_numMatched));
        
        % if more than one pair still matches, take lowest timing error
        if sum(best_r2) > 1
            meanErr(~best_r2) = nan;
            best_err = abs(meanErr) == min(abs(meanErr));
            best_idx = best_err;
        else
            best_idx = best_r2;
        end
        
    else
        best_idx = best_numMatched;
    end

end

