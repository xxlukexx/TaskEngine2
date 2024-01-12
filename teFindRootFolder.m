function path_root = teFindRootFolder

    file_pres = which('tePresenter');
    if isempty(file_pres)
        error('tePresenter not found in Matlab path.')
    end
    
    parts = strsplit(file_pres, filesep);
    path_root = [filesep, fullfile(parts{1:end - 1})];
    
    if ~exist(path_root, 'dir')
        error('Root path was detected to be %s but this path does not exist.',...
            path_root)
    end

end