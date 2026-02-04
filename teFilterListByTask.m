function teFilterListByTask(list, taskName)

    if ~ismember(list.Table.Properties.VariableNames, 'Task')
        error('No ''task'' variable in the list.')
    end
    
    if ~iscell(taskName), taskName = {taskName}; end
    idx = cellfun(@(x) ismember(x, taskName), list.Table.Task);
    
    if ~any(idx)
        error('No matching tasks found in list.')
    end
    list.Table = list.Table(idx, :);
    teEcho('List %s was filtered for only those entries with ''task'':\n', list.Name);
    teEcho('\t%s\n', taskName{:});

end