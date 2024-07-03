function [suc, oc, timestamps, trl, onsetLabels] = teSegment_labelTime(...
    data, label, dur_trial, dur_baseline, varargin)
% Segments data into trials using a label to define the onset, and a
% duration to define the offset. Optionally a baseline can be included.
% This is the most common type of segmentation when dealing with EEG data
%
% Required input args
%
%   data - a fieldtrip dataset
%
%   label - text event labels to segment on. These define the onset of a
%   segment (excluding the baseline, which is applied separately). Can be
%   either a char (for a single label) or a cellstr (for multiple labels).
%   Each label is looked up in the te log data. If fieldtrip data is
%   present, and a sync structure is in place (from teSync) then the
%   corresponding fieldtrip event will be looked up from the sync struct. 
%
%   dur_trial - the duration in seconds of each trial 
%
%   dur_baseline - the duration of the baseline, expressed as a negative
%   scalar, in seconds (e.g. a 100ms baseline would be expressed as -0.100)
%
% Optional input args
%
%   ftData - fieldtrip data
%
%   excludeUnmatchedEvents - in situations where fieldtrip data is present,
%   and some te events are unmatched (not found) in the ft data, this will
%   cause the unmatched te events to be dropped (filtered out). This keeps
%   the fieldtrip trl in sync with the te data. 

% check inputs

    if ~exist('data', 'var') || ~isa(data, 'teData')
        error('Must pass a teData (or subclass) instance as the first input argument.')
    end
    
    if ~exist('label', 'var') || isempty(label) ||...
            (~ischar(label) && ~iscellstr(label))
        error('Must pass a label (char) or labels (cellstr) as the second input argument.')
    end
    
    if ~exist('dur_trial', 'var') || isempty(dur_trial) ||...
            ~isnumeric(dur_trial) || ~isscalar(dur_trial) || dur_trial <= 0
        error('Must pass a scalar numeric trial duration as the third input argument.')
    end
    
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
    
% parse optional

    crit_eegMethod          =   @(x) ischar(x) && ismember(x, {'synctable', 'syncabstime','abstime'});         

    parser =                    inputParser;
    addParameter(               parser, 'ftData',                   [],             @isstruct                   )
    addParameter(               parser, 'eegMethod',                'synctable',    crit_eegMethod              )
    addParameter(               parser, 'eegSync',                  [],             @isstruct                    )
    addParameter(               parser, 'excludeUnmatchedEvents',   true,           @islogical                  )
    parse(                      parser, varargin{:});
    data_ft                 =   parser.Results.ftData;
    eegMethod               =   parser.Results.eegMethod;
    eegSync                 =   parser.Results.eegSync;
    excludeUnmatchedEvents  =   parser.Results.excludeUnmatchedEvents;
    
% get events from log

    events = data.Log.Events;
   
% can only (currently) work on string event labels. Find any non-string
% events, warn, then ignore them. 

    idx_notString = ~cellfun(@ischar, events.data);
    if any(idx_notString)
        warning('Non-string event labels detected in log (%d). These will be ignored.',...
            sum(idx_notString))
        events(idx_notString, :) = [];
    end
    
% find all occurences of onset labels, and look up their timestamps. These
% will form the trial onset times. 

    idx_onsetLab = ismember(events.data, label);
    
    % if dropping unmatched events, do so
    idx_unMatched = cellfun(@isempty, events.sync_eeg_sample);
    idx_unMatchedAndWanted = idx_unMatched & idx_onsetLab;
    if excludeUnmatchedEvents && any(idx_unMatchedAndWanted)
        idx_onsetLab(idx_unMatched) = false;
        teEcho('Dropped %d events that were unmatched.\n', sum(idx_unMatchedAndWanted));
    elseif excludeUnmatchedEvents && any(idx_unMatchedAndWanted)
        warning('Some (%d) Task Engine events did not have matched Fieldtrip EEG events. These events will be dropped from the fieldtrip structure, but present in the Task Engine data. Use the excludeUnmatchedEvents input argument (set it to true) to drop these unmatched events from the Task Engine data.',...
            sum(idx_unMatchedAndWanted))
    end
    
    numOnsets = sum(idx_onsetLab);
    teEcho('Found %d onset events.\n', numOnsets);
    
% check that all onsets originate from the same task

    task_u = unique(events.task(idx_onsetLab));
    if length(task_u) > 1
        suc = false;
        oc = sprintf('Specified labels span more than one task');
        return
    end
    
% get timestamps

    % onset timestamps from labels
    timestamps(:, 1) = events.timestamp(idx_onsetLab) + dur_baseline;
    
    % offset
    timestamps(:, 2) = events.timestamp(idx_onsetLab) + dur_trial;
    
    % store onset event
    onsetLabels = events.data(idx_onsetLab);
    
