function [suc, oc, data_joined, report] = teJoin(path_subject, varargin)

    % default output args in case of unknown error
    suc = false;
    oc = 'unknown error';
    data_joined = [];
    report = [];
    
    % handle input arguments in one of two ways, 1) if paths are passed,
    % attempt to load each one and fail if not valid session, or 2) if
    % variables are passed check that they are all valid teSessions
    [suc, oc, allSes] = teJoin_handleInputArgs(path_subject, varargin{:});
    if ~suc, return, end

    % for each dataset, load the tracker
    [suc, oc, allTrackers] = teJoin_loadAllTrackers(allSes{:});
    if ~suc, return, end
    
%     % this function detects resumed sessions, in which case earlier
%     % sessions will contain redundant data (in effect the session was
%     % joined
%     [isResumed, joinLog, joinEyetracking] =...
%         teJoin_detectResumedSession(allTrackers)
    
    % create a joined tracker, which will form the basis of the joined
    % dataset. The result has the start time of the earliest session being
    % joined, and the end time of the latest. The log is empty. The dynamic
    % variables are carried over but the paths are not. 
    tracker_joined = teJoin_createJoinedTracker(allTrackers{:});

    % log
    [suc, oc, tracker_joined] = teJoin_log(tracker_joined, allTrackers{:});

    % eye tracking - note we pass the teSessions here, because they already
    % have the eye tracking buffer loaded
    [suc, oc, tracker_joined, et_joined] = teJoin_et(tracker_joined, allSes{:});

    % enobio
    [suc, oc, enobio_joined, info_joined] = teJoin_enobio(allSes{:});
    
    % backup previous sessions
    [suc, oc] = teJoin_backupPreviousSessions(path_subject, allSes{:});
    if ~suc
        % report failure to backup
        oc = sprintf('Failed to backup previous sessions. No data was deleted and no data was written. Fix this error then try to join the sessions again. Error was:\n\%s',...
            oc);
        return
    end
    
    % write joined sessions
    [suc, oc] = teJoin_writeJoinedSessions(path_subject, tracker_joined,...
        et_joined, enobio_joined, info_joined);
    
end

function [suc, oc, data, numData] = teJoin_handleInputArgs(path_subject, varargin)

    teEcho('Processing input data...\n');

    suc = false;
    oc = 'unknown error';
    
    % first input argument is path_out
    
        % check that path_out is first input arg and a valid string 
        if ~exist('path_subject', 'var') || ~ischar(path_subject)
            suc = false;
            oc = 'First argument should be the output path as a char';
            return
        end

        % check that output path exists
        if ~exist(path_subject, 'dir')
            suc = false;
            oc = sprintf('Output path not found: %s', path_subject);
            return
        end
    
    % inputs can be teSession instances or paths to teData - determine
    % which
    
        if all(cellfun(@ischar, varargin))
            % all inputs are char
            data = teJoin_loadSessionFromPaths(varargin{:});
        elseif all(cellfun(@(x) isa(x, 'teSession'), varargin))
            % all inputs are teSession objects
            data = varargin;
        end

    % final check on the data format. Probably unnecessary but leave in for
    % now. todo - check this is still necessary
    if ~all(cellfun(@(x) isa(x, 'teSession'), data))
        
        % not all sessions are valid
        suc = false;
        oc = sprintf('At least one session was not valid.');
        return
        
    else
        
        % all sessions are valid, count them then return
        numData = length(data);
        suc = true;
        oc = '';
        
    end
        
end

function [suc, oc, data] = teJoin_loadSessionFromPaths(varargin)

    % check that all are valid paths to existing te sessions
    [is, reason] =...
        cellfun(@teIsSession, varargin, 'UniformOutput', false);
    
    if ~all(cell2mat(is))

        % report invalid 
        suc = false;
        oc = sprintf('At least one path was invalid:\n\n');
        oc = [oc, sprintf('\t%s | %s\n', varargin{~is}, reason{~is})];
        return

    else
            
        % attempt to load
        try
            
            data = cellfun(@teSession, varargin, 'UniformOutput', false);
            
        catch ERR
            
            % report any errors
            suc = false;
            oc = sprintf('Error loading at least one session:\n\n%s',...
                ERR.message);
            return

        end

    end
        
end

function [suc, oc, tracker] = teJoin_loadAllTrackers(varargin)
% loads all tracker files from datasets. Assumes that datasets are valid te
% sessions and have been loaded (ensured by calling teJoin_handleInputArgs
% before calling this function)
%
% 20230306 - this doesn't seem necessary since teSessions have a .Tracker
% property. For now, just return that but this could cause problems if
% ever for some reason the .Tracker field isn't populated. todo - check if
% this is still necessary.

    suc = true;
    oc = '';
    tracker = cellfun(@(x) x.Tracker, varargin, 'UniformOutput', false);
    
    return
    
%     teEcho('Loading trackers...\n');
% 
%     suc = false;
%     oc = 'unknown error';
%     data = varargin;
%     numData = length(data);
% 
%     % check that tracker files can be found
%     tracker = cell(numData, 1);
%     for d = 1:numData
%         
%         try
%             
%             % attempt to load
%             tmp = load(data{d}.Paths('tracker'));
%             
%             % check data
%             if ~isfield(tmp, 'tracker')
%                 suc = false;
%                 oc = 'Loaded tracker file but no tracker found';
%                 return
%             end
%             
%             if ~isa(tmp.tracker, 'teTracker')
%                 suc = false;
%                 oc = 'Invalid format of tracker file';
%             end
%             
%             tracker{d} = tmp.tracker;
%             
%         catch ERR
%             
%             suc = false;
%             oc = sprintf('Error loading tracker: %s', ERR.message);
%             return
%             
%         end
%         
%     end
%     
%     suc = true;
%     oc = '';
    
end

% function [isResumed, joinLog, joinEyetracking] =...
%     teJoin_detectResumedSession(allTrackers)
% 
%     suc = false;
%     oc = 'unknown error';
%     isResumed = false;
%     joinLog = true;
%     joinEyetracking = true;
%     
%     % each session can be resumed or not resumed. We can join sessions in
%     % two ways:
%     %
%     %   [not resumed] <-> [resumed]
%     %   [resumed]     <-> [resumed]
%     %
%     % But we cannot join:
%     %
%     %   [resumed]     <-> [not resumed]
%     %
%     % Therefore we need to detect a valid pattern (as per the first
%     % example) of resumed flags. 
%     
%         resumeFlags = cellfun(@(x) x.Resuming, allTrackers);
%         
%         % the only valid location for a 'not resumed' flag is the first
%         % element -- the rest need to be 'resumed'
%         if ~resumeFlags(1) && all(resumeFlags(2:end))
%             isResumed = false;
%             return
%         end
%         
%     % now we have a pattern of sessions that were resumed, we can
%     % potentially skip joining the log and the eye tracking. We need to
%     % ensure
%     
%     
% 
%     suc = true;
%     oc = '';
% 
% end

function tracker_joined = teJoin_createJoinedTracker(varargin)

    allTrackers = varargin;

    % sort trackers by session start time
    startTimes = cellfun(@(x) x.SessionStartTime, allTrackers);
    [~, so] = sort(startTimes);
    allTrackers = allTrackers(so);

    % base the joined data on the first tracker in the list
    tracker_joined = copyHandleClass(allTrackers{1});

    % update end time
    endTimes = cellfun(@(x) x.SessionEndTime, allTrackers);
    idx_last = find(~isnan(endTimes) & endTimes == min(endTimes), 1);
    tracker_joined.SessionEndTime = endTimes(idx_last);    
    
    % clear path properties
    tracker_joined.Path_Diary = [];
    tracker_joined.Path_Session = [];
    tracker_joined.Path_Diary = [];
    tracker_joined.Path_Tracker = [];
    tracker_joined.Path_EyeTracker = [];
    
    % clear log
    tracker_joined.ClearLog;
            
end

function [suc, oc, tracker_joined] = teJoin_log(tracker_joined, varargin)
% takes an output tracker (tracker_joined) and all input trackers, and
% combines the logs from each into the output tracker. Logs are combined by
% finding the temporal extent of each the log in each tracker, and
% calculating where there is overlap. Where there isn't overlap,
% non-overlapping log entries are copied to the joined tracker. 

    teEcho('Joining log data...\n');

    suc = false;
    oc = 'unknown error';
    allTrackers = varargin;
    numData = length(allTrackers);
    
% find temporal extent of all tracker logs

    t_ext = nan(numData, 2);
    for d = 1:numData
        
        % sort log entries
        la = teSortLog(allTrackers{d}.Log);
        
        % find temporal extent
        t_ext(d, 1) = la{1}.timestamp;
        t_ext(d, 2) = la{end}.timestamp;
        
    end
    
% find log duration and sort in descending order

    dur_ext = t_ext(:, 2) - t_ext(:, 1);
    [~, so] = sort(t_ext(:, 2), 'descend');
    allTrackers = allTrackers(so);
    t_ext = t_ext(so, :);
    dur_ext = dur_ext(so);
    
% loop through trackers and copy to joined tracker, if extents DON'T
% overlap 

    for d = 1:numData
        
        if d == 1
            
            % this is the master tracker with the longest log. Do a
            % straight copy, regardless of extent
            tracker_joined.Log = allTrackers{d}.Log;
            
        else
            
            % get log timestamps
            ts = cellfun(@(x) x.timestamp, allTrackers{d}.Log);
            
            % find entries that don't overlap with the master log (i.e.
            % they come before the start of the master, or after the end)
            idx_before = ts < t_ext(1, 1);
            idx_after = ts > t_ext(1, 2);
            
            % if any logs need to be appended, prepare them and insert
            % boundary events
            if any(idx_before)
                
                % create boundary event, and cat to END of to-be-copied log
                li_boundary = struct('timestamp', ts(find(idx_before,1 , 'last')),...
                    'topic', 'join_boundary',...
                    'source', 'teJoin_log',...
                    'ses_before', allTrackers{d}.Path_Session,...
                    'ses_after', allTrackers{1}.Path_Session);
                
                % join all elements of the log that are needed on to the
                % boundary event
                la_before = [allTrackers{d}.Log(idx_before); {li_boundary}];
                
                % join
                allTrackers{1}.Log = [la_before; allTrackers{1}.Log];
                
            end
            
            % if any logs need to be appended, prepare them and insert
            % boundary events
            if any(idx_after)
                
                % create boundary event, and cat to END of to-be-copied log
                li_boundary = struct('timestamp', ts(find(idx_after, 1)),...
                    'topic', 'join_boundary',...
                    'source', 'teJoin_log',...
                    'ses_before', allTrackers{1}.Path_Session,...
                    'ses_after', allTrackers{d}.Path_Session);
                
                % join all elements of the log that are needed on to the
                % boundary event
                la_after = [{li_boundary}; allTrackers{d}.Log(idx_after)];
                
                % join
                allTrackers{1}.Log = [allTrackers{1}.Log; la_after];
                
            end            
            
            % re-sort master, and calculate new extents
            allTrackers{1}.Log = teSortLog(allTrackers{1}.Log);

            % find temporal extent
            t_ext(1, 1) = allTrackers{1}.Log{1}.timestamp;
            t_ext(1, 2) = allTrackers{1}.Log{end}.timestamp;
        
        end
        
    end
    
    tracker_joined.Log = allTrackers{1}.Log;
    
    suc = true;
    oc = '';

