function [suc, oc, res] = teCutter(data, timestamps, varargin)
% Takes a teData instance and a [n x 2] matrix of log array indices. Each
% row of this matrix represents a trial. Cuts the original log array up and
% instantiates a teTrial instance for that trial. The log array is cut
% to include all entries between timestamps.
%
% Eye tracking data is cut between timestamps and returned in the
% .EyeTracking field of each teTrial. Additionally an etGazeData instance
% is added as a .Gaze field to each teTrial. 
%
% Fieldtrip data can be cut in two ways: 1) by passing an EEG sync struct
% via the "eegSync" name/value pair in the input arguments. To counter
% clock drift between task engine and the EEG amp, the nearest events to
% each timestamp pair are found, and the delta between timestamp and event
% is added/subtracted when cutting the EEG data (see the cutFieldtrip
% function for more details). 2) by passing a pre-made fieldtrip trl (trial
% definition) structure to this function via the "trl" name/value pair. In
% this case, the fieldtrip data is segmented exactly using the sample
% indices in the trl structure. teSegment_labelTime is an example of a
% function that can output a trl structure (and is probably the most
% common use-case, since EEG data naturally works well with an onset label
% and duration to define trials). 
%
% Video is currently not supported.

    suc = false;
    oc = 'unknown error';
    
% parse inputs

    parser      =   inputParser;
    addParameter(   parser, 'eegsync',              [],         @isstruct       )
    addParameter(   parser, 'trl',                  []                          )    
    addParameter(   parser, 'eegbaseline',          0                           )
    addParameter(   parser, 'triallabels',          []                          )
    addParameter(   parser, 'includetrialerrors',   false,      @islogical      )
    addParameter(   parser, 'musthave',             {},         @(x) ischar(x) || islogical(x))
    parse(          parser, varargin{:});
    eegSync     =   parser.Results.eegsync;
    trl         =   parser.Results.trl;
    eegBaseline =   parser.Results.eegbaseline;
    lab_trial   =   parser.Results.triallabels;
    incTrialErr =   parser.Results.includetrialerrors;
    mustHave    =   parser.Results.musthave;
    
    if isempty(timestamps)
        error('Timestamps cannot be empty.')
    end
    
    if ~iscell(mustHave)
        mustHave = {mustHave};
    end
    if ~all(ismember(mustHave, {'log', 'fieldtrip', 'eyetracking'}))
        error('The ''mustHave'' parameter must be either char or cell array, and must be either ''log'', ''eyetracking'', or ''fieldtrip''')
    end
    
    if ~isequal(size(timestamps, 1), length(lab_trial))
        error('The height of the timestamps matrix must be the same length as the trial labels.')
    end
    
% set up output vars

    numTrials           = size(timestamps, 1);
    trials              = cell(numTrials, 1);
    suc_log             = false(numTrials, 1);
    oc_log              = cell(numTrials, 1);
    hasET               = false(numTrials, 1);
    hasFieldtrip        = false(numTrials, 1);
    suc_et              = false(numTrials, 1);
    oc_et               = cell(numTrials, 1);
    lg                  = data.Log;
    
% determine presence of external data

    et = data.ExternalData('eyetracking');
    hasET = repmat(~isempty(et) && et.Valid, numTrials, 1);
    ft = data.ExternalData('fieldtrip');
    hasFieldtrip = repmat(~isempty(ft), numTrials, 1);
    
% sort timestamps
    
    [timestamps, so] = sort(timestamps);
    if ~isempty(lab_trial)
        lab_trial = lab_trial(so);
    end
    
% find and store dynamic prop values

    dynP = data.DynamicProps;
    dynV = data.DynamicValues;
    
% as of Oct 22, data from the PIP study has an erroneous timestamp on the
% sync marker. Find any log stamps with a timestamp delta  >50SDs and
% remove them for now

    idx_errTimestamp = [false; zscore(diff(lg.LogTable.timestamp)) > 50];
    idx_errTimestamp_logArray = lg.LogTable.logIdx(idx_errTimestamp);
    lg.LogArray(idx_errTimestamp_logArray) = [];    
    lt = lg.LogTable;
    
