function teWriteTrialLogDataToDisk(lg, path_out)

    if ~exist(path_out, 'dir')
        error('Path not found: %s', path_out);
    end
    
    numTasks = length(lg.Tasks);
    for t = 1:numTasks
        
        tab = teLogFilter(lg.LogArray, 'task', lg.Tasks{t}, 'topic', 'trial_log_data');
        if isempty(tab), continue, end
        
        file_out = fullfile(path_out, sprintf('%s.csv', lg.Tasks{t}));
        writetable(tab, file_out);
        
    end
        
        
        
        
        
end
    