end

function [suc, oc, tracker_joined, et_joined] = teJoin_et(tracker_joined, varargin)
% takes an output tracker (tracker_joined) and all input trackers, and
% combines the eye tracking data from. 

    teEcho('Joining eye tracking data...\n');

    suc = false;
    oc = 'unknown error';
    et_joined = [];
    allTrackers = varargin;
    numData = length(allTrackers);
    
% examine eye tracking data for each session, and extract buffers

    buf = cell(numData, 1);
    sr = nan(numData, 1);
    hasET = false(numData, 1);
    t_ext = nan(numData, 2);
    for d = 1:numData
        
        ext = allTrackers{d}.ExternalData('eyetracking');
        hasET(d) = ~isempty(ext);
        if ~hasET(d)
            % no eye tracking data
            warning('Dataset %d had not eye tracking data - needs debugging', d)
            continue
        end
        
        % get buffer and sampling rate
        buf{d} = ext.Buffer;
        sr(d) = ext.TargetSampleRate;
        
        % get temporal extent
        t_ext(d, 1) = ext.Buffer(1, 1);
        t_ext(d, 2) = ext.Buffer(end, 1);
        
    end
    
    % fail if sampling rates don't match
    if ~all(arrayfun(@(x) isequal(x, sr(1)), sr(2:end)))
        suc = false;
        oc = 'Mismatched sample rates';
        return
    end
    
    tab = table;
    tab.hasET = hasET;
    tab.buf = buf;
    tab.sr = sr;
    tab.t_ext = t_ext;
    
