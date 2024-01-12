classdef teDataSummary_events < teDataSummary
    
    properties (Access = private)
        uiTable
    end
    
    methods
        
        function CreateUI(obj)
            
            % convert session metadata to table
            wantedVars = {'timestamp', 'data', 'source', 'task', 'logIdx'};
            if ~all(ismember(wantedVars, obj.Data.data.Properties.VariableNames))
                events =  [];
            else
                events = obj.Data.data(:, wantedVars);      
            end
            
%             % colour rows by task
%         
%                 % find unique tasks and assign colour to each
%                 tasks = events.task;
%                 idx_empty = cellfun(@isempty, tasks);
%                 tasks(idx_empty) = repmat({'<EMPTY>'}, sum(idx_empty), 1);
%                 [task_u, ~, task_s] = unique(tasks);
%                 numTasks = length(task_u);
%                 cols = lines(numTasks);
%                 
%                 % make uistyle for each task
%                 style = cell(numTasks, 1);
%                 for t = 1:numTasks
%                     
%                     style{t} = uisty
            
            obj.uiTable = uitable(obj.uiParent,...
                'Data', events,...
                'Position', obj.Position,...
                'RowName', [],...
                'FontName', 'Menlo');
            
        end
        
        function UpdateUI(obj)
            obj.uiTable.Position = obj.Position;
        end
        
    end
     
end