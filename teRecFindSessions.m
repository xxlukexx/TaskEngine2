function [paths_sessions, trackers, vars, ext, md, ses] = teRecFindSessions(path_data, varargin)
% Recursively finds sessions in a folder tree. Returns the path to all
% discovered sessions, as well as the contents of the tracker. 

    paths_sessions = [];
    trackers = [];
    vars = [];
    ext = [];
    md = [];
    ses = [];

    % rec find all files
    allFiles = recdir(path_data, '-silent');
    
    % add current path to allFiles in case it is itself a session
    allFiles{end + 1} = path_data;
    numFiles = length(allFiles);
    stat = cmdStatus(sprintf('Finding valid sessions...\n'));
    
    % find valid te sessions
    is = false(numFiles, 1);
    trackers = cell(numFiles, 1);
    ext = cell(numFiles, 1);
    md = cell(numFiles, 1);
    ses = cell(numFiles, 1);
    if nargout == 6
        createTeSession = true;
    else
        createTeSession = false;
    end
    parfor f = 1:numFiles
        [is(f), ~, ~, trackers{f}] = teIsSession(allFiles{f});
        if is(f)
            % read external data
            ext{f} = teDiscoverExternalData(allFiles{f});
            % read metadata
            md{f} = teReadMetadataFromSessionFolder(allFiles{f},...
                trackers{f}, ext{f});
            % make teSession
            if createTeSession
                ses{f} = teSession('tracker', trackers{f});
                ses{f}.ExternalData = ext{f};
                ses{f}.Metadata = md{f};
                ses{f}.Paths('session') = allFiles{f};
            end
        end
        if mod(f, 30) == 0
            fprintf('Finding valid sessions (%.1f%%)...\n',...
                (f / numFiles) * 100);
%             stat.Status = sprintf('Finding valid sessions (%.1f%%)...',...
%                 (f / numFiles) * 100);
        end
    end
    
    % filter for valid sessions   
    if ~any(is)
        return
    end
    
    paths_sessions = allFiles(is);
    trackers = trackers(is);
    ext = ext(is);
    md = md(is);
    ses = ses(is);
    teEcho('%d sessions found.\n', sum(is));
    
    % return vars in a table
    [~, ~, s] = cellfun(@(x) x.GetVariables, trackers, 'UniformOutput', false);
    vars = teLogExtract(s);
    
    % add GUID to table
    vars.GUID = cellfun(@(x) x.GUID, trackers, 'UniformOutput', false);
    
    % add session start time
    idx_valid = cellfun(@(x) ~isnan(x.SessionStartTime), trackers);
    vars.SessionStart = repmat({'invalid'}, size(vars, 1), 1);
    vars.SessionStart(idx_valid) =...
        cellfun(@(x) datestr(x.SessionStartTime, 'ddd mmm yyyy HH:MM:SS'),...
        trackers(idx_valid), 'UniformOutput', false);
    
    % calculate duration
%     dur = cellfun(@(x) x.SessionEndTime - x.SessionStartTime, trackers);
    dur = cellfun(@teCalculateSessionDuration, trackers);
    idx_valid = ~isnan(dur);
    vars.Duration = repmat({'invalid'}, size(vars, 1), 1);
    vars.Duration(idx_valid) = arrayfun(@(x) datestr(x, 'HH:MM:SS'),...
        dur(idx_valid), 'uniform', false);
    
end