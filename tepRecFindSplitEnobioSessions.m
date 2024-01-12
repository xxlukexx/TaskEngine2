function [ops, path_enobio] = tepRecFindSplitEnobioSessions(path_in, ops)

    if ~exist('ops', 'var') || isempty(ops)
        ops = struct;
    end
    
    ops.tepRecFindSplitEnobioSessions_suc = false;
    ops.tepRecFindSplitEnobioSessions_oc = 'unknown error';
    
    allFiles = recdir(path_in);
    idx_enobio =...
        cellfun(@(x) contains(x, 'enobio') && isfolder(x), allFiles);
    files = allFiles(idx_enobio);
    num = length(files);
    
    idx_split = false(size(files));
    for i = 1:num
        d = dir(fullfile(files{i}, filesep, '*.easy'));
        idx_split(i) = length(d) > 1;
    end
       
    path_enobio = files(idx_split);
    teEcho('Found %d split enobio sessions. These were at:\n\n', sum(idx_split));
    teEcho('\t%s\n', path_enobio{:});
    
end
        
