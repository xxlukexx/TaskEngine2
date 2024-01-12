function labels = teCodes2RegisteredEvents(regEvents, codes, type)

    % type, e.g. 'eeg' or 'nirs' - defaults to eeg
    if ~exist('type', 'var') || isempty(type)
        type = 'eeg';
        warning('No type specified, defaulting to ''eeg''')
    end
    
    % get sumamry of reg events
    smry = regEvents.Summary;
    
    % find type
    col_type = strcmpi(type, smry.Properties.VariableNames);
    if ~any(col_type)
        error('Event type ''%s'' not found in registered events.', type)
    elseif sum(col_type) > 1
        error('Event type ''%s'' found %d times in registered events.',...
            type, sum(col_type));
    end
    
    % get master list of eeg codes
%     masterCodes = cell2mat(smry{:, col_type});
    masterCodes = smry{:, col_type};
    
    % use that list as a lookup table to find the indices of each segmented
    % event in the master list
    idx = arrayfun(@(x) find(x == masterCodes, 1), codes, 'UniformOutput',...
        false);
    
    % events not found in the master list are currently empty elements in
    % the cell array idx. Make an index of these missing events, then
    % remove the missing elements
    missing = cellfun(@isempty, idx);
    idx(missing) = num2cell(nan(sum(missing), 1));
    idx = cell2mat(idx);
    
    % look up the corresponding label for each eeg code
    labels = cell(length(idx), 1);
    labels(~missing) = regEvents.Summary{idx(~missing), 1};

end