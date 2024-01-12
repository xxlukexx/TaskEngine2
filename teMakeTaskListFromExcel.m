function list = teMakeTaskListFromExcel(path_taskList, path_excel, varName)
% loads an Excel sheet and uses the contents in a lists .Table property. If
% a task list exists at path_taskList it will be loaded and its .Table
% property updated (so that other properties remain the same). Then it is
% saved. 

    if ~exist('varName', 'var') || isempty(varName)
        varName = 'tasks';
        varNameSet = false;
    else
        varNameSet = true;
    end

    % load existing list (if present)
    if ~exist(path_taskList, 'file')
        list = teList;
        list.Name = varName;
        type = 'new';
    else
        tmp = load(path_taskList);
        fnames = fieldnames(tmp);
        varName_file = fnames{1};
        if ~isa(tmp.(varName_file), 'teList')
            error('The first variable in the saved file %s is not a teList object.')
        else
            list = tmp.(varName_file);
        end
        type = 'update';
        
        % varName can be passed to this function, in which case varNameSet
        % will be true. If it has NOT Been passed, use the varname in the
        % struct that was read from disk (the existing task list file)
        if ~varNameSet
            varName = varName_file;
        end
    end

    % load Excel
    if ~exist(path_excel, 'file')
        error('Path not found: %s', path_excel)
    end
    xl = readtable(path_excel);
    
    % set list
    list.CustomSetTable(xl);
    
    % back up old file (if present)
    if isequal(type, 'update')
        file_bak = sprintf('%s.bak', path_taskList);
        copyfile(path_taskList, file_bak);
        teEcho('Backed up previous task list to %s\n', file_bak);
    end
    
    % save
    eval(sprintf('%s = list;', varName));
    save(path_taskList, varName)
    teEcho('Saved new task list to: %s\n', path_taskList);
 
end