% remove sessions with no eye tracking data

    tab(~hasET, :) = [];
    allTrackers(~hasET) = [];
    numData = length(allTrackers);
        
% find et end time and sort in descending order

    tab.dur_ext = tab.t_ext(:, 2) - tab.t_ext(:, 1);
    [~, so] = sort(tab.t_ext(:, 2), 'descend');
    tab = tab(so, :);
    allTrackers = allTrackers(so);
    
% loop through trackers and copy to joined tracker, if extents DON'T
% overlap 
   
    for d = 2:numData
           
        % get log timestamps
        ts = tab.buf{d}(:, 1);

        % find entries that don't overlap with the master log (i.e.
        % they come before the start of the master, or after the end)
        idx_before = ts < tab.t_ext(1, 1);
        idx_after = ts > tab.t_ext(1, 2);

        % if any logs need to be appended, prepare them and insert
        % boundary events
        if any(idx_before)

            % create boundary event, and cat to joined tracker log
            li_boundary = struct('timestamp', ts(find(idx_before, 1, 'last')),...
                'topic', 'join_boundary',...
                'source', 'teJoin_et',...
                'ses_before', allTrackers{d}.Paths('session'),...
                'ses_after', allTrackers{1}.Paths('session'));
            tracker_joined.Log{end + 1} = li_boundary;

            % append to master buffer
            tab.buf{1} = [tab.buf{d}(idx_before, :); tab.buf{1}];

        end

        % if any logs need to be appended, prepare them and insert
        % boundary events
        if any(idx_after)

            % create boundary event, and cat to END of to-be-copied log
            li_boundary = struct('timestamp', ts(find(idx_after, 1)),...
                'topic', 'join_boundary',...
                'source', 'teJoin_et',...
                'ses_before', allTrackers{1}.Paths('session'),...
                'ses_after', allTrackers{d}.Paths('session'));
            tracker_joined.Log{end + 1} = li_boundary;

            % append to master buffer
            tab.buf{1} = [tab.buf{1}; tab.buf{d}(idx_after, :)];
            
        end            

        % re-sort master, and calculate new extents
        tab.buf{1} = sortrows(tab.buf{1}, 1);

        % find temporal extent
        tab.t_ext(1, 1) = tab.buf{1}(1, 1);
        tab.t_ext(1, 2) = tab.buf{1}(end, 1);
        
    end
    
    % sort joined tracker log (ensures any boundary events we added are in
    % order)
    tracker_joined.Log = teSortLog(tracker_joined.Log);
    