% cut each trial

    for t = 1:numTrials
        
        % cut log
        [trials{t}, suc_log(t), oc_log{t}] =...
            cutLog(lg, timestamps(t, 1), timestamps(t, 2), incTrialErr);
        if ~suc_log(t)
            continue
        end
        
        % cut eye tracking
        if hasET(t)
            [trials{t}, suc_et(t), oc_et{t}] =...
                cutEyeTracking(et, data.Log.Events, trials{t},...
                timestamps(t, 1), timestamps(t, 2));
        end

        % cut video
        
        % store trial number and label
        trials{t}.TrialNo = t;
        if ~isempty(lab_trial)
            trials{t}.OnsetLabel = lab_trial{t};
        end
        
        % transfer dynamic props (e.g. ID) from session to trial
        for p = 1:length(dynP)
            trials{t}.(dynP{p}) = dynV{p};
        end

    end
    
    % fieldtrip EEG data is cut for all trials at once, so happens outside
    % of the loop
    
        if hasFieldtrip(t(1))
            
            % get trial GUIDs from teTrials
            trialGUIDs =...
                cellfun(@(x) x.TrialGUID, trials, 'UniformOutput', false);
            
            % cut
            [data_ft_seg, suc_ft, oc_ft] = cutFieldtrip(ft,...
                timestamps(:, 1), timestamps(:, 2), eegSync, trl,...
                eegBaseline, trialGUIDs);
            
%             % repeat suc_ft and oc_ft for all trials
%             suc_ft(2:numTrials, 1) = repmat(suc_ft(1), numTrials - 1, 1);
%             oc_ft(2:numTrials, 1) = repmat(oc_ft(1), numTrials - 1, 1);
            
        else
            
            data_ft_seg = [];
            suc_ft = false(numTrials, 1);
            oc_ft = repmat({'no fieldtrip data'}, numTrials, 1);
            
        end
        
% sort trials by onset timestamp

    onset_tr = cellfun(@(x) x.Onset, trials);
    [~, so] = sort(onset_tr);
    trials = trials(so);
    
% build report
    
    report = table;
    report.segment(:, 1) = (1:numTrials)';
    report.onset = timestamps(:, 1);
    report.offset = timestamps(:, 2);
    report.log_success = suc_log;
    report.log_outcome = oc_log;
    report.et_success = suc_et;
    report.et_outcome = oc_et;
    report.ft_success = suc_ft;
    report.ft_outcome = oc_ft;
    
    % sort by trial onset
    report = report(so, :);
    
% store in results struct

    res.trials = trials;
    res.report = report;
    if ~isempty(data_ft_seg), res.ft_seg = data_ft_seg; end
    
% determine overall success

    % if the 'musthave' parameter is not used, then default is to consider
    % anything in which any data was found -- of any type (even log), and
    % of any quantity greater than zero.
    if isempty(mustHave)
        suc = any(suc_et) || any(suc_log) || any(suc_ft);
    else
        suc = true;
        if ismember('log', mustHave)
            suc = suc && any(suc_log);
            oc = 'Missing log data (and maybe others) specified as must haves';
        end
        if ismember('eyetracking', mustHave)
            suc = suc && any(suc_et);
            oc = 'Missing eye tracking data (and maybe others) specified as must haves';
        end
        if ismember('fieldtrip', mustHave)
            suc = suc && any(suc_ft);
            oc = 'Missing fieldtrip data (and maybe others) specified as must haves';
        end
    end

end

