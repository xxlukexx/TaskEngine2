function tab = teLogExtract(logArray, varargin)

    if ~iscell(logArray) && ~all(cellfun(@(x) isa(x, 'teListItem')))
        error('logArray must be a cell array of teListItems')
    end
    
    if isempty(logArray), tab = table; return, end
    
    % get variable names, and unique signatures
    [fnames, fnames_u, ~, ~, sig_i, sig_s, logArray] =...
        teLogGetVariableNames(logArray, varargin{:});    
    if isempty(logArray), return, end

    % make empty structure of cells, add these to the table
    c = cell(length(logArray), length(fnames_u) + 1);    
    % loop through unique field combinations
    for s = 1:length(sig_i)
        % get indices of log items that correspond to the current field
        % combo
        idx = find(sig_s == s);
        % get fieldnames of current combo
        fn = fnames{idx(1)};
        fidx = cellfun(@(x) find(ismember(fnames_u, x)), fn);
        % get values from current combo fields in the log array
        items = cellfun(@(x) struct2cell(x), logArray(idx), 'uniform', false);
        items = horzcat(items{:})';
        % arrange them in c
        c(idx, fidx) = items;
        % store original log index in c
        c(idx, end) = num2cell(idx);
    end
    % if logIdx is already a fieldname, rename it
    searchStr = 'logIdx';
    idx = find(strncmpi(fnames_u, searchStr, length(searchStr)));
    for i = 1:length(idx)
        fnames_u{idx(i)} = sprintf('%s_%d', fnames_u{idx(i)}, i);
    end
    % put into table
    tab = cell2table(c, 'variablenames', [fnames_u, 'logIdx']);
    % filter out unwanted cols
    if ~isempty(varargin)
        [~, keep] = intersect(fnames_u, varargin);
        tab = tab(:, keep);
    end
    
    % unify data types by column
    tabc = table2cell(tab);
    empty = cellfun(@isempty, tabc);
%     logNonScalar = cellfun(@(x) islogical(x) && isscalar(x), tabc);
    for c = 1:size(tab, 2)
        
        col = tab{:, c};
        
        if iscell(col) && any(empty(:, c))
            
%             empty = cellfun(@isempty, col);
            
%             if all(logNonScalar(:, c))
            if all(cellfun(@(x) islogical(x) && isscalar(x), col(~empty(:, c))))
%             if all(cellfun(@islogical, col(~empty(:, c)))) &&...
%                     all(cellfun(@isscalar, col(~empty(:, c))))
                logcol = false(size(col));
                logcol(~empty(:, c)) = cell2mat(col(~empty(:, c)));
                varName = tab.Properties.VariableNames{c};
                tab.(varName) = logcol;
            end
            
        end
        
    end

end