% create joined eye tracking data

    ext = allTrackers{1}.ExternalData('eyetracking');
    et_joined = struct;
    et_joined.Calibration = ext.Calibration;
    et_joined.Buffer = tab.buf{1};
    et_joined.Notepad = ext.Notepad;
    et_joined.SampleRate = ext.TargetSampleRate;
    et_joined.AOIs = [];
    et_joined.TrackerType = [];
    
    % store calibration and notepad from pre-joined sessions
    for d = 2:numData
        ext = allTrackers{d}.ExternalData('eyetracking');
        if ~isempty(ext.Calibration)
            et_joined.PreJoin.Calibration(d - 1) = ext.Calibration;
            et_joined.PreJoin.Notepad(d - 1) = ext.Notepad; 
        end
    end
    
    suc = true;
    oc = '';

end

function [suc, oc, enobio_joined, info_joined] = teJoin_enobio(varargin)
% takes an array of sessions and finds all of those with enobio external
% data. Passes the filenames of all files to the eegEnobio_Join function
% (part of the 'eegtools' package) to join all enobio .easy and .info files
% and return them. By default, eegEnobio_join will also write the data, but
% we do this later. 

    teEcho('Joining enobio data...\n');

    suc = false;
    oc = 'unknown error';
    enobio_joined = [];
    info_joined = [];
    allSes = varargin;
    numData = length(allSes);
    
    % examine all sessions and figure out which can be joined. This means
    % that a) they have enobio data, b) the .easy and .info files are in
    % the ExternalData .Paths collection, and c) those paths exist 
    tab = table;
    tab.file_easy = cell(numData, 1);
    tab.file_info = cell(numData, 1);
    tab.canBeJoined = true(numData, 1);
    for d = 1:numData
        
        % check that this session has enobio data
        
            ext = allSes{d}.ExternalData('enobio');
            hasEEG(d) = ~isempty(ext);
            if ~hasEEG(d)
                % no enobio data
                warning('Dataset %d had no enobio data', d)
                tab.canBeJoined(d) = false;
                continue
            end
        
        % get paths to .easy and .info files
        
            % easy
            file_easy = ext.Paths('enobio_easy');
            if ~isempty(file_easy) && exist(file_easy, 'file')
                tab.file_easy{d} = file_easy;
            else
                tab.canBeJoined(d) = false;
                continue
            end

            % info    
            file_info = ext.Paths('enobio_info');        
            if ~isempty(file_info) && exist(file_info, 'file')
                tab.file_info{d} = file_info;
            else
                tab.canBeJoined(d) = false;
                continue
            end
                    
    end
    
    % remove any sessions that don't have join-able data, and deal with the
    % results
    
        tab(~tab.canBeJoined, :) = [];
        
        % if there are no joinable sessions at all, give up
        if isempty(tab)
            suc = false;
            oc = 'no join-able enobio data found in any sessions';
            return
        end
        
        % if there is only one joinable session, return it
        if height(tab) == 1
            
            % load the data from the one session
            enobio_joined = load(tab.file_easy{1});
            info_joined = fileread(tab.file_info{1});
            
            suc = false;
            oc = 'only one valid enobio session found, returning that';
            return
            
        end
        
        % if there are >1 join-able sessions, join them
        [suc, oc, enobio_joined, info_joined] =...
            eegEnobio_join([], tab.file_easy{:});
        
