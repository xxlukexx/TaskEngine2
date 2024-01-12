function tasks = teListTasks(logArray)
 
    if ~iscell(logArray)
        error('''data'' must be a teData instance.')
    end
    
    tab = teLogExtract(logArray);
    if ismember('task', tab.Properties.VariableNames)
        % find empties
        empty = cellfun(@isempty, tab.task);
        tab(empty, :) = [];
        tasks = unique(tab.task);
    else
        tasks = [];
    end

end