function [suc, oc, timestamps, smry, trl] = teSegment_labelPairs(...
    data, onsetLabel, offsetLabel, varargin)
% Segments data into trials using pairs of labels to define trial
% on/offsets. 

    suc = false;
    oc = 'unknown error';
    timestamps = [];
    smry = table;
    trl = [];

% check inputs

    if ~exist('data', 'var') || ~isa(data, 'teData')
        error('Must pass a teData (or subclass) instance as the first input argument.')
    end
    
    if ~exist('onsetLabel', 'var') || isempty(onsetLabel) ||...
            (~ischar(onsetLabel) && ~iscellstr(onsetLabel))
        error('Must pass an onset label (char) or labels (cellstr) as the second input argument.')
    end
    
    if ~exist('offsetLabel', 'var') || isempty(offsetLabel) ||...
            (~ischar(offsetLabel) && ~iscellstr(offsetLabel))
        error('Must pass an offset label (char) or labels (cellstr) as the third input argument.')
    end    
    
% parse optional

    parser      =   inputParser;
    addParameter(   parser, 'fieldtrip',               [],         @(x) isempty(x) || isstruct(x)       )
    addParameter(   parser, 'task',                    [],         @ischar                              )
    addParameter(   parser, 'dur_baseline',            0,          @isnumeric                           )
    parse(          parser, varargin{:});
    data_ft     =   parser.Results.fieldtrip;
    task_filter =   parser.Results.task; 
    dur_baseline =  parser.Results.dur_baseline;
    
% validate baseline duration (if specified)

    if exist('dur_baseline', 'var') && ~isempty(dur_baseline)
        if ~isnumeric(dur_baseline) || ~isscalar(dur_baseline)
            error('Baseline duration must be a numeric scalar.')
        end
        % dur_baseline should be negative (makes sense since this is how we
        % usually describe an EEG baseline). Inform and throw an error
        % otherwise
        if dur_baseline > 0
            error('Baseline duration should be expressed as a negative number in seconds.')
        end
    else
        % baseline duration of 0 means no baseline
        dur_baseline = 0;
    end    
    
% get events from log

    events = data.Log.Events;
    
% (optionally) filter events for a particular task

    if ~isempty(task_filter)
        idx_task_filter = strcmpi(events.task, task_filter);
        if ~any(idx_task_filter)
            oc = sprintf('no events remain after filtering for task [%s]',...
                task_filter);
            return
        end
        events = events(idx_task_filter, :);
    end
    
% % can only (currently) work on string event labels. Find any non-string
% % events, warn, then ignore them. 
% 
%     idx_notString = ~cellfun(@ischar, events.data);
%     if any(idx_notString)
%         warning('Non-string event labels detected in log (%d). These will be ignored.',...
%             sum(idx_notString))
%         events(idx_notString, :) = [];
%     end
    
% find on/offset events. We must ensure these are paired (i.e. each offset
% is linked to the preceding onset, such that they form the bounds of one
% trial). For now we do this with a loop, if it's terribly slow it may need
% optimising

    numEvents = height(events);
    idx = 1;
    e = 0;
    idx_onsets = nan(numEvents, 1);
    idx_offsets = nan(numEvents, 1);
    lookingFor = 'onset';
    ev = events.data;
    
    % precalculate regex masks if wildcard pattern is detected
    onsetHasWildcard = contains(onsetLabel, '*');
    if onsetHasWildcard
        mask_onset = regexptranslate('wildcard', onsetLabel);
    end
    offsetHasWildcard = contains(offsetLabel, '*');
    if offsetHasWildcard
        mask_offset = regexptranslate('wildcard', offsetLabel);
    end

    while e < numEvents
        
        e = e + 1;
        
        switch lookingFor
            case 'onset'
                
                if onsetHasWildcard
                    onsetFound = lm_strcmpWildcard(ev{e}, [], mask_onset);
                else
                    onsetFound = strcmp(ev{e}, onsetLabel);
                end
                if onsetFound
                    idx_onsets(idx) = e;
                    lookingFor = 'offset';
                end
                
            case 'offset'
                
                if offsetHasWildcard
                    offsetFound = lm_strcmpWildcard(ev{e}, [], mask_offset);
                else
                    offsetFound = strcmp(ev{e}, offsetLabel);
                end
                if offsetFound
                    idx_offsets(idx) = e;
                    idx = idx + 1;
                    lookingFor = 'onset';
                end
                
        end
        
    end
    
    idx_onsets = idx_onsets(1:idx - 1);
    idx_offsets = idx_offsets(1:idx - 1);   
    
    if isempty(idx_onsets) || isempty(idx_offsets)
        suc = false;
        oc = sprintf('No label pairs found with onsetLabel ''%s'' and offsetLabel ''%s''',...
            onsetLabel, offsetLabel);
        return
    end
    