% if fieldtrip data is present, form a trl structure (pairs of on/offset
% samples around each trial) from the label pairs

    ft = data.ExternalData('fieldtrip');
    hasFieldtrip = ~isempty(ft);
    if hasFieldtrip
        
        % check that fieldtrip data can be found
        if ~exist(ft.Paths('fieldtrip'), 'file')
            suc = false;
            oc = sprintf('Could not load fieldtrip data: %s',...
                ft.Paths('fieldtrip'));
            return
        end
        
        % we won't load the EEG data unless we have to. The 'abstime' and
        % 'syncabstime' methods need the .abstime field in the EEG data, so
        % in that case we must load it. 
        needToLoadEEG = ismember(eegMethod, {'abstime', 'syncabstime'});
        needAbsTime = ismember(eegMethod, {'abstime', 'syncabstime'});
        needEEGSync = isequal(eegMethod, 'syncabstime');
        
        % find EEG sample rate. If a metadata structure is present, with a
        % fieldtrip summary, use this. Otherwise we have to load the EEG
        % dataset and extract it directly from the fieldtrip struct
        hasMetadata = ~isempty(data.Metadata);
        hasFieldtripMetadata = hasMetadata && isprop(data.Metadata, 'fieldtrip');
        hasSampleRate = hasFieldtripMetadata && hasField(data.Metadata.fieldtrip, 'SampleRate');
        if ~needToLoadEEG && hasMetadata && hasFieldtripMetadata && hasSampleRate
            % we don't need to load the eeg data, so try to get it from the
            % metadata
            fs = data.Metadata.fieldtrip.SampleRate;
        else
            % we either need to load the EEG data for some other reason, or
            % we can't find the sample rate in the metadata, so load it
            tmp = load(ft.Paths('fieldtrip'));
            data_ft = tmp.ft_data;
            fs = data_ft.fsample;
        end
        
        % if we are going to be querying absolute (posix) timestamps,
        % ensure they are in the fieldtrip data
        if needAbsTime && ~hasField(data_ft, 'abstime')
            suc = false;
            oc = sprintf('EEG segmentation method %s requires a .abstime field in the fieldtrip data (containing absolute -- posix -- timestamps for each sample.',...
                eegMethod);
            return
        end 
        
        % if we are going to be correcting timestamps for drift, we need
        % the EEG sync struct for the offset and beta
        if needEEGSync && isempty(eegSync)
            suc = false;
            oc = sprintf('EEG segmenetation method %s requires an EEG sync struct (eegSync).',...
                eegMethod);
            return
        end
        
        % translate trial and baseline duration from seconds to samples
        dur_trial_samp = dur_trial * fs;
        dur_baseline_samp = dur_baseline * fs;
        
%         % detect un-matched EEG events
%         if any(idx_unMatchedAndWanted)
%             % todo - fix this if it ever becomes a problem
%             warning('Some (%d) Task Engine events did not have matched Fieldtrip EEG events. These events will be dropped.',...
%                 sum(idx_unMatchedAndWanted))
%         end

        switch eegMethod
            
            case 'synctable'
            % this is the default, where a pre-calculated lookup table is
            % queried to find the EEG event corresponding to each task
            % engine event
        
                % apply baseline to onset, and find offset
                onset_samp = cell2mat(events.sync_eeg_sample(idx_onsetLab));
                offset_samp = round(onset_samp + dur_trial_samp);
                onset_samp = round(onset_samp + dur_baseline_samp);
                
            case {'abstime', 'syncabstime'}
            % if the EEG data contains a .abstime field (absolute time aka
            % posix timestamps for each sample) then we can simply query
            % these to find the EEG sample indices at the onset and offset
            % of each segment. This assumes no clock drift, so is not
            % recommended. If the EEG data has been synchronised then the
            % 'syncabstime' option means we regress the timestamps first,
            % to account for clock drift
            
                if strcmpi(eegMethod, 'syncabstime')              
                    timestamps_eeg(:, 1) = eegSync.intercept +...
                        (eegSync.b1 .* (timestamps(:, 1) - eegSync.offset));
                    timestamps_eeg(:, 2) = eegSync.intercept +...
                        (eegSync.b1 .* (timestamps(:, 2) - eegSync.offset));                 
                else
                    timestamps_eeg = timestamps;
                end
            
                % loop through TE events and find sample indices closest to
                % each timestamp
                numEvents = size(timestamps_eeg, 1);
                onset_samp = nan(numEvents, 1);
                offset_samp = nan(numEvents, 1);
                for e = 1:numEvents
                    
                    onset_dlt = abs(data_ft.abstime - timestamps_eeg(e, 1));
                    onset_samp(e) = find(onset_dlt == min(onset_dlt));
                    
                    offset_dlt = abs(data_ft.abstime - timestamps_eeg(e, 2));
                    offset_samp(e) = find(offset_dlt == min(offset_dlt));
                    
%                     onset_samp(e) =...
%                         find(data_ft.abstime >= timestamps_eeg(e, 1), 1, 'first');
%                     offset_samp(e) =...
%                         find(data_ft.abstime >= timestamps_eeg(e, 2), 1, 'first');
                end

        end
        
        % create trl
        trl = [onset_samp, offset_samp,...
            repmat(dur_baseline_samp, size(onset_samp, 1), 1)];        
        
        % add event index to trl
        trl(:, 4) = 1:numOnsets;

    end
    
    suc = true;
    oc = '';

end