end
            

function [suc, oc] = teJoin_backupPreviousSessions(path_subject, varargin)
% rename existing sessions with .precombine (so that we can ignore them in
% future)

    data = varargin;
    
    % get all session paths
    path_ses = cellfun(@(x) x.Paths('session'), data, 'UniformOutput',...
        false);
    
    % check that session paths exist
    for d = 1:length(data)
        if ~exist(path_ses{d}, 'dir')
            suc = false;
            oc = sprintf('Session path not found: %s', path_ses{d});
            return
        end
    end
    
    % check that subject folder (output path) exists
    if ~exist(path_subject, 'dir')
        suc = false;
        oc = sprintf('Output path (subject folder) not found: %s',...
            path_subject);
        return
    end
    
%     % zip
%     file_zip = fullfile(path_subject, sprintf('precombine_%s.zip',...
%         data{1}.GUID));
%     zip(file_zip, path_ses)
%     
%     % verify zip file exists
%     if ~exist(file_zip, 'file')
%         suc = false;
%         oc = 'Zip file written but could not be verified';
%         return
%     end
    
    % delete old sessions
    for d = 1:length(data)
        try
            file_rn = sprintf('%s.precombine', path_ses{d});
            [rn_suc, rn_msg] = movefile(path_ses{d}, file_rn);
            if ~rn_suc
                suc = false;
                oc = sprintf('Error renaming old sessions: %s', rn_msg);
                return
            end
        catch ERR
            suc = false;
            oc = sprintf('Error renaming old sessions: %s', ERR.message);
        end
    end
    
    suc = true;
    oc = '';
        
end
    
