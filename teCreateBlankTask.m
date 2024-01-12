function [obj, path_task, path_stim] = teCreateBlankTask(path_folder, name)

    if nargin ~= 2
        error('Call this function with two input arguments, 1) path to task folder, 2) name of task')
    end
    
    if ~ischar(path_folder)
        error('Task path must be a string.')
    end
    
    if ~exist(path_folder, 'dir')
        error('Task path not found.')
    end
    
    if ~ischar(name)
        error('Name must be a string.')
    end
    
    % build path to task
    
        path_task = fullfile(path_folder, name);
        if exist(path_task, 'dir')

            % path exists, confirm overwrite 
            msg = sprintf('Path [%s] exists.\nDo you want to continue? Files may be overwritten. (y/n) >',...
                path_task);
            resp = input(msg, 's');
            if ~instr(lower(resp), 'y')
                return
            end
        else

            % path doesn't exist, make it
            [suc, err] = mkdir(path_task);
            if ~suc
                error('Error creating path [%s]:\n\n%s', path_task, err)
            end 
        end
        
    % load and process blank task templates, adding name and version etc.
    % where necessary
    
        if ~exist('blankTaskDef.mat', 'file')
            error('blankTaskDef.mat not found.')
        end
        def = load('blankTaskDef.mat');
        
        % task version 
        def.strTrialVer = strrep(def.strTrialVer, '#taskname#',...
            sprintf('%s', name));
        def.strTrialVer = strrep(def.strTrialVer, '#date#',...
            datestr(now, 'yyyymmdd'));
        def.strTrialVer = strrep(def.strTrialVer, '#version#', '1');
        
        % trial function
        def.strTrialFun = strrep(def.strTrialFun, '#name#', name);
        
        % build output paths
        file_ver = fullfile(path_task, sprintf('%s_ver.m', name));
        file_trialFun = fullfile(path_task, sprintf('%s_trial.m', name));
        
    % write output files
    
        [fid_ver, err_ver] = fopen(file_ver, 'w+');
        fprintf(fid_ver, '%s', def.strTrialVer);
        fclose(fid_ver);
        
        fid_trialFun = fopen(file_trialFun, 'w+');
        fprintf(fid_trialFun, '%s', def.strTrialFun);
        fclose(fid_trialFun);
        
   % make stimuli folder
   
        path_stim = fullfile(path_task, 'stimuli');
        [suc, err] = mkdir(path_stim);
        if ~suc
            error('Error creating stimuli path [%s]:\n\n%s', path_stim, err)
        end     

    % create task instance
    
        if nargout ~= 0
            obj = teTask(path_task);
        end
        
end