function [suc, oc, timestamps, smry, trl] = teSegment_trial_log_fields(...
    data, onsetField, offsetField, logQuery, dur_baseline, varargin)
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
    
    if ~exist('onsetField', 'var') || isempty(onsetField) ||...
            (~ischar(onsetField) && ~iscellstr(onsetField))
        error('Must pass an onset field (char) as the second input argument.')
    end
    
    if ~exist('offsetField', 'var') || isempty(offsetField) ||...
            (~ischar(offsetField) && ~iscellstr(offsetField))
        error('Must pass an offset label (char) as the third input argument.')
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

    parser      =   inputParser;
    addParameter(   parser, 'fieldtrip',               [],         @(x) isempty(x) || isstruct(x)       )
    parse(          parser, varargin{:});
    data_ft     =   parser.Results.fieldtrip;
    
% (optionally) query the log

    if ~isempty(logQuery)
        
        try
            tab = teLogFilter(data.Log.LogArray, logQuery{:});
        catch ERR
            suc = false;
            oc = sprintf('Error querying log: %s', ERR.message);
            return
        end
        
    else
        
        % use the entire log
        tab = teLogFilter(data.Log.LogArray, 'topic', 'trial_log_data');

    end
    
    if isempty(tab)
        suc = false;
        oc = 'Log query returned no data.';
        return
    end
    
% parse the results for timestamps

    % look for on/offset fields, check they contain numbers
    vars = tab.Properties.VariableNames;
    if ~ismember(onsetField, vars)
        suc = false;
        oc = sprintf('Onset field ''%s'' not found after log query', onsetField);
        return    
    elseif ~isnumeric(tab.(onsetField))
        try
            tab.(onsetField) = cell2mat(tab.(onsetField));
            convFailed = false;
        catch ERR
            convFailed = true;
        end
        if convFailed || ~isnumeric(tab.(onsetField))
            suc = false;
            oc = sprintf('Onset field ''%s'' is not numeric', onsetField);
            return    
        end
    end
    if ~ismember(offsetField, vars)
        suc = false;
        oc = sprintf('Offset field ''%s'' not found after log query', offsetField);
        return    
    elseif ~isnumeric(tab.(offsetField))
        try
            tab.(offsetField) = cell2mat(tab.(offsetField));
            convFailed = false;
        catch ERR
            convFailed = true;
        end
        if convFailed || ~isnumeric(tab.(offsetField))
            suc = false;
            oc = sprintf('Offset field ''%s'' is not numeric', offsetField);
            return    
        end 
    end    
    
    % just those fields
    tabf = tab(:, {'trialguid', onsetField, offsetField});
    timestamps = table2array(tabf(:, {onsetField, offsetField}));
    if iscell(timestamps)
        timestamps = cell2mat(timestamps);
    end
    
    % (optionally) apply baseline to onset timestamps
    if dur_baseline ~= 0
        timestamps(:, 1) = timestamps(:, 1) + dur_baseline;
    end
    
% summarise

    numSegs = size(timestamps, 1);
    smry = table;
    smry.onsetField = repmat({onsetField}, numSegs, 1);
    smry.offsetField = repmat({offsetField}, numSegs, 1);
    smry.duration = timestamps(:, 2) - timestamps(:, 1);
    smry.trialGUID = tab.trialguid;

    suc = true;
    oc = '';

end