function [suc, oc] = teJoin_writeJoinedSessions(path_subject, tracker,...
    eyetracker, enobio_easy, enobio_info)
   
    % create session folder
    path_ses = fullfile(path_subject, datestr(tracker.CreationTime, 30));
    try
        [suc_mkdir, msg_mkdir] = mkdir(path_ses);
        if ~suc_mkdir
            suc = false;
            oc = sprintf('Error making dir for joined session: %s', msg_mkdir);
            return
        end
    catch ERR
        suc = false;
        oc = sprintf('Error making dir for joined session: %s', ERR.message);
        return
    end
    
    % make paths
    tags            = tracker.MakeTags;
    file_tracker    = fullfile(path_ses, sprintf('tracker%s.mat', tags));
    path_enobio     = fullfile(path_ses, 'enobio');
    file_easy       = fullfile(path_enobio, sprintf('combined%s.easy', tags));
    file_info       = fullfile(path_enobio, sprintf('combined%s.info', tags));
    path_et         = fullfile(path_ses, 'eyetracking');
    file_et         = fullfile(path_et, sprintf('eyetracking%s.mat', tags));
    
    suc = true;
    
    % tracker
    teEcho('Saving tracker to: %s\n', file_tracker);
    save(file_tracker, 'tracker');
    suc = suc & teJoin_verify(file_tracker);
    if ~suc, return, end
    
    % eye tracking
    if ~isempty(eyetracker)
        teEcho('Saving eye tracking to: %s\n', path_et);
        [suc, oc] = teJoin_mkdir(path_et);
        if ~suc, return, end
        save(file_et, 'eyetracker');
        suc = suc & teJoin_verify(file_et);
        if ~suc, return, end
    end
    
    % enobio
    if ~isempty(enobio_easy) && ~isempty(enobio_info)
        
        teEcho('Saving enobio to: %s\n', file_easy);

        [suc, oc] = teJoin_mkdir(path_enobio);
        if ~suc, return, end

        % info
        fid = fopen(file_info, 'w+');
        fprintf(fid, '%s', enobio_info);
        fclose(fid);

        % easy
        writetable(array2table(enobio_easy), file_easy,...
            'WriteVariableNames', false, 'FileType', 'text')

        suc = suc & teJoin_verify(file_easy);
        if ~suc, return, end
        suc = suc & teJoin_verify(file_info);
        if ~suc, return, end
    
    end

end

function [suc, oc] = teJoin_mkdir(path_dir)

    try
        [suc, msg] = mkdir(path_dir);
        if ~suc
            oc = sprintf('Error making dir (%s): %s', path_dir, msg);
            return
        end
    catch ERR
        oc = sprintf('Error making dir (%s): %s', path_dir, ERR.message);
        return
    end
    
    if exist(path_dir, 'dir')
        suc = true;
        oc = '';
    else
        suc = false;
        oc = sprintf('Verification failed after mkdir on %s', path_dir);
    end
    
end

function [suc, oc] = teJoin_verify(file)

    suc = exist(file, 'file');
    if ~suc
        oc = sprintf('Verification failed for: %s', file);
    else
        oc = '';
    end
    
end

    
    
