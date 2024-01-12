classdef teDataSummary_tasks < teDataSummary
    
    properties (Access = private)
        uiTable
    end
    
    methods
        
        function CreateUI(obj)
            
            % convert session metadata to table
            taskSummary = obj.Data.tts;
            
            obj.uiTable = uitable(obj.uiParent,...
                'Data', taskSummary,...
                'Position', obj.Position,...
                'FontName', 'Menlo');
            
        end
        
        function UpdateUI(obj)
            obj.uiTable.Position = obj.Position;
        end
        
    end
     
end