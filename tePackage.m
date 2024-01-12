function tePackage(varargin)
% Takes a path to a task battery and produces an installer package. 
%
%   path_battery: full path to the battery to be packaged
%   
%   path_pack: full path to the output folder where the package will be
%   saved
%
% There are also some optional input arguments, expressed as name/value
% pairs:
%
%   'extra_folder' / <path to folder>: allows an extra folder to be copied.
%   For example, to include the et_tools package, use the name/value pair:
% 
%       'extra_folder', '/users/luke/code/dev/et_tools'
%
%   'tobii_sdk_version' / <version>: allows selecting a particular version
%   of the Tobii Pro SDK. <version> should be a string containing a path to
%   a folder containing the desired SDK version. 

    parser = inputParser;
    parser.addRequired('path_battery', @(x) ischar(x) && exist(x, 'dir'));
    parser.addRequired('path_pack', @ischar);
    parser.addParameter('extra_folder', [], @(x) iscell(x) || (ischar(x) && exist(x, 'dir')));
    parser.addParameter('tobii_sdk_version', [], @(x) ischar(x) && exist(x, 'dir'));
    parser.parse(varargin{:})
    path_battery = parser.Results.path_battery;
    path_pack = parser.Results.path_pack;
    path_extra = parser.Results.extra_folder;
    tobii_sdk_version = parser.Results.tobii_sdk_version;

    path_master = '/Users/luke/code/Dev/stim/_master';

    if ~exist(path_battery, 'dir') 
        error('Could not find battery path at %s', path_battery);
    end

    % extract battery name
    parts = strsplit(path_battery, filesep);
    battery = parts{end};
    
    % find tasks
    path_reg = fullfile(path_battery, sprintf('%s.reg.mat', battery));
    if ~exist(path_reg, 'file')
        error('Registry file not found at %s.', path_reg)
    end
    load(path_reg);
    tasks = reg.Tasks.Keys';
    numTasks = length(tasks);
    
    % battery

        % battery - dest
        path_battery_pack = fullfile(path_pack, 'batteries', battery);
        tryToMakePath(path_battery_pack)

        % copy
        copyfile(path_battery, path_battery_pack)
        fprintf('Copied battery %s from %s to %s\n', battery, path_battery,...
            path_battery_pack);

    % tasks 
    
        path_tasks_src = cell(numTasks, 1);
        path_tasks_pack = cell(numTasks, 1);
        
        for t = 1:numTasks

            % source
            path_tasks_src{t} = fullfile(path_master, 'tasks', tasks{t});
            if ~exist(path_tasks_src{t}, 'dir')
                error('Could not find task path at %s', path_tasks_src{t});
            end

            % dest
            path_tasks_pack{t} = fullfile(path_pack, 'tasks', tasks{t});
            tryToMakePath(path_tasks_pack{t});

            % copy
            copyfile(path_tasks_src{t}, path_tasks_pack{t})
            fprintf('Copied task %s from %s to %s\n', tasks{t}, path_tasks_src{t},...
                path_tasks_pack{t});
        end

    % lm_tools
    
        path_lmtools_src = fullfile(path_master, 'lm_tools');
        if ~exist(path_lmtools_src, 'dir') 
            error('Could not find lm_tools path at %s', path_lmtools_src);
        end

        path_lmtools_pack = fullfile(path_pack, 'lm_tools');
        tryToMakePath(path_lmtools_pack)

        % copy
        copyfile(path_lmtools_src, path_lmtools_pack)
        fprintf('Copied lm_tools from %s to %s\n', path_lmtools_src,...
            path_lmtools_pack);
        
    % task engine
    
        path_te_src = fullfile(path_master, 'TaskEngine2');
        if ~exist(path_te_src, 'dir') 
            error('Could not find Task Engine 2 path at %s', path_te_src);
        end

        path_te_pack = fullfile(path_pack, 'TaskEngine2');
        tryToMakePath(path_te_pack)

        % copy
        copyfile(path_te_src, path_te_pack)    
        fprintf('Copied Task Engine 2 from %s to %s\n', path_te_src,...
            path_te_pack);        
        
    % optionally swap tobii SDK versions in the package (output) folder
    
        if ~isempty(tobii_sdk_version)
            path_current = fullfile(path_te_pack, 'tobii');
            if ~exist(tobii_sdk_version, 'dir')
                error('Tobii SDK version not found at: %s', tobii_sdk_version)
            end
            % zip current version of the SDK in the package folder
            file_zip = [path_current, '.zip'];
            zip(file_zip, path_current)
            fprintf('Backed up package Tobii SDK folder to: %s\n', file_zip);
            % delete the current version folder
            rmdir(path_current, 's')
            fprintf('Deleted package Tobii SDK folder at: %s\n', path_current);
            % copy the new folder
            copyfile(tobii_sdk_version, path_current)
            fprintf('Copied specific Tobii SDK version into package folder from: %s\n', tobii_sdk_version);
        end
        
    % any other files
    
        if ~isempty(path_extra)
            if ~iscell(path_extra)
                path_extra = {path_extra};
            end
            numOther = length(path_extra);
            for i = 1:numOther
                parts = strsplit(path_extra{i}, filesep);
                copyfile(path_extra{i}, fullfile(path_pack, parts{end}));
                fprintf('Copied additional package(s) from %s to %s\n', varargin{i},...
                    path_pack);      
            end
        end

end