% check that all onsets originate from the same task

    tasks = events.task(idx_onsets);
    if all(~cellfun(@isempty, tasks))
        task_u = unique(tasks);
        if length(task_u) > 1
            suc = false;
            oc = sprintf('Specified labels span more than one task');
            return
        end
    end
    
% get timestamps

    % onset timestamps from labels
    timestamps(:, 1) = events.timestamp(idx_onsets) + dur_baseline;
    
    % offset
    timestamps(:, 2) = events.timestamp(idx_offsets);
    
    % store onset event
    smry.pairedOnsetLabels = events.data(idx_onsets);
    smry.pairedOffsetLabels = events.data(idx_offsets);
    smry.pairedDurations = events.timestamp(idx_offsets) -...
        events.timestamp(idx_onsets);
    if ismember('trialguid', events.Properties.VariableNames)
        smry.pairedTrialGUIDs = events.trialguid(idx_onsets);
    else
        smry.pairedTrialGUIDs = cell(size(idx_onsets));
    end    
    
% if fieldtrip data is present, form a trl structure (pairs of on/offset
% samples around each trial) from the label pairs

    ft = data.ExternalData('fieldtrip');
    hasFieldtrip = ~isempty(ft);
    if hasFieldtrip
        
        error('EEG data not currently supported.')
        
        % check that fieldtrip data can be found
        if ~exist(ft.Paths('fieldtrip'), 'file')
            suc = false;
            oc = sprintf('Could not load fieldtrip data: %s',...
                ft.Paths('fieldtrip'));
            return
        end
        
        % find EEG sample rate. If a metadata structure is present, with a
        % fieldtrip summary, use this. Otherwise we have to load the EEG
        % dataset and extract it directly from the fieldtrip struct
        hasMetadata = ~isempty(data.Metadata);
        hasFieldtripMetadata = isprop(data.Metadata, 'fieldtrip');
        hasSampleRate = hasField(data.Metadata.fieldtrip, 'SampleRate');
        if hasMetadata && hasFieldtripMetadata && hasSampleRate
            
            % extract from md
            fs = data.Metadata.fieldtrip.SampleRate;
            
        else
        
            % load fieldtrip data
            tmp = load(ft.Paths('fieldtrip'));
            data_ft = tmp.ft_data;
            fs = data_ft.samplerate;
            
        end
        
        % translate trial and baseline duration from seconds to samples
        dur_trial_samp = dur_trial * fs;
        dur_baseline_samp = dur_baseline * fs;
        
        % detect un-matched EEG events
        idx_unMatched = cellfun(@isempty, events.sync_eeg_sample);
        idx_unMatchedAndWanted = idx_unMatched & idx_onsetLab;
        if any(idx_unMatchedAndWanted)
            % todo - fix this if it ever becomes a problem
            warning('Some (%d) Task Engine events did not have matched Fieldtrip EEG events. These events will be dropped.',...
                sum(idx_unMatchedAndWanted))
        end
        
        % apply baseline to onset, and find offset
        onset_samp = cell2mat(events.sync_eeg_sample(idx_onsetLab));
        offset_samp = round(onset_samp + dur_trial_samp);
        onset_samp = round(onset_samp + dur_baseline_samp);
        
        % create trl
        trl = [onset_samp, offset_samp,...
            repmat(dur_baseline_samp, size(onset_samp, 1), 1)];        

    end
    
    suc = true;
    oc = '';

end