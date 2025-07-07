classdef teLog < handle
    
    properties
        LogArray 
    end
    
    properties (Dependent, SetAccess = private)
        Tasks
        TaskTrialSummary
        LogTable
        Events
        Sources
        Topics
        TrialGUIDs
        TrialGUIDTable
    end
    
    properties (Access = private)
        prLogTable
        prTasks
        prSources
        prTopics
        prTaskTrialSummary
        prEvents
        prTrialGUIDTable
    end
    
    methods
        
        function obj = teLog(logArray)
        % this class must be instantiated with a log array (a cell array of
        % structs). Doing this sets the .LogArray property (but an empty -
        % uninstantiated - object is not allowed)
        
            % check for no input args
            if nargin == 0
                error('Must instantiate this class by passing a log array to it.')
            end
            if isempty(logArray)
                return
            end
            
            % check format of log array
            if iscell(logArray) && all(cellfun(@isstruct, logArray))
                obj.LogArray = logArray;
            else
                error('Input argument was not a log array (cell array of structs).')
            end
            
        end
        
        function ClearCache(obj)
            obj.prLogTable = [];
            obj.prTasks = [];
            obj.prTaskTrialSummary = [];
            obj.prEvents = [];
            obj.prTrialGUIDTable = [];
            obj.prSources = [];
            obj.prTopics = [];
        end
        
    % get/ set
    
        function set.LogArray(obj, val)
        % when the .LogArray property is changed, we may need to recalc
        % certan cached data such as LogTable
            
            % if nothing changed, give up
            if isequal(obj.LogArray, val)
                return
            end
            
            obj.LogArray = val;
            
            % clear cache properties
            obj.ClearCache;
            
        end
    
        function val = get.LogTable(obj)
            % if no log data, return empty
            if isempty(obj.LogArray), val = []; return, end
            % check if cached
            if isempty(obj.prLogTable)
%                 fprintf('Processing log array...\n');
                % make table
                obj.prLogTable = teLogExtract(obj.LogArray);
            end
            % return value
            val = obj.prLogTable;
        end
        
        function val = get.Tasks(obj)
            % if no log data, return empty
            if isempty(obj.LogArray), val = []; return, end     
            % update cache if necessary
            if isempty(obj.prTasks)
                % get log table
                tab = obj.LogTable;
                % check that there is at least one log entry with a 'task'
                % field
                if ~ismember('task', tab.Properties.VariableNames)
                    val = [];
                    return
                end
                % find empties
                empty = cellfun(@isempty, tab.task);
                tab(empty, :) = [];
                % return unique task labels
                obj.prTasks = unique(tab.task);            
            end
            val = obj.prTasks;
        end
        
        function val = get.Sources(obj)
            % if no log data, return empty
            if isempty(obj.LogArray), val = []; return, end     
            % update cache if necessary
            if isempty(obj.prSources)
                % get log table
                tab = obj.LogTable;  
                % find empties
                empty = cellfun(@isempty, tab.source);
                tab(empty, :) = [];
                % return unique task labels
                obj.prSources = unique(tab.source);            
            end
            val = obj.prSources;                
        end
        
        function val = get.Topics(obj)
            % if no log data, return empty
            if isempty(obj.LogArray), val = []; return, end     
            % update cache if necessary
            if isempty(obj.prTopics)
                % get log table
                tab = obj.LogTable;  
                % find empties
                empty = cellfun(@isempty, tab.topic);
                tab(empty, :) = [];
                % return unique task labels
                obj.prTopics = unique(tab.topic);            
            end
            val = obj.prTopics;               
        end
        
        function val = get.TaskTrialSummary(obj)
            % if no log data, return empty
            if isempty(obj.LogArray), val = []; return, end     
            % update cache if necessary            
            if isempty(obj.prTaskTrialSummary)
                % get log table
                tab = obj.LogTable;
                % filter for trial data
                tab = teLogFilter(tab, 'topic', 'trial_log_data');
                % check that there is at least one log entry with a 'task'
                % field
                if ~ismember('task', tab.Properties.VariableNames)
                    val = [];
                    return
                end
                % find empties
                empty = cellfun(@isempty, tab.task);
                tab(empty, :) = [];
                % get task subscripts
                [task_u, ~, task_s] = unique(tab.task);
                % count trials
                num = accumarray(task_s, ones(size(tab, 1), 1), [], @sum);
                % make table
                obj.prTaskTrialSummary =....
                    array2table(num, 'rownames', task_u, 'VariableNames',...
                    {'Number'});
            end
            val = obj.prTaskTrialSummary;
        end
        
        function val = get.Events(obj)
            % if no log data, return empty
            if isempty(obj.LogArray), val = []; return, end     
            % update cache if necessary            
            if isempty(obj.prEvents)
                % get just events}
                obj.prEvents = teLogFilter(...
                    obj.LogTable, 'source', 'teEventRelay_Log');
            end
            val = obj.prEvents;
        end
        
        function val = get.TrialGUIDTable(obj)
        % returns a table of trial GUIDs, with associated task name, trial
        % number and subscripts to further interrogate the log
        
            % if no log data, return empty
            if isempty(obj.LogArray), val = []; return, end     
            
            % update cache if necessary
            if isempty(obj.prTrialGUIDTable)
                
                % get working copy of trial log table. We do this so that we
                % can filter out rows with missing trial GUIDs but still query
                % it for, e.g., task name
                tab = teLogFilter(obj.LogArray, 'data', 'trial_onset');

                % get trial GUIDs in a vector
                tguid = tab.trialguid;

                % remove empty
                empty = cellfun(@isempty, tguid);
                tab(empty, :) = [];

                % find unique
                [tguid_u, ~, ~] = unique(tab.trialguid);        

                obj.prTrialGUIDTable = table;
                obj.prTrialGUIDTable.trialguid = tguid_u;
                obj.prTrialGUIDTable.timestamp = tab.timestamp;
                obj.prTrialGUIDTable.task = tab.source;
                if iscell(tab.trialno)
                    obj.prTrialGUIDTable.trialno = cell2mat(tab.trialno);
                else
                    obj.prTrialGUIDTable.trialno = tab.trialno;
                end
                
            end
            
            val = obj.prTrialGUIDTable;
        
        end
        
        function val = get.TrialGUIDs(obj)
        % produces a unique list of trial GUIDs. Some log entries will have
        % a blank trial GUID so we remove those first. 
        
            tab = obj.TrialGUIDTable;
            val = tab.trialguid;
            
        end
        
    % overriden functions
    
        function val = length(obj)
            val = length(obj.LogArray);
        end
        
    end
    
end
    
    