classdef teTrial < teDynamicProps
    
    properties 
        EyeTracking
        Gaze
        TrialNo = nan
        TrialGUID
        Task
    end
    
    properties (SetAccess = private)
        Date
        Onset
        Offset
        Log teLog
    end
    
    properties (Dependent, SetAccess = private)
        Duration
    end
    
    methods
        
        function obj = teTrial(lg, onset, offset)
            
            tab = lg.LogTable;

            if ~exist('onset', 'var') || isempty(onset)
                onset = tab.timestamp(1);
            end
            if ~exist('offset', 'var') || isempty(offset)
                offset = tab.timestamp(end);
            end
            
            obj.Date = tab.date(1);
            obj.Onset = onset;
            obj.Offset = offset;
            if ismember('task', tab.Properties.VariableNames) &&...
                    iscell(tab.task) && all(cellfun(@ischar, tab.task))
                idx_taskName = find(~cellfun(@isempty, tab.task), 1);
            else
                idx_taskName = [];
            end
            if ~isempty(idx_taskName)
                obj.Task = tab.task{idx_taskName};
            end
            if ismember('trialguid', tab.Properties.VariableNames)
                obj.TrialGUID = tab.trialguid{1};
            else
                obj.TrialGUID = [];
            end
            obj.Log = lg;
            
        end
        
        % overloaded functions
        function c = struct2cell(obj)
        % this allows functions that want to treat a teTrial as a struct to
        % to work (e.g. teLogExtract)
        
            s = struct(obj);
            s = rmfield(s, {'DynamicProps', 'DynamicPropOrder',...
                'PropOrderCounter'});
            c = struct2cell(s);
            
        end
        
        % get / set
        function val = get.Duration(obj)
            val = obj.Offset - obj.Onset;
        end
        
    end
    
end