function tab = teSummariseRegisteredEventsInTaskFolder(path_tasks)

    allFiles = recdir(path_tasks);
    idx_keep = cellfun(@(x) contains(x, 'defineEvents.m'), allFiles);
    evFiles = allFiles(idx_keep);
    num = length(evFiles);
    events = teEventCollection;
    for f = 1:num
        [~, fun, ~] = fileparts(evFiles{f});
        feval(fun, events);
    end
    
    eeg = events.Summary.eeg;
    warning('Does not currently handle empty eeg events.')
    
    [u, i, s] = unique(eeg);
    numUnique = length(i);
    tab_code = u;
    tab_tasks = cell(numUnique, 1);
    tab_lab = cell(numUnique, 1);
    tab_num = zeros(numUnique, 1);
    for e = 1:numUnique
        idx = find(s == e);
        tab_tasks{e} = '';
        for dup = 1:length(idx)
            tab_tasks{e} = sprintf('%s %s', tab_tasks{e}, events.Summary.task{idx(dup)});
            tab_lab{e} = sprintf('%s %s', tab_lab{e}, events.Summary.Label{idx(dup)});
        end
        tab_num(e) = sum(s == e);
    end
    tab = table;
    tab.code = tab_code;
    tab.num = tab_num;
    tab.label = tab_lab;
    tab.task = tab_tasks;
    
%     tb = tabulate(eeg);
%     gridSize = ceil(sqrt(size(tb, 1)));
%     grid_col = nan(gridSize, gridSize);
%     grid_code = nan(gridSize, gridSize);
%     x = 1;
%     y = 1;
%     for i = 1:size(tb, 1)
%         grid_code(x, y) = tb(i, 1);
%         grid_col(x, y) = tb(i, 2);
%         x = x + 1;
%         if x > gridSize
%             x = 1;
%             y = y + 1;
%         end
%     end
    
end