function [trial, suc, oc] = cutLog(lg, onset, offset, incTrialErr)

    suc = false;
    oc = 'unknown error';
    trial = [];
    
    % find the first event that occurs at or after the onset timestamp
    s1 = find(lg.LogTable.timestamp >= onset, 1, 'first');
    if isempty(s1)
        suc = false;
        oc = 'onset not found in log';
        return
    end
    
    % find the first event that occurs after the offset timestamp
    s2 = find(lg.LogTable.timestamp > offset, 1);
    if isempty(s2)
        suc = false;
        oc = 'offset not found in log';
        return
    end
    
    % two possibilities here: 
    % 
    % 1) s1 and s2 are different (with s2 > s1, and
    % elements s1:s2 representing elements in between). In this case, s2 is
    % actually the first event AFTER the offset. We want to include all
    % events that are AFTER the onset but BEFORE the offset. So we do 
    % s2 - 1 to ensure we are only including events BEFORE the onset. This
    % may end up with s1 == s2, but that is OK - it's just a segment with
    % only one log element within it. 
    %
    % 2) s1 and s2 are the same. Normal logic (see above) would be to
    % subtract one from s2 on the basis that we want events BEFORE the
    % offset. But here we only have one event after the onset and that same
    % event before the offset - i.e. onset and offset are just one event.
    % So in this case we don't subtract 1. 
    if s2 > s1
        s2 = s2 - 1;
    elseif s2 < s1
        % if s2 comes before s1 throw an event - shouldn't happen but just
        % in case
        error('s2 was earlier than s1 - debug')
    end
        
    % create new log with just segmented data
    try
        la = lg.LogArray(s1:s2);
        la = teSortLog(la);
        lg_seg = teLog(la);
    catch ERR
        suc = false;
        oc = sprintf('error instantiating teLog: %s', ERR.message);
        return
    end
    
    % (optionally) detect and remove segments containing trial errors
    if ~incTrialErr
        tab_err = teLogFilter(la, 'topic', 'trial_error');
        if ~isempty(tab_err) 
            suc = false;
            oc = 'Trial error in log';
            return
        end
    end
    
    % create teTrial instance with segmented log data
    trial = teTrial(lg_seg, onset, offset);
    
    % if the log has a trialguid variable, and all log entries within this
    % segment (trial) are equal, store that trialguid in the teTrial
    % instance
    if ismember('trialguid', lg_seg.LogTable.Properties.VariableNames) &&...
            length(lg_seg.LogTable.trialguid) > 1 &&...
            isequal(lg_seg.LogTable.trialguid{:})
        trial.TrialGUID = lg_seg.LogTable.trialguid{1};
    end

    suc = true;
    oc = '';
    
end

function [trial, suc, oc] = cutEyeTracking(et, events, trial, onset, offset)

    suc = false;
    oc = 'unknown error';

    idx = et.Buffer(:, 1) >= onset & et.Buffer(:, 1) <= offset;
    if ~any(idx)
        suc = false;
        oc = 'no eye tracking data within onset/offset timestamps';
        return
    end

    % segment
    trial.EyeTracking = et.Buffer(idx, :);

    % make gaze data object
    trial.Gaze = etGazeDataBino('te2', trial.EyeTracking);
    
    % store events
    idx_ev = events.timestamp >= onset & events.timestamp <= offset;
    trial.Gaze.Events = events(idx_ev, {'timestamp', 'data'});

    suc = true;
    oc = '';

end

