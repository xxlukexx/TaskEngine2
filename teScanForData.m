function [tab, dups] = teScanForData(path_data, tab)

% check input args and path

    if ~exist('tab', 'var') || isempty(tab)
        tab = table;
    end
    
    % check input arg
    if nargin == 0
        error('Must supply a path to scan.')
    end
    
    % check path
    if ~exist(path_data, 'dir')
        error('Path not found.')
    end

% recursively scan the input folder. This will give a list of all files and
% folders

    allFiles = recdir(path_data);
    numFiles = length(allFiles);

% loop through all files/folders, looking for task engine sessions

    is = false(numFiles, 1);
    guids = cell(numFiles, 1);
    path_sessions = cell(numFiles, 1);
    hashes = cell(numFiles, 1);
    needs_proc = true(numFiles, 1);
    
    for f = 1:numFiles
        
        % is the current path a session folder?
        [is(f), ~, path_tracker, tracker] = teIsSession(allFiles{f});
        
        % if this is a session, then it either:
        % 
        %   (1) exists in the table and is unchanged - do nothing, since
        %   this is a session we've seen before
        %
        %   (2) exists in the table and has changed - remove its entry from
        %   the table, so that it is treated as a new dataset 
        %
        %   (3) does not exist in the table, since it is a new dataset. In
        %   this case add to the table
        %
        if is(f)
            
            % default behaviour is not to add this session to the table
            needsAdding = false;
            hash_files = [];
            
            % is the current path already in the table
            if isempty(tab)
                
                % if not table was supplied, then the dataset definitely
                % needs adding
                needsAdding = true;
                
            else
                
                % a table exists so check the tracker guid against the
                % table
                idx_exist = strcmpi(tracker.GUID, tab.guid);
                if sum(idx_exist) == 1
                    % matches one, and only one GUID in the table. Check the
                    % hash to see if the session folder has changed
                    hash_tab = tab.hash{idx_exist};
                    hash_files = recmd5(tab.path_session{idx_exist});
                    changed = ~isequal(hash_tab, hash_files);

                    % if the files have changed, remove the entry from the
                    % table so that it will be recreated (as if it were a new
                    % datset) below
                    if changed
                        tab(idx_exist, :) = [];
                        needsAdding = true;
                    end

                elseif sum(idx_exist) > 1
                    % matches more than one. This should not be possible so
                    % throw and error
                    error('Duplicate GUID in table - this should not happen.')

                elseif ~any(idx_exist)
                    % was not found in the table, so needs adding to the table
                    needsAdding = true;

                end
                
            end
            
    % if the session needs adding to the table then extract its path,
    % guid and hash and add to the cell array
            
            if needsAdding
                
                % calculate the hash for the session files. This may
                % already have been calculated if comparing to the table in
                % the previous step. If so, save time by not recalculating
                if isempty(hash_files)
                    hash_files = recmd5(allFiles{f});
                end

                % find session path (one folder up from tracker)
                parts = strsplit(path_tracker, filesep);
                path_session = fullfile(filesep, parts{1:end - 1});
                
                % add to table
                idx_tab = size(tab, 1) + 1;
                tab.guid{idx_tab} = tracker.GUID;
                tab.path_session{idx_tab} = path_session;
                tab.hash{idx_tab} = hash_files;
                
%                 tab = [tab; cell2table([tracker.GUID, path_session, hash_files],...
%                     'VariableNames', {'guid', 'path_session', 'hash'})];
                
            end
            
        end
        
    end
    
%     % filter for sessions
%     guids = guids(is);
%     path_sessions = path_sessions(is);
%     hashes = hashes(is);
%     needs_proc = needs_proc(is);
%     
%     % put into table
%     tab.guid = guids;
%     tab.path_session = path_sessions;
%     tab.hash = hashes;
%     tab.needs_proc = needs_proc;

% find duplicate GUIDs, and put these into the dups table. We cannot
% deal with duplicates form this point forward, so they must be fixed
% before they're allowed in the table. We don't fix them here, we just
% return a list of them

    % get unique guids
    guid_u = unique(tab.guid);
    
    % tabulate guids, to count those with more than one entry
    tabu_guid = tabulate(tab.guid); 
    
    % sort the tabulate list of guids alphabetically, so that they match
    % the output of unique (stored in guid_u)
    [~, so] = sort(tabu_guid(:, 1));
    tabu_guid = tabu_guid(so, :);
    
    % get indices of unique guids with duplicates
    idx_dupGuid = cell2mat(tabu_guid(:, 2)) > 1;
    
    % get table indices of sessions with unique guids
    idx_dup = ismember(tab.guid, guid_u(idx_dupGuid));
    
    % store duplicate indices in the dups table
    dups = tab(idx_dup, :);
    
    % remove duplicates from the main table
    tab(idx_dup, :) = [];

end