%     data = varargin;
%     numData = length(data);
%     
% % examine enobio data for each session, and extract buffers
% 
%     dat = cell(numData, 1);
%     inf = cell(numData, 1);
%     sr = nan(numData, 1);
%     hasEEG = false(numData, 1);
%     t_ext = nan(numData, 2);
%     for d = 1:numData
%         
%         ext = data{d}.ExternalData('enobio');
%         hasEEG(d) = ~isempty(ext);
%         if ~hasEEG(d)
%             % no enobio data
%             warning('Dataset %d had no enobio data', d)
%             continue
%         end
%         
%         % load
%         file_easy = ext.Paths('enobio_easy');
%         if isempty(file_easy)
%             suc = false;
%             oc = 'Enobio easy file not found in external data Paths collection';
%             return
%         elseif ~exist(file_easy, 'file')
%             suc = false;
%             oc = sprintf('File not found: %s', file_easy);
%             return
%         end
%         try
%             dat{d} = load(file_easy);
%         catch ERR
%             suc = false;
%             oc = sprintf('Error reading enobio data: %s', ERR.message);
%             return
%         end
%         
%         file_info = ext.Paths('enobio_info');
%         if isempty(file_info)
%             suc = false;
%             oc = 'Enobio info file not found in external data Paths collection';
%             return
%         elseif ~exist(file_info, 'file')
%             suc = false;
%             oc = sprintf('File not found: %s', file_info);
%             return
%         end
%         try
%             inf{d} = fileread(file_info);
%         catch ERR
%             suc = false;
%             oc = sprintf('Error reading enobio data: %s', ERR.message);
%             return
%         end
%         
%         % get buffer and sampling rate
%         try
%             loc1 = strfind(inf{d}, 'EEG sampling rate: ');
%             loc2 = strfind(inf{d}, 'Samples/second');
%             parts = strsplit(inf{d}(loc1(1):loc2(1) - 2), ': ');
%             sr(d) = str2num(parts{2});
%         catch ERR
%             suc = false;
%             oc = sprintf('Error searching info file for sample rate: %s',...
%                 ERR.message);
%             return
%         end
%         
%         % get temporal extent
%         t_ext(d, 1) = dat{d}(1, end);
%         t_ext(d, 2) = dat{d}(end, end);
%         
%     end
% 
%     tab = table;
%     tab.hasEEG = hasEEG;
%     tab.dat = dat;
%     tab.sr = sr;
%     tab.t_ext = t_ext;
%     tab.originalFirstSample = t_ext(:, 1);
%     tab.originalLength = cellfun(@(x) size(x, 1), dat);
%     tab.inf = inf;
%     
% % remove sessions with no EEG data
% 
%     tab(~hasEEG, :) = [];
%     data(~hasEEG) = [];
%     numData = length(data);
%     if numData == 0
%         oc = 'No enobio data';
%         enobio_joined = [];
%         return
%     elseif numData == 1
%         % after searching through all external data, there is only one EEG
%         % dataset. Obv this doesn't need joining, so just return that
%         % session
%         enobio_joined = tab.dat{1};
%         info_joined = tab.inf{1};
%         suc = true;
%         oc = 'Only one enobio dataset was present, using this';
%         return
%     end
%     
%     % fail if sampling rates don't match
%     if ~all(arrayfun(@(x) isequal(x, tab.sr(1)), tab.sr(2:end)))
%         suc = false;
%         oc = 'Mismatched sample rates';
%         return
%     end
%     
% % find et end time and sort in descending order
% 
%     tab.dur_ext = tab.t_ext(:, 2) - tab.t_ext(:, 1);
%     [~, so] = sort(tab.t_ext(:, 2), 'descend');
%     tab = tab(so, :);
%     data = data(so);
%     
% % loop through trackers and copy to joined tracker, if extents DON'T
% % overlap 
%    
%     for d = 2:numData
%            
%         % get log timestamps
%         ts = tab.dat{d}(:, end);
% 
%         % find entries that don't overlap with the master log (i.e.
%         % they come before the start of the master, or after the end)
%         idx_before = ts < tab.t_ext(1, 1);
%         idx_after = ts > tab.t_ext(1, 2);
% 
%         % if any logs need to be appended, prepare them and insert
%         % boundary events
%         if any(idx_before)
% 
%             % create boundary event, and cat to joined tracker log
%             tab.dat{d}(find(idx_before, 1, 'last'), end - 1) = 32767;
% 
%             % append to master buffer
%             tab.dat{1} = [tab.dat{d}(idx_before, :); tab.dat{1}];
% 
%         end
% 
%         % if any logs need to be appended, prepare them and insert
%         % boundary events
%         if any(idx_after)
% 
%             % create boundary event, and cat to END of to-be-copied log
%             tab.dat{d}(find(idx_after, 1, 'first'), end - 1) = 32767;
% 
%             % append to master buffer
%             tab.dat{1} = [tab.dat{1}; tab.dat{d}(idx_after, :)];
%             
%         end            
% 
%         % re-sort master, and calculate new extents
%         tab.dat{1} = sortrows(tab.dat{1}, size(tab.dat{1}, 2));
% 
%         % find temporal extent
%         tab.t_ext(1, 1) = tab.dat{1}(1, end);
%         tab.t_ext(1, 2) = tab.dat{1}(end, end);
%         
%     end
%     
% % edit info file
% 
%     % replace first sample timestamp
%     info_joined = tab.inf{1};
%     info_joined = strrep(info_joined, num2str(tab.originalFirstSample(1)),...
%         num2str(tab.dat{1}(1, end)));
%     info_joined = strrep(info_joined, num2str(tab.originalLength(1)),...
%         num2str(size(tab.dat{1}, 1)));    
%     
% % create joined eye tracking data
% 
%    enobio_joined = tab.dat{1};
%    
%     suc = true;
%     oc = '';


