classdef teJoin < handle
    
    properties
    end
    
    properties (SetAccess = private)
        Trackers
    end
    
    properties (Dependent, SetAccess = private)
        Path_Sessions
    end
    
    methods
        
        function obj = teJoin(varargin)
        % Instantiates the class, taking a cellstr array of session paths.
        % Checks these session paths are valid, and if they are adds each
        % to the class for joining later on.
            
        % init trackers collection
        
            obj.Trackers = teCollection('teTracker');
            
        % check inputs

            if ~iscellstr(varargin)
                error('Must pass paths to each session in a cell array.')
            end

            if ~all(cellfun(@teIsSession, varargin))
                error('All paths must be to valid sessions.')
            end            

        % add sessions to collection
        
            numSes = length(varargin);
            for s = 1:numSes
                [suc, oc] = obj.AddSession(varargin{s});
            end
            
        end
        
        function [suc, oc] = AddSession(obj, path_ses)
        % Attemps to load and store a teTracker for each session path
        
            suc = false;
            oc = 'unknown error';

        % load session

            % find tracker
            file_tracker = teFindFile(path_ses, 'tracker*.mat');
            if isempty(file_tracker)
                suc = false;
                oc = sprintf('Could not find tracker.mat in session: %s',...
                    path_ses);
                return
            elseif iscell(file_tracker) && length(file_tracker) > 1
                suc = false;
                oc = sprintf('Multiple trackers returned for session: %s',...
                    path_ses);
                return
            elseif iscell(file_tracker) && length(file_tracker) == 1 &&...
                    ischar(file_tracker{1})
                % extract scalar path from cell array
                file_tracker = file_tracker{1};
            end

            % attempt to load
            try
                tmp = load(file_tracker);
            catch ERR
                suc = false;
                oc = sprintf('Error loading tracker: %s', ERR.message);
                return
            end
            if ~isfield(tmp, 'tracker') || ~isa(tmp.tracker, 'teTracker')
                suc = false;
                oc = sprintf('Tracker not valid in session: %s', path_ses);
                return
            else
                % store tracker
                obj.Trackers(path_ses) = tmp.tracker;
            end

        end
        
        function [suc, oc] = Join(obj, path_out)
            
            if ~exist(path_out, 'dir') 
                error('Output path not found.')
            end
            
        % setup
        
            % sort trackers by session start time
            startTimes = arrayfun(@(x) x.SessionStartTime, obj.Trackers);
            [~, so] = sort(startTimes);
            obj.Trackers.SortByIndex(so);

            % base the joined data on the first tracker in the list
            joined = copyHandleClass(obj.Trackers(1));

            % update end time
            endTimes = arrayfun(@(x) x.SessionEndTime, obj.Trackers);
            idx_last = find(endTimes == min(endTimes), 1);
            joined.SessionEndTime = endTimes(idx_last);            

        % join log
        
            % sort all logs and find extent (first/last timestamp)
            numTrackers = obj.Trackers.Count;
            ts = cell(numTrackers, 1);
            for t = 1:numTrackers
                
                % sort log array
                obj.Trackers(t).ReplaceLog(teSortLog(obj.Trackers(t).Log));
                
                % get timestamps 
                ts{t} = cellfun(@(x) x.timestamp, obj.Trackers(t).Log);
                                   
                if t == 1
                    
                    % this is the master (from the output tracker) log that
                    % we'll edit/append 
                    lg = joined.Log;
                    
                elseif t > 1
                    
                    % append appropriate portions of each additional log to the
                    % joined (output) log. Do this by only copying those
                    % portions of the additional logs that don't overlap 
                    idx1 = ts{t} < ts{1}(1);        % log entries BEFORE
                    idx2 = ts{t} > ts{1}(end);      % log entries AFTER
                    
                    if any(idx1)
                        % append BEFORE
                        lg = [obj.Trackers(t).Log(idx1); lg];
                    end
                    
                    if any(idx2)
                        % append AFTER
                        lg = [lg; obj.Trackers(t).Log(idx2)];
                    end
                    
                end
                
            end
            
            % update joined log
            joined.Log = lg;
                    
       
                    
                    
                    
            
            
            
            
            
            
        end
        
        % get / set
        function val = get.Path_Sessions(obj)
        % The keys in the teCollection that holds teTrackers are the
        % session paths, so we just return these
        
            val = obj.Trackers.Keys;
            
        end

    end
    
end


% function [suc, oc] = teJoin(varargin)
% % Joins multiple Task Engine sessions, and writes one new joined session.
% % Will also join external data found in each session. 
% 
% 
%         
% % join trackers (including log)
% 
%     % sort trackers by session start time
%     startTimes = cellfun(@(x) x.SessionStartTime, tracker);
%     [~, so] = sort(startTimes);
%     tracker = tracker(so);
% 
%     % base the joined data on the first tracker in the list
%     joined = copyHandleClass(tracker{1});
%     
%     % find end time of last tracker that has a valid SessionEndTime (i.e.
%     % not NaN)
%     endTimes = cellfun(@(x) x.SessionEndTime, tracker);
%     idx_last = find(endTimes == min(endTimes), 1);
%     joined.SessionEndTime = endTimes(idx_last);
% 
%     
%   
% 
%     
% 
% 
% 
% 
% 
% end
