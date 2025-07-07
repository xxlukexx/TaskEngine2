function tab = teLogExtract(logArray, varargin)
    % teLogExtract
    %
    % Converts a cell array of structs (teListItem objects) into a table
    % with columns corresponding to the unique fieldnames across all structs.
    % Missing fields are represented as empty cells/logicals. An additional
    % column for the original log index is appended. If variable names are
    % provided in 'varargin', only those columns are kept in the resulting table.
    %
    % Usage:
    %   tab = teLogExtract(logArray)
    %   tab = teLogExtract(logArray, varNamesToKeep, ...)
    %
    % Inputs:
    %   logArray : Cell array of teListItem structs. Each struct can have
    %              different fieldnames.
    %   varargin : (Optional) A list of fieldnames to keep in the final table.
    %
    % Output:
    %   tab      : A MATLAB table with columns for each unique field, plus
    %              'logIdx' for the original row index.
    %
    % See also: teLogGetVariableNames

    % Verify input type
    if ~iscell(logArray) && ~all(cellfun(@(x) isa(x, 'teListItem'), logArray))
        error('logArray must be a cell array of teListItems.');
    end

    % Return empty table if input is empty
    if isempty(logArray)
        tab = table;
        return
    end

    % Gather fieldnames and signatures (helper function)
    [fnames, fnamesUnique, ~, ~, sigIdx, sigSet, logArray] = ...
        teLogGetVariableNames(logArray, varargin{:});
    if isempty(logArray), tab = table; return; end

    % Initialize a cell array for all data
    cell_grid = cell(length(logArray), length(fnamesUnique));
    
    % determine whether we need to add a log_idx column, or if one already
    % exists
    col_log_idx = cellfun(@(x) contains(x, 'logIdx'), fnamesUnique);
    need_to_add_log_idx = ~any(col_log_idx);
    if need_to_add_log_idx
        % add a column on the end for log idx
        cell_grid = [cell_grid, cell(length(logArray), 1)];
        col_log_idx = size(cell_grid, 2);
    else
        % find the actual logIdx (i.e. not logIdx_2 etc) column
        new_col_log_idx = find(strcmpi(fnamesUnique, 'logIdx'));
        % if it's not in there, fall back to the first variable that
        % contains 'logIdx' from our earlier search
        if isempty(new_col_log_idx)
            col_log_idx = find(log_log_idx, 1);
        else
            col_log_idx = new_col_log_idx;
        end
    end

    % Loop through each unique field-combination signature
    for s = 1:length(sigIdx)
        % Rows that share this signature
        currentRows = (sigSet == s);

        % Fieldnames for this signature and their index in the master list
        currentFieldnames = fnames{find(currentRows, 1)};
        masterIdx = cellfun(@(x) find(ismember(fnamesUnique, x)), ...
                            currentFieldnames);

        % Extract struct values, turning each into a cell array
        items = cellfun(@(x) struct2cell(x), logArray(currentRows), ...
                        'UniformOutput', false);
        items = horzcat(items{:})';  % Concatenate horizontally, then transpose

        % Assign extracted items into dataCells
        cell_grid(currentRows, masterIdx) = items;

        % Populate the 'logIdx' column (last column)
        cell_grid(currentRows, col_log_idx) = num2cell(find(currentRows));
    end

%     % If 'logIdx' is already among the fieldnames, rename it to avoid collision
%     baseName = 'logIdx';
%     existingIdx = find(strncmpi(fnamesUnique, baseName, length(baseName)));
%     for i = 1:length(existingIdx)
%         fnamesUnique{existingIdx(i)} = sprintf('%s_%d', ...
%             fnamesUnique{existingIdx(i)}, i);
%     end

    % Create a table with the combined data
    if need_to_add_log_idx
        var_names = [fnamesUnique, 'logIdx'];
    else
        var_names = fnamesUnique;
    end
    tab = cell2table(cell_grid, 'VariableNames', var_names);

    % If user provided specific column names, filter the table
    if ~isempty(varargin)
        [~, keepIdx] = intersect(fnamesUnique, varargin);
        tab = tab(:, keepIdx);
    end

    % Attempt to unify data types in each column, e.g., convert single logical cells
    tableCells = table2cell(tab);
    cellIsEmpty = cellfun(@isempty, tableCells);

    for colIdx = 1:size(tab, 2)
        colData = tab{:, colIdx};

        % If the column is cell-based and has empty entries
        if iscell(colData) && any(cellIsEmpty(:, colIdx))

            % Check if all non-empty elements are single logicals
            isSingleLogical = @(x) islogical(x) && isscalar(x);
            if all(cellfun(isSingleLogical, colData(~cellIsEmpty(:, colIdx))))
                % Convert to a logical array
                logicalCol = false(size(colData));
                logicalCol(~cellIsEmpty(:, colIdx)) = cell2mat(colData(~cellIsEmpty(:, colIdx)));

                % Assign the converted column back into the table
                varName = tab.Properties.VariableNames{colIdx};
                tab.(varName) = logicalCol;
            end
        end
    end
end
