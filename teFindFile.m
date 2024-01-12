function found = teFindFile(path_in, search, varargin)
% finds a file within a folder using wildcard matching. For example, if we
% wish to find a tracker file that is names 'tracker_BATTERY_SUBJECTID.mat'
% then we use the wildcard '*tracker*' to return this file. 

    % check that path is a folder
    if ~exist('path_in', 'var') || isempty(path_in) || ~exist(path_in, 'dir')
        found = [];
        return
    end
    
    % check that search is char
    if ~ischar(search) 
        error('''search'' must be a char.')
    end
    
    % search for files
    d = dir(sprintf('%s%s%s', path_in, filesep, search));
    
    % make full paths
    found = cellfun(@(filename) fullfile(path_in, filename), {d.name},...
        'uniform', false);
    
    % if -latest switch is set, find the latest file from results
    if ismember('-latest', varargin)
        idx_latest = find([d.datenum] == max([d.datenum]), 1);
        found = found(idx_latest);
    end
    
    % if -largest switch is set, find the largest file from results
    if ismember('-largest', varargin)
        idx_largest = find([d.bytes] == max([d.bytes]), 1);
        found = found(idx_largest);
    end
    
    % if is scalar cell array, return as char
    if isscalar(found)
        found = found{1};
    end

end