function [is, reason, file_tracker, tracker] =...
    teIsSession(path_session, varargin)
% checkes that a passed path is a) a folder, and b) contains a valid
% teTracker file

    is = false;
    reason = 'unknown error';
    file_tracker = [];
    tracker = [];
    
    % default behaviour is to ignore any sessions with '.precombine' in the
    % folder name. These are split sessions that have been combined with
    % teJoin, and should not be considered valid data. This can be
    % overriden with the '-includePreCombine' switch
    includePrecombine = ismember('-includePrecombine', varargin);

    % if path_session is a cellstr containing multiple files, recursively
    % call this function with each element 
    if iscellstr(path_session)
        num = length(path_session);
        is = false(num, 1);
        reason = cell(num, 1);
        file_tracker = cell(num, 1);
        tracker = cell(num, 1);
        for i = 1:num
            [is(i), reason{i}, file_tracker{i}, tracker{i}] =...
                teIsSession(path_session{i}, varargin{:});
        end
        return
    end

    % check for valid folder
    validFolder = exist(path_session, 'dir');
    if ~validFolder
        is = false;
        reason = 'not folder';
        return
    end
    
    % optionally exclude .precombine folders
    if contains(path_session, '.precombine') && ~includePrecombine
        is = false;
        reason = 'precombine';
        return
    end
     
    % search for tracker file
    file_tracker = teFindFile(path_session, '*tracker*.mat');
    if isempty(file_tracker)
        is = false;
        reason = 'tracker file not found';
        return
    elseif iscell(file_tracker) && length(file_tracker) > 1
        is = false;
        reason = 'multiple tracker files found';
        return
    end
    
    % load tracker and check contents
    try
        tmp = load(file_tracker);
        tracker = tmp.tracker;
        % if tracker is serialised (as a result of a fast save),
        % deserialize it
        if isa(tracker, 'uint8')
            try
                tracker = getArrayFromByteStream(tracker);
            catch ERR_deserialise
                error('Error whilst attempting to deserialise the tracker. Error was:\n\n%s',...
                    ERR_deserialise.message)
            end
        end
        
    catch ERR_load
        is = false;
        reason = ERR_load.message;
        tracker = [];
        return
        
    end
    
    % check data type
    if ~isa(tracker, 'teTracker')
        is = false;
        reason = 'file is not of class teTracker';
        return
    end
    
    % check contents
    if ~isprop(tracker, 'GUID') 
        is = false;
        reason = 'missing property: GUID';
        return
        
    elseif ~isprop(tracker, 'Log')
        is = false;
        reason = 'missing property: Log';
        return
        
    end
    
    % everything is OK
    is = true;
    reason = [];
    
end
    