function [data_ft_seg, suc, oc] = cutFieldtrip(ft, onset, offset,...
    eegSync, trl, eegBaseline, trialGUIDs)

    numTrials = length(onset);
    suc = false(numTrials, 1);
    oc = repmat({'unknown error'}, numTrials, 1);
    
    % check fieldtrip is installed
    try
        ft_defaults
    catch ERR
        suc = false;
        oc = sprintf('Error initialising fieldtrip - may mean fieldtrip is not in the Matlab path:\n\n%s',...
            ERR.message);
    end
    
    % determine whether a trl structure has been passed
    useExistingTrl = ~isempty(trl);
    
    % todo - check trl structure, match to on/offsets
    
    % if an existing trl structure is not passed then we have to make one
    % using the on/offset timestamps and the eegSync structure. Check that
    % we have an eegSync
    if ~useExistingTrl && isempty(eegSync)
        suc = false;
        oc = 'Must pass either a trl structure, OR an eegSync structure (so that a trl structure can be made).';
        return
    end
    
    % check fieldtrip data paths
    path_ft = ft.Paths('fieldtrip');
    if isempty(path_ft)
        suc = false;
        oc = 'Fieldtrip data not found in external fieldtrip data .Paths collection';
        return
    elseif ~exist(path_ft, 'file')
        suc = false;
        oc = sprintf('Fieldtrip data path not found: %s', path_ft);
        return
    end
    
    % attempt to load
    try
        tmp = load(ft.Paths('fieldtrip'));
    catch ERR
        suc = false;
        oc = sprintf('Error loading fieldtrip data (%s):\n\n%s',...
            path_ft, ERR.message);
        return
    end
    
    % look for ft_data variable
    if isfield(tmp, 'ft_data')
        data_ft = tmp.ft_data;
    else
        suc = false;
        oc = sprintf('ft_data variable not found in fieldtrip data file: %s',...
            path_ft);
        return
    end
    
    if ~useExistingTrl
        
        % if a baseline has been specified, convert from time to samples
        eegBaseline_samps = round(eegBaseline * data_ft.fsample);
        
        % filter sync table for successfully matched events, and SKIPPED
        % events
        idx_matched = eegSync.match_table.event_matched;
        idx_lowErr = eegSync.match_table.timing_error < 0.050;
        idx_notSkipped = ~strcmpi(eegSync.match_table.eeg_label, 'SKIPPED');
        
        tab = eegSync.match_table(idx_matched & idx_lowErr & idx_notSkipped, :);
        
        % get timestamps (to prevent performance-sapping repeated calls to
        % Matlab table's subsref method)
        ts = tab.te_time;
        eegSamps = tab.eeg_sample;
        
        % loop through all trials
        suc = true(numTrials, 1);
        oc = repmat({''}, numTrials, 1);
        trl = nan(numTrials, 4);
        for t = 1:numTrials
        
            % find delta of all event timestamps from on/offset timestamps
            delta_on = ts - onset(t);
            delta_off = ts - offset(t);

            % find non-negative event closest to on/offsets
            minPosDelta = min(delta_on(delta_on > 0));
            maxPosDelta = max(delta_off(delta_off < 0));
            if isempty(minPosDelta) || isempty(maxPosDelta)
                suc(t) = false;
                oc{t} = 'could not match';
                continue
            end
            idx_on = find(delta_on > 0 & delta_on == minPosDelta);
            if length(idx_on) > 1
                warning('Multiple onset events matched, trial %d.', t)
                idx_on = idx_on(1);
            end
            idx_off = find(delta_off < 0 & delta_off == maxPosDelta);
            if length(idx_off) > 1
                warning('Multiple offset events matched, trial %d.', t)
                idx_off = idx_off(1);
            end

            % find sample indices for matched events
            eeg_s1 = eegSamps(idx_on);
            eeg_s2 = eegSamps(idx_off);

            % until now we have only matched on EVENTS, but we are trying to
            % segment using TIMESTAMPS. For onset and offset, calculate
            % deviation from on/offset timestamp, and correct EEG samples
            % accordingly. We refer to the fieldtrip sample rate to calculate
            % this (could use the abstime vector, but this won't be there for
            % non-enobio/egi datasets, and sample rate should be just as good)
            dev_on = round(-delta_on(idx_on) * data_ft.fsample);
            dev_off = round(-delta_off(idx_off) * data_ft.fsample);
            eeg_s1 = eeg_s1 + dev_on;
            eeg_s2 = eeg_s2 + dev_off;

            trl(t, 1) = eeg_s1;
            trl(t, 2) = eeg_s2;
            trl(t, 3) = eegBaseline_samps;
            trl(t, 4) = t;
            
            % the fourth column of the trl structure is the trial number
            % (1:numOnsets), which facilitates linking te and eeg data
            % after segmentation
            trl(t, 4) = t;
            
        end
        
    end
    
    % remove NaNs
    idx_nan = any(isnan(trl(:, 1:4)), 2);
    trl(idx_nan, :) = [];
%     suc(idx_nan) = false;
%     oc(idx_nan) = repmat({'end of EEG data'}, sum(idx_nan), 1);
    
    % segment using fieldtrip
    cfg = struct;
    cfg.trl = trl;
    data_ft_seg = ft_redefinetrial(cfg, data_ft);    
%     data_ft_seg.trialinfo = [onset, offset, trl(:, 4)];
    
end