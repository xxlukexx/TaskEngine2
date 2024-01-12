function varargout = teSegment(data, type, varargin)

    % handle multiple datasets
    if ~iscell(data)
        data = {data};
    end
    
    % parse inputs
    prs = inputParser;
    validSession = @iscell;
    validType = @(x) ismember(x, {'labelpairs', 'labeltime', 'trial_log_fields'});
    validDuration = @(x) isnumeric(x) && isscalar(x) && x > 0;
    prs.addRequired('data', validSession);
    prs.addRequired('type', validType);
    prs.addParameter('onsetlabel', [], @ischar);
    prs.addParameter('offsetlabel', [], @ischar);
    prs.addParameter('onsetfield', [], @ischar);
    prs.addParameter('offsetfield', [], @ischar);
    prs.addParameter('logquery', [], @iscell); 
    prs.addParameter('trialduration', [], validDuration);
    prs.addParameter('baselineduration', [], validDuration);
    prs.addParameter('fieldtrip', [], @isstruct);
%     prs.addParameter('trialerrors', false, @islogical)
    prs.parse(data, type, varargin{:});
    
    % get results
    data = prs.Results.data;
    type = prs.Results.type;
    label_onset = prs.Results.onsetlabel;
    label_offset = prs.Results.offsetlabel;
    field_onset = prs.Results.onsetfield;
    field_offset = prs.Results.offsetfield;
    log_query = prs.Results.logquery;
    dur_trial = prs.Results.trialduration;
    dur_baseline = prs.Results.baselineduration;
    ft = prs.Results.fieldtrip;
%     segmentTrialErrors = prs.Results.trialerrors;
    
    % check inputs
    switch type
        case 'labelpairs'
            
            if isempty(label_onset)
                error('To segment using label pairs, must provide an onset label (onsetlabel).')
            end
            if isempty(label_offset)
                error('To segement using label pairs, must provide an offset label (offsetlabel).')
            end
            if isempty(dur_baseline)
                dur_baseline = 0;
            end            
            
        case 'labeltime'
            
            if isempty(label_onset)
                error('To segment using label time, must provide an onset label (onsetlabel).')
            end    
            if isempty(dur_trial)
                error('To segment using label time, must provide a trial duration (trialduration).')
            end
            if isempty(dur_baseline)
                dur_baseline = 0;
            end
            
        case 'trial_log_fields'
            
            if isempty(field_onset)
                error('To segment using trial_log_fields, must provide an onset field name (onsetfield).')
            end    
            if isempty(field_offset)
                error('To segment using trial_log_fields, must provide an offset field name (offsetfield).')
            end
            if isempty(dur_baseline)
                dur_baseline = 0;
            end
            
    end
    
    % only use parfor if a parpool is available
    numData = length(data);
    suc = false(numData, 1);
    oc = cell(numData, 1);
    timestamps = cell(numData, 1);
    smry = cell(numData, 1);
    trl = cell(numData, 1);
    label = cell(numData, 1);
    h_pool = gcp('noCreate');
    if isempty(h_pool)
        m = 0;
    else
        m = h_pool.NumWorkers;
    end
        
    % loop through all datasets and segment using appropriate sub-function
%     parfor (i = 1:numData, m)
%     numData = 10;
    startTime = clock;
    wb = [];
    for i = 1:numData
        
        if etime(clock, startTime) > 1
            if isempty(wb)
                wb = waitbar(i/numData, sprintf('Segmenting: %d of %d datasets.', i, numData));
            else
                wb = waitbar(i/numData, wb, sprintf('Segmenting: %d of %d datasets.', i, numData));
            end
            startTime = clock;
        end
            
        switch type
            case 'labelpairs'
                
                [tmp_suc, tmp_oc, tmp_timestamps, tmp_smry, tmp_trl] =...
                    teSegment_labelPairs(data{i}, label_onset,...
                    label_offset, dur_baseline, 'fieldtrip', ft);
                
            case 'labeltime'
                
                [tmp_suc, tmp_oc, tmp_timestamps, tmp_smry, tmp_trl] =...
                    teSegment_labelTime(data{i}, label_onset, dur_trial,...
                    dur_baseline, 'fieldtrip', ft);
                
            case 'trial_log_fields'
                
                [tmp_suc, tmp_oc, tmp_timestamps, tmp_smry, tmp_trl] =...
                    teSegment_trial_log_fields(data{i}, field_onset,...
                    field_offset, log_query, dur_baseline,...
                    'fieldtrip', ft);
                
            otherwise
                
                % this is just here to stop matlab moaning about
                % uninitialised temp vars in a parfor loop (all code paths
                % must set these vars to avoid the warning)
                tmp_suc = false;
                tmp_oc = 'invalid type';
                tmp_timestamps = [];
                tmp_smry = [];
                tmp_trl = [];
                tmp_lab = [];
                
        end
        
        suc(i) = tmp_suc;
        oc{i} = tmp_oc;
        timestamps{i} = tmp_timestamps;
        smry{i} = tmp_smry;
        trl{i} = tmp_trl;
        
        % extract string of onset labels from summary
        if suc(i) 
            numSegs = size(smry{i}, 1);
            
            switch type
                case {'labelpairs', 'labeltime'}
                    for s = 1:numSegs
                        if iscell(smry{i}.pairedOnsetLabels{s}) &&...
                                all(cellfun(@ischar, smry{i}.pairedOnsetLabels{s}))
                            label{i}{s} = cell2char(smry{i}.pairedOnsetLabels{s});
                        elseif ischar(smry{i}.pairedOnsetLabels{s})
                            label{i}{s} = smry{i}.pairedOnsetLabels{s};
                        else
                            label{i}{s} = sprintf('segment_%02d', s);
                        end
                    end
                case 'trial_log_fields'
                    label{i} = smry{i}.onsetField;
            end
            
        end
        
    end
    delete(wb)
    
    varargout{1} = suc;
    varargout{2} = oc;
    varargout{3} = timestamps;
    varargout{4} = smry;
    varargout{5} = label;
    varargout